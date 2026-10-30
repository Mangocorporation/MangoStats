import Foundation
import MangoStatsKit

extension StatusData {
    /// The reference screenshot's values, for snapshots and the gallery.
    static let sample: StatusData = {
        var data = StatusData()
        data.health = "84"
        data.healthWord = "Good"
        data.healthReason = "Disk space low · 99 GB Free"
        data.chip = "M5"
        data.ram = "24 GB"
        data.macOS = "macOS 26.6.2"
        data.uptime = "up 51 days, 10 hrs"
        data.cpu = "15"
        data.cpuTemp = "45°C"
        data.cpuFooter = "idle · 0.9W"
        data.cpuHistory = [0.9, 0.7, 0.35, 0.25, 0.08, 0.08, 0.45, 0.22, 0.22, 0.08]
        data.gpu = "53"
        data.gpuTemp = "42°C"
        data.gpuFooter = "normal · 0.3W"
        data.gpuHistory = [0.08, 0.1, 0.09, 0.12, 0.1, 0.1, 0.18, 0.1, 0.12, 0.1, 0.11, 0.1, 0.13, 0.1, 0.1, 0.12,
                         0.11, 0.1, 0.12, 0.1, 0.11, 0.1, 0.1, 0.12, 0.1, 0.25, 0.1, 0.85, 0.15, 0.9]
        data.memory = "84"
        data.memoryPressure = "Normal"
        data.memoryFooter = "20,07 GB · 6,62 GB swap"
        data.memoryUsedOfTotal = "20,25 GB / 24 GB"
        data.memoryHistory = Array(repeating: 0.84, count: 30)
        data.diskFree = "99"
        data.diskTotal = "494 GB"
        data.diskUsed = 0.8
        data.diskFooter = "395 GB used · 80%"
        data.network = "4"
        data.networkUnit = "KB/s"
        data.networkInterface = "Wi-Fi"
        data.networkUpload = "Upload <1 KB/s"
        data.networkUploadShort = "↑ <1 KB/s"
        data.networkLatency = "Low Lag"
        data.networkHistory = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 9, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        data.fanRPM = "0"
        data.fanSpeed = "Speed 0%"
        data.fanNote = "Managed by macOS"
        data.battery = "100"
        data.batteryWatts = "65W"
        data.batteryHealth = "100% Health"
        data.batteryState = "Charged"
        data.batteryDrain = "Top drain now WindowServer"
        data.batteryLevel = 1
        data.processCount = 156
        data.processes = [
                .init(id: 1453, name: "Google Chrome", memory: "18.5 GB", cpu: 47.7, cpuText: "47.7", power: "42.8",
                      bundlePath: "/Applications/Google Chrome.app"),
                .init(id: 50429, name: "Code", memory: "2.7 GB", cpu: 1.0, cpuText: "1.0", power: "0.3",
                      bundlePath: "/Applications/Visual Studio Code.app"),
                .init(id: 589, name: "WindowServer", memory: "1.1 GB", cpu: 47.7, cpuText: "47.7", power: "51.1"),
                .init(id: 1350, name: "Google Chrome", memory: "1.1 GB", cpu: 0.4, cpuText: "0.4", power: "0.4",
                      bundlePath: "/Applications/Google Chrome.app"),
                .init(id: 55273, name: "Safari", memory: "1.0 GB", cpu: 0.0, cpuText: "0.0", power: "0.0",
                      bundlePath: "/Applications/Safari.app"),
                .init(id: 36968, name: "Warp", memory: "887 MB", cpu: 3.7, cpuText: "3.7", power: "1.5"),
                .init(id: 51492, name: "Xcode", memory: "886 MB", cpu: 0.3, cpuText: "0.3", power: "0.2",
                      bundlePath: "/Applications/Xcode.app"),
                .init(id: 43194, name: "Claude Code", memory: "554 MB", cpu: 0.4, cpuText: "0.4", power: "0.2"),
                .init(id: 545, name: "mds", memory: "486 MB", cpu: 0.0, cpuText: "0.0", power: "0.0"),
                .init(id: 1356, name: "Finder", memory: "445 MB", cpu: 0.4, cpuText: "0.4", power: "0.3",
                      bundlePath: "/System/Library/CoreServices/Finder.app"),
                .init(id: 12614, name: "Claude Code", memory: "383 MB", cpu: 2.1, cpuText: "2.1", power: "1.2"),
                .init(id: 59309, name: "Spotlight", memory: "305 MB", cpu: 0.0, cpuText: "0.0", power: "--"),
                .init(id: 827, name: "mds_stores", memory: "156 MB", cpu: 0.0, cpuText: "0.0", power: "0.0"),
                .init(id: 9993, name: "com.apple.appkit.xpc.openAndSavePanelService", memory: "132 MB", cpu: 0.0,
                      cpuText: "0.0", power: "0.0"),
        ]
        data.awakeText = L10n.t("Awake")
        data.screenText = L10n.t("Screen on")
        data.privacyText = L10n.t("Not in use")
        // The Overview's values from design/reference/overview.png.
        data.cpu = "11"
        data.cpuTemp = "37°C"
        data.cpuFooter = L10n.t("idle") + " · 0,9 W"
        data.cpuHistory = [0.10, 0.11, 0.09, 0.12, 0.11, 0.10, 0.12, 0.11, 0.10, 0.11, 0.13, 0.11, 0.10, 0.14, 0.11]
        data.gpu = "46"
        data.gpuTemp = "37°C"
        data.gpuFooter = L10n.t("normal") + " · 0,5 W"
        data.gpuHistory = [0.40, 0.46, 0.42, 0.55, 0.43, 0.58, 0.47, 0.52, 0.60, 0.48, 0.55, 0.44, 0.62, 0.45, 0.56, 0.50, 0.58, 0.53]
        data.memory = "86"
        data.memoryFraction = 0.86
        data.memoryUsedLine = L10n.f("%@ used of %@", "20,62 GB", "24 GB")
        data.memoryDetailLine = L10n.f("%@ swap · pressure %@", "5,32 GB", L10n.t("Normal").lowercased())
        data.memoryUsedOfTotal = "20,62 GB / 24 GB"
        data.diskFree = "98"
        data.diskUsed = 0.8
        data.storageTitle = L10n.f("%@ free", "98 GB")
        data.storageLine = L10n.f("%@ of %@ used on %@.", "396", "494 GB", "Macintosh HD")
        data.diskFooter = L10n.f("%@ used · %@%%", "396 GB", "80")
        data.network = "3"
        data.networkLine = "↓ 3 KB/s · ↑ 3 KB/s · " + L10n.t("Low Lag").lowercased()
        data.networkHistory = [2, 2.2, 2.4, 2.1, 2.3, 2.6, 2.2, 2.4, 2.3, 6, 2.5, 2.3, 2.4, 2.8, 2.2]
        data.battery = "91"
        data.batteryLevel = 0.91
        data.batteryState = L10n.f("On Battery · %@ left", "11 h 47 min")
        data.batteryLine = L10n.f("%@ left", "11 h 47 min") + " · " + L10n.f("%@ drains most", "Chrome")
        data.batteryHistory = Array(stride(from: 0.93, through: 0.91, by: -0.001))
        data.fanHistory = Array(repeating: 0, count: 20)
        data.hasFan = true
        data.hasGPU = true
        data.hasTemperature = true
        data.fanNote = L10n.t("Silent · managed by macOS")
        data.health = "84"
        data.healthWord = L10n.t("Good")
        data.healthReasons = [L10n.f("Disk space low · %@ free", "98 GB"), L10n.t("Using swap")]
        data.insights = [
            Insight(kind: .memory, eyebrow: L10n.t("Memory is tight"), title: L10n.f("%@ is holding %@", "Google Chrome", "19,4 GB"),
                    body: L10n.f("Memory is %ld%% full and macOS has moved %@ to swap.", 86, "5,32 GB") + " "
                        + L10n.t("Quitting what you aren't using is the quickest way to get memory back."),
                    app: "Google Chrome"),
            Insight(kind: .disk, eyebrow: L10n.t("Storage is filling up"), title: L10n.f("%@ free", "98 GB"),
                    body: L10n.t("Below 10% free, macOS can't keep caches and updates may fail."), app: nil),
        ]
        data.batteryCycles = L10n.f("%ld of %@", 55, "1000")
        data.batteryCapacity = L10n.f("%@ of %@ mAh", "6305", "6249")
        data.batteryPower = L10n.f("Using %@", "8,4 W")
        data.batteryTemperature = "30,5 °C"
        data.batteryCondition = L10n.t("Normal")
        data.batteryAdapter = L10n.t("Not connected")
        data.batteryHealth = L10n.f("%ld%% Health", 100)
        data.diskRead = "12 MB/s"
        data.diskWrite = "3 MB/s"
        data.diskReadHistory = [2, 4, 3, 12, 30, 8, 5, 3, 2, 12, 6, 4].map { $0 * 1_000_000 }
        data.diskWriteHistory = [1, 1, 2, 3, 6, 2, 1, 1, 3, 3, 2, 1].map { $0 * 1_000_000 }
        data.processCount = 541
        data.processes = [
            .init(id: 1350, name: "Google Chrome", memory: "19,4 GB", cpu: 47.0, cpuText: "47,0", power: "0,1",
                  bundlePath: "/Applications/Google Chrome.app", memoryBytes: 20_830_000_000, watts: 1.8,
                  diskRate: 2_400_000, energyWh: 51.1),
            .init(id: 589, name: "WindowServer", memory: "111 MB", cpu: 9.3, cpuText: "9,3", power: "–",
                  memoryBytes: 116_000_000, ownedByUser: false),
            .init(id: 12614, name: "claude", memory: "362 MB", cpu: 8.9, cpuText: "8,9", power: "0,0",
                  memoryBytes: 380_000_000, watts: 0),
            .init(id: 36968, name: "Warp", memory: "852 MB", cpu: 8.5, cpuText: "8,5", power: "0,0",
                  bundlePath: "/Applications/Warp.app", memoryBytes: 893_000_000, watts: 0.32, diskRate: 160_000, energyWh: 2.4),
            .init(id: 1356, name: "Finder", memory: "362 MB", cpu: 1.9, cpuText: "1,9", power: "0,0",
                  bundlePath: "/System/Library/CoreServices/Finder.app", memoryBytes: 380_000_000, watts: 0),
            .init(id: 43194, name: "claude", memory: "373 MB", cpu: 1.2, cpuText: "1,2", power: "0,0",
                  memoryBytes: 391_000_000, watts: 0),
            .init(id: 92152, name: "MangoStats", memory: "82 MB", cpu: 1.1, cpuText: "1,1", power: "0,0",
                  bundlePath: "/Applications/MangoStats.app", memoryBytes: 86_000_000, watts: 0),
            .init(id: 25396, name: "Visual Studio Code", memory: "1,5 GB", cpu: 1.1, cpuText: "1,1", power: "0,0",
                  bundlePath: "/Applications/Visual Studio Code.app", memoryBytes: 1_610_000_000, watts: 0.21,
                  diskRate: 640_000, energyWh: 6.8),
            .init(id: 1247, name: "WindowManager", memory: "40 MB", cpu: 1.0, cpuText: "1,0", power: "0,0",
                  memoryBytes: 42_000_000, watts: 0),
            .init(id: 1178, name: "corespotlightd", memory: "44 MB", cpu: 0.4, cpuText: "0,4", power: "0,0",
                  memoryBytes: 46_000_000, watts: 0),
            .init(id: 96770, name: "screencapture", memory: "8 MB", cpu: 0.4, cpuText: "0,4", power: "–",
                  memoryBytes: 8_400_000),
            .init(id: 13682, name: "iconservicesagent", memory: "20 MB", cpu: 0.3, cpuText: "0,3", power: "0,0",
                  memoryBytes: 21_000_000, watts: 0),
            .init(id: 74958, name: "MangoMemory", memory: "39 MB", cpu: 0.2, cpuText: "0,2", power: "0,0",
                  bundlePath: "/Applications/MangoMemory.app", memoryBytes: 41_000_000, watts: 0),
            .init(id: 9993, name: "com.apple.appkit.xpc.openAndSavePanelService", memory: "132 MB", cpu: 0.0,
                  cpuText: "0,0", power: "0,0", memoryBytes: 138_000_000, watts: 0),
        ]
        return data
    }()

    /// Snapshot runs and APP_SAMPLE=1 show the sample; the real app waits for the samplers.
    static var initial: StatusData {
        let env = ProcessInfo.processInfo.environment
        if env["APP_LIVE"] == "1" { return .placeholder }
        return env["APP_SNAPSHOT"] != nil || env["APP_SAMPLE"] == "1" ? .sample : .placeholder
    }
}
