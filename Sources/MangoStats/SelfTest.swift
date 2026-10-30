import AppKit
import MangoStatsKit
import MangoStatsSMC

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

            // S-019 to S-021
            check("camera and mic state is read", ["Not in use", "Camera in use", "Mic in use", "Camera and mic in use"]
                .contains(status.privacyText), status.privacyText)
            check("sleep state is read", ["Awake", "Can sleep"].contains(status.awakeText), status.awakeText)
            _ = LoginItem.isEnabled
            check("open at login reads its status without changing it", true)
            model.refreshInterval = 1
            let historyBefore = model.status.memoryHistory.count
            try? await Task.sleep(for: .seconds(2.5))
            check("a 1 s refresh keeps the history and samples faster", model.status.memoryHistory.count >= historyBefore + 2,
                  "\(historyBefore) -> \(model.status.memoryHistory.count)")
            check("the refresh interval survives a restart", AppModel().refreshInterval == 1)
            model.refreshInterval = 2
            print("INFO privacy \(status.privacyText) · \(status.awakeText) (\(status.awakeHelp)) · \(status.screenText)")

            // S-024 to S-026, without touching the real helper (test runs never do).
            let fan = FanControl.shared
            check("MangoStats starts with the fan on Auto", fan.wanted == .auto && fan.applied == .auto)
            fan.pick(.max)
            check("Cool and Max need fan control turned on", fan.state == .on || fan.wanted == .auto)
            check("the helper and its launchd plist are in the app bundle",
                  FileManager.default.fileExists(atPath: Bundle.main.bundlePath + "/Contents/MacOS/MangoStatsHelper")
                  && FileManager.default.fileExists(atPath: Bundle.main.bundlePath
                      + "/Contents/Library/LaunchDaemons/\(FanHelper.plistName)"))

            // S-027, S-030: history in a /tmp database.
            let store = HistoryStore(url: URL(fileURLWithPath: "/tmp/MangoStats-selftest-history.sqlite"))
            await store.clear()
            let minute = MinuteAggregator.minuteStart(.now)
            store.insert(MinuteSample(time: minute, cpu: 0.25, memory: 0.5, gpu: nil, download: 1_000))
            store.insert(MinuteSample(time: minute.addingTimeInterval(-40 * 86_400), cpu: 0.9, memory: 0.9))
            await store.flush()
            let reopened = HistoryStore(url: URL(fileURLWithPath: "/tmp/MangoStats-selftest-history.sqlite"))
            let rows = await reopened.minutes(since: minute.addingTimeInterval(-50 * 86_400))
            check("history minutes are written and read back", rows.count == 2 && rows.last?.cpu == 0.25 && rows.last?.gpu == nil)
            reopened.prune(before: HistoryRetention.cutoff(days: 30, now: .now))
            check("old minutes are pruned", await reopened.minutes(since: .distantPast).count == 1)
            await reopened.clear()
            check("Clear History empties the database", await reopened.minutes(since: .distantPast).isEmpty)
            check("test runs use a history file in /tmp", HistoryStore.defaultURL.path.hasPrefix("/tmp/"))

            // S-035: updates.
            check("test runs never check for updates", !model.updater.enabled && !model.updater.canCheck)
            check("the app has an update feed and key",
                  Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
                  && Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil)
            check("Sparkle is embedded", FileManager.default.fileExists(
                atPath: Bundle.main.bundlePath + "/Contents/Frameworks/Sparkle.framework"))

            // S-031 to S-034: alerts.
            check("alerts are off by default", AppModel().alerts.showAlerts == false)
            var alerts = model.alerts
            alerts.showAlerts = true
            alerts.thresholds[.cpuHot] = 95
            model.alerts = alerts
            check("alert settings survive a restart", AppModel().alerts == alerts)
            model.popoverOpen = false
            model.status.processes = []
            try? await Task.sleep(for: .seconds(2.5))
            check("the busy-app alert reads processes with nothing open", !model.status.processes.isEmpty)
            model.alerts = AlertSettings()
            model.popoverOpen = true

            // S-039: pings without root, each to its own target.
            let pings = await Task.detached { () -> (Double?, Double?) in
                let route = NetworkProbe.defaultRoute()
                async let router = route.flatMap { NetworkProbe.ping($0.gateway) }
                async let internet = NetworkProbe.ping("1.1.1.1")
                return (await router, await internet)
            }.value
            check("the router answers a ping without root", pings.0 != nil, "\(pings.0 ?? -1) ms")
            check("the internet answers a ping without root", pings.1 != nil, "\(pings.1 ?? -1) ms")
            print("INFO ping router \(pings.0.map { String(format: "%.1f", $0) } ?? "-") ms · internet \(pings.1.map { String(format: "%.1f", $0) } ?? "-") ms")

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
            // S-051: the Portuguese table ships, and each sentence keeps the same values to fill in.
            if let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "pt-BR"),
               let table = NSDictionary(contentsOfFile: path) as? [String: String] {
                check("the app speaks Portuguese", table["Overview"] == "Visão Geral" && table.count > 300)
                let specifiers = try! Regex("%(lld|ld|@|%)")
                let broken = table.filter { key, value in
                    key.matches(of: specifiers).map { String(key[$0.range]) }.sorted()
                        != value.matches(of: specifiers).map { String(value[$0.range]) }.sorted()
                }
                check("Portuguese sentences keep their values", broken.isEmpty, broken.keys.joined(separator: ", "))
            } else {
                check("the app speaks Portuguese", false, "pt-BR.lproj missing from the bundle")
            }
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
