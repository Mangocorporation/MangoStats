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
        return data
    }()

    /// Snapshot runs and APP_SAMPLE=1 show the sample; the real app waits for the samplers.
    static var initial: StatusData {
        let env = ProcessInfo.processInfo.environment
        if env["APP_LIVE"] == "1" { return .placeholder }
        return env["APP_SNAPSHOT"] != nil || env["APP_SAMPLE"] == "1" ? .sample : .placeholder
    }
}
