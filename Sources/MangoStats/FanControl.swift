import AppKit
import MangoStatsKit
import MangoStatsSMC
import Observation
import ServiceManagement

/// Fan control from the app's side (S-024 to S-026): the helper's state,
/// the mode people picked, and the XPC connection. The helper does the
/// writing and the safety rules; this sends the wanted mode every sample.
@Observable
final class FanControl {
    enum State: Equatable {
        case off, needsApproval, on
    }

    static let shared = FanControl()

    private(set) var state: State = .off
    /// What people picked. Always Auto at launch (S-026).
    private(set) var wanted: FanMode = .auto
    /// What the helper applied: the hot override can turn Cool into Max.
    private(set) var applied: FanMode = .auto
    private(set) var error: String?

    @ObservationIgnored private let service = SMAppService.daemon(plistName: FanHelper.plistName)
    @ObservationIgnored private var connection: NSXPCConnection?
    @ObservationIgnored private var checkedVersion = false

    /// Test and snapshot runs never touch the real helper.
    private var allowed: Bool { !Store.isOverridden }

    private init() {
        refresh()
    }

    func refresh() {
        guard allowed else { return }
        switch service.status {
        case .enabled: state = .on
        case .requiresApproval: state = .needsApproval
        default: state = .off
        }
    }

    /// "Allow Fan Control…": registers the helper; macOS asks for approval in Login Items.
    func enable() {
        guard allowed else { return }
        do {
            try service.register()
            error = nil
        } catch {
            self.error = "Unable to install the helper: \(error.localizedDescription)"
        }
        refresh()
        if state == .needsApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    /// "Turn Off Fan Control": back to Auto, then remove the helper.
    func disable() {
        guard allowed else { return }
        wanted = .auto
        sendAutoNow()
        connection?.invalidate()
        connection = nil
        Task {
            try? await service.unregister()
            refresh()
        }
    }

    func pick(_ mode: FanMode) {
        guard state == .on || mode == .auto else { return }
        wanted = mode
        tick()
    }

    /// Called every sample: tells the helper the wanted mode, which also proves the app is alive.
    func tick() {
        refresh()
        guard state == .on, let proxy = proxy() else {
            applied = .auto
            return
        }
        proxy.request(wanted.rawValue) { mode, error in
            Task { @MainActor in
                self.applied = FanMode(rawValue: mode) ?? .auto
                self.error = error.map { "Unable to set the fan: \($0)" }
                if error != nil { self.wanted = .auto }
            }
        }
    }

    /// On quit: Auto before the process ends (S-026). Waits at most 1 s.
    func sendAutoNow() {
        guard state == .on, let connection = connect() else { return }
        let done = DispatchSemaphore(value: 0)
        let proxy = connection.synchronousRemoteObjectProxyWithErrorHandler { _ in done.signal() }
        (proxy as? FanHelperProtocol)?.request(FanMode.auto.rawValue) { _, _ in done.signal() }
        _ = done.wait(timeout: .now() + 1)
    }

    private func proxy() -> FanHelperProtocol? {
        guard let connection = connect() else { return nil }
        return connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            Task { @MainActor in
                self?.error = "Unable to reach the fan helper: \(error.localizedDescription)"
                self?.connection = nil
            }
        } as? FanHelperProtocol
    }

    private func connect() -> NSXPCConnection? {
        if let connection { return connection }
        let connection = NSXPCConnection(machServiceName: FanHelper.label, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: FanHelperProtocol.self)
        connection.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        connection.resume()
        self.connection = connection
        checkVersion(connection)
        return connection
    }

    /// A helper from an older build gets replaced, so launchd runs the new one.
    private func checkVersion(_ connection: NSXPCConnection) {
        guard !checkedVersion else { return }
        checkedVersion = true
        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in } as? FanHelperProtocol
        proxy?.version { version in
            guard version != FanHelper.version else { return }
            Task { @MainActor in
                try? await self.service.unregister()
                try? self.service.register()
                self.connection?.invalidate()
                self.connection = nil
                self.checkedVersion = false
            }
        }
    }
}
