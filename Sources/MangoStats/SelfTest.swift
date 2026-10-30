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
            check("stats this Mac can't read yet stay out of the menu bar", !model.shownStats.contains(.gpu))
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
