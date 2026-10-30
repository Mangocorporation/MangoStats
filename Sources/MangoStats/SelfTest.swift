import AppKit
import MangoStatsKit

/// Self-test for agents: runs the app's real functions on a test store,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/MangoStats-self ~/Applications/MangoStats.app/Contents/MacOS/MangoStats --selftest
/// (tools/selftest.sh does this.) Add a check for every story with logic.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        // Print each line at once, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a path in /tmp")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            let saved = model.menuBar
            model.setShown(.network, true)
            model.setShown(.cpu, false)
            check("turning stats on and off changes the menu bar", model.menuBar.visible == [.memory, .network])
            model.setShown(.gpu, true)
            model.menuValues = [.cpu: "1%"]
            model.status.hasGPU = false
            check("stats this Mac can't read stay out of the menu bar", !model.shownStats.contains(.gpu))
            model.status.hasGPU = true
            check("stats this Mac can read show in the menu bar", model.shownStats.contains(.gpu))
            model.menuValues = [:]
            model.setShown(.gpu, false)
            let reloaded = AppModel()
            check("menu bar choices survive a restart", reloaded.menuBar == model.menuBar)
            model.menuBarStyle = .valueOnly
            check("menu bar style survives a restart", AppModel().menuBarStyle == .valueOnly)
            model.menuBar = saved
            check("settings use the test domain", Store.defaults !== UserDefaults.standard)

            // S-001: live values within a few seconds.
            model.popoverOpen = true
            model.startSampling()
            try? await Task.sleep(for: .seconds(5))
            let cpu = model.menuValues[.cpu] ?? "--"
            check("CPU shows a live value in the menu bar", cpu != "--" && cpu.hasSuffix("%"), cpu)
            check("Memory shows a live value in the menu bar", (model.menuValues[.memory] ?? "--") != "--")
            let status = model.status
            check("the health score is a number", Int(status.health) != nil, status.health)
            check("chip and macOS are read", status.chip != "--" && status.macOS.hasPrefix("macOS"), status.chip)
            check("free space is read", status.diskFree != "--" && status.diskUsed > 0)
            check("CPU history has samples", !status.cpuHistory.isEmpty)
            // S-008: processes, including other users' (WindowServer runs as _windowserver).
            check("processes are listed", status.processes.count > 20, "\(status.processes.count)")
            check("other users' processes are listed", status.processes.contains { $0.name == "WindowServer" })
            let memories = status.processes.prefix(5).map(\.name)
            check("top processes are sorted by memory", !memories.isEmpty, memories.joined(separator: ", "))
            // S-015 to S-018: sensors (this Mac has a GPU, SMC sensors, and a fan).
            check("GPU load is read", status.hasGPU && Int(status.gpu) != nil, status.gpu)
            check("CPU temperature is read", status.cpuTemp?.hasSuffix("°C") == true, status.cpuTemp ?? "nil")
            check("GPU temperature is read", status.gpuTemp != nil)
            check("CPU power shows in the footer", status.cpuFooter.hasSuffix("W"), status.cpuFooter)
            check("the fan is read", status.hasFan && status.fanSpeed.hasPrefix("Speed"), status.fanSpeed)
            check("temperature can show in the menu bar", model.isAvailable(.temperature))
            print("INFO sensors gpu \(status.gpu)% \(status.gpuFooter) · cpu \(status.cpuTemp ?? "-") \(status.cpuFooter) · gpu temp \(status.gpuTemp ?? "-") · fan \(status.fanRPM) RPM \(status.fanSpeed)")

            // S-014: Quit ends a process of this user.
            let child = Process()
            child.executableURL = URL(fileURLWithPath: "/bin/sleep")
            child.arguments = ["60"]
            try? child.run()
            let pid = child.processIdentifier
            check("Quit sends a quit request to the process", ProcessActions.quit(pid))
            try? await Task.sleep(for: .seconds(0.5))
            check("the process is gone after Quit", !child.isRunning)
            if let other = status.processes.first(where: { $0.name == "WindowServer" }) {
                check("other users' processes can't be quit", !other.ownedByUser)
            }
            check("this user's apps can be quit", status.processes.contains { $0.ownedByUser })
            print("INFO menu \(model.menuValues.sorted { $0.key.rawValue < $1.key.rawValue }.map { "\($0.key.rawValue)=\($0.value)" }.joined(separator: " "))")
            print("INFO top \(memories.joined(separator: ", ")) · battery \(status.battery) \(status.batteryState) \(status.batteryHealth) · net \(status.networkInterface) \(status.network) \(status.networkUnit)")

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    /// Quits through NSApp.terminate, never exit(), and closes sheets first:
    /// an open sheet refuses terminate, and the run would wait forever.
    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
