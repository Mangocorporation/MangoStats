import Foundation

/// Everything the cards and tables show, already formatted. The samplers
/// (S-001 and on) fill it; until then the app shows `placeholder`, and
/// snapshot runs show `sample`, the values from design/reference.
struct StatusData {
    var health: String
    var healthWord: String
    var healthReason: String
    var chip: String
    var ram: String
    var macOS: String
    var uptime: String

    var cpu: String
    var cpuTemp: String?
    var cpuFooter: String
    var cpuHistory: [Double]

    var gpu: String
    var gpuTemp: String?
    var gpuFooter: String
    var gpuHistory: [Double]

    var memory: String
    var memoryPressure: String
    var memoryFooter: String
    var memoryHistory: [Double]

    var diskFree: String
    var diskTotal: String
    var diskUsed: Double
    var diskFooter: String

    var network: String
    var networkUnit: String
    var networkInterface: String
    var networkUpload: String
    var networkLatency: String
    var networkHistory: [Double]

    var fanRPM: String
    var fanSpeed: String
    var fanNote: String

    var battery: String
    var batteryWatts: String?
    var batteryHealth: String
    var batteryState: String
    var batteryDrain: String
    var batteryLevel: Double

    var processCount: Int
    var processes: [ProcessRowData]

    /// Shown before the first sample: every value reads "--".
    static let placeholder = StatusData(
        health: "--", healthWord: "", healthReason: "Measuring…", chip: "--", ram: "--", macOS: "--", uptime: "--",
        cpu: "--", cpuTemp: nil, cpuFooter: "--", cpuHistory: [],
        gpu: "--", gpuTemp: nil, gpuFooter: "--", gpuHistory: [],
        memory: "--", memoryPressure: "--", memoryFooter: "--", memoryHistory: [],
        diskFree: "--", diskTotal: "--", diskUsed: 0, diskFooter: "--",
        network: "--", networkUnit: "KB/s", networkInterface: "Network", networkUpload: "Upload --",
        networkLatency: "", networkHistory: [],
        fanRPM: "--", fanSpeed: "Speed --", fanNote: "Managed by macOS",
        battery: "--", batteryWatts: nil, batteryHealth: "--", batteryState: "--", batteryDrain: "", batteryLevel: 0,
        processCount: 0, processes: [])

    /// The reference screenshot's values, for snapshots and the gallery.
    static let sample = StatusData(
        health: "84", healthWord: "Good", healthReason: "Disk space low · 99 GB Free",
        chip: "M5", ram: "24 GB", macOS: "macOS 26.6.2", uptime: "up 51 days, 10 hrs",
        cpu: "15", cpuTemp: "45°C", cpuFooter: "idle · 0.9W",
        cpuHistory: [0.9, 0.7, 0.35, 0.25, 0.08, 0.08, 0.45, 0.22, 0.22, 0.08],
        gpu: "53", gpuTemp: "42°C", gpuFooter: "normal · 0.3W",
        gpuHistory: [0.08, 0.1, 0.09, 0.12, 0.1, 0.1, 0.18, 0.1, 0.12, 0.1, 0.11, 0.1, 0.13, 0.1, 0.1, 0.12,
                     0.11, 0.1, 0.12, 0.1, 0.11, 0.1, 0.1, 0.12, 0.1, 0.25, 0.1, 0.85, 0.15, 0.9],
        memory: "84", memoryPressure: "Pressure normal", memoryFooter: "20,07 GB · 6,62 GB swap",
        memoryHistory: Array(repeating: 0.84, count: 30),
        diskFree: "99", diskTotal: "494 GB", diskUsed: 0.8, diskFooter: "395 GB used · 80%",
        network: "4", networkUnit: "KB/s", networkInterface: "Wi-Fi", networkUpload: "Upload < 1 KB/s",
        networkLatency: "Low Lag",
        networkHistory: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 9, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
        fanRPM: "0", fanSpeed: "Speed 0%", fanNote: "Managed by macOS",
        battery: "100", batteryWatts: "65W", batteryHealth: "100% Health", batteryState: "Charged",
        batteryDrain: "Top drain now WindowServer", batteryLevel: 1,
        processCount: 156,
        processes: [
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
        ])

    /// Snapshot runs and APP_SAMPLE=1 show the sample; the real app waits for the samplers.
    static var initial: StatusData {
        let env = ProcessInfo.processInfo.environment
        return env["APP_SNAPSHOT"] != nil || env["APP_SAMPLE"] == "1" ? .sample : .placeholder
    }
}
