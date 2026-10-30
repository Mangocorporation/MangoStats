import Foundation
import MangoStatsKit
import MangoStatsSMC
import Security

// MangoStatsHelper: a launch daemon that sets the fan for MangoStats (S-024 to S-026).
// Runs as root; launchd starts it on the first XPC connection.
// Safety: it starts in Auto, returns to Auto when the app stops asking (15 s),
// when a connection drops, and on SIGTERM. Cool turns into Max on a hot CPU.

/// All fan state, on one serial queue.
final class FanController: NSObject, FanHelperProtocol, @unchecked Sendable {
    private let queue = DispatchQueue(label: "fan")
    private let smc = SMC()
    private lazy var fans = smc?.fans() ?? []
    private lazy var cpuKeys = smc?.keys { $0.hasPrefix("Tp") || $0.hasPrefix("Te") } ?? []
    private var requested = FanMode.auto
    private var lastPing: Date?
    private var boosted = false
    private var applied: FanMode?
    private var timer: DispatchSourceTimer?

    func start() {
        queue.sync { _ = apply(.auto) }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2, leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    func request(_ mode: Int, reply: @escaping @Sendable (Int, String?) -> Void) {
        queue.async {
            self.requested = FanMode(rawValue: mode) ?? .auto
            self.lastPing = .now
            let error = self.tick()
            reply((self.applied ?? .auto).rawValue, error)
        }
    }

    func version(reply: @escaping @Sendable (Int) -> Void) {
        reply(FanHelper.version)
    }

    /// The app went away: give the fan back to macOS.
    func connectionEnded() {
        queue.async {
            self.requested = .auto
            self.tick()
        }
    }

    func resetToAuto() {
        queue.sync { _ = apply(.auto) }
    }

    @discardableResult
    private func tick() -> String? {
        let temperature = requested == .cool ? smc?.cpuTemperature(keys: cpuKeys) : nil
        let next = FanPolicy.effective(requested: requested, lastPing: lastPing, now: .now,
                                       cpuTemperature: temperature, boosted: boosted)
        boosted = next.boosted
        return apply(next.mode)
    }

    @discardableResult
    private func apply(_ mode: FanMode) -> String? {
        guard let smc else { return "The SMC is not available." }
        guard !fans.isEmpty else { return "This Mac has no fan." }
        // Re-apply manual modes every tick: after sleep the SMC can return to Auto on its own.
        guard mode != applied || mode != .auto else { return nil }
        for fan in fans {
            guard smc.setFan(fan, rpm: FanPolicy.target(mode, min: fan.min, max: fan.max)) else {
                smc.setFan(fan, rpm: nil)
                applied = .auto
                return "The SMC refused the fan setting."
            }
        }
        applied = mode
        return nil
    }
}

/// Accepts connections only from MangoStats signed by the helper's own team.
final class ListenerDelegate: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    let controller: FanController

    init(controller: FanController) {
        self.controller = controller
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: FanHelperProtocol.self)
        connection.exportedObject = controller
        connection.invalidationHandler = { [controller] in controller.connectionEnded() }
        connection.interruptionHandler = { [controller] in controller.connectionEnded() }
        connection.resume()
        return true
    }
}

/// "anchor apple generic and identifier … and certificate leaf[subject.OU] = <team>".
func clientRequirement() -> String? {
    var code: SecCode?
    guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
    var info: CFDictionary?
    guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
          let team = (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String else { return nil }
    return "anchor apple generic and identifier \"\(FanHelper.appIdentifier)\" and certificate leaf[subject.OU] = \"\(team)\""
}

let controller = FanController()
controller.start()

// launchd stops daemons with SIGTERM: give the fan back first.
signal(SIGTERM, SIG_IGN)
let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
termination.setEventHandler {
    controller.resetToAuto()
    exit(0)
}
termination.resume()

guard let requirement = clientRequirement() else {
    // Unsigned or ad hoc: no team to check callers against, so accept no one.
    FileHandle.standardError.write(Data("MangoStatsHelper: no team signature, refusing to run\n".utf8))
    controller.resetToAuto()
    exit(1)
}
let delegate = ListenerDelegate(controller: controller)
let listener = NSXPCListener(machServiceName: FanHelper.label)
listener.setConnectionCodeSigningRequirement(requirement)
listener.delegate = delegate
listener.resume()
dispatchMain()
