import Foundation

/// Everything the cards and tables show, already formatted. `StatusBuilder`
/// fills it from readings; before the first reading every value reads "--".
public struct StatusData: Sendable {

    public var health: String = "--"
    public var healthWord: String = ""
    public var healthReason: String = "Measuring…"
    public var healthReasons: [String] = []
    public var chip: String = "--"
    public var ram: String = "--"
    public var macOS: String = "--"
    public var uptime: String = "--"

    public var cpu: String = "--"
    public var cpuTemp: String? = nil
    public var cpuFooter: String = "--"
    public var cpuHistory: [Double] = []

    public var gpu: String = "--"
    public var gpuTemp: String? = nil
    public var gpuFooter: String = "--"
    public var gpuHistory: [Double] = []

    public var memory: String = "--"
    public var memoryPressure: String = "--"
    public var memoryPressureLevel: MemoryPressure = .normal
    public var memoryFooter: String = "--"
    /// Popover footer: "20,25 GB / 24 GB".
    public var memoryUsedOfTotal: String = "--"
    public var memoryHistory: [Double] = []

    public var diskFree: String = "--"
    public var diskFreeUnit: String = "GB"
    public var diskTotal: String = "--"
    public var diskUsed: Double = 0
    public var diskFooter: String = "--"

    public var network: String = "--"
    public var networkUnit: String = "KB/s"
    public var networkInterface: String = "Network"
    public var networkUpload: String = "Upload --"
    public var networkLatency: String = ""
    public var networkHistory: [Double] = []

    public var fanRPM: String = "--"
    public var fanSpeed: String = "Speed --"
    public var fanNote: String = "Managed by macOS"

    public var hasBattery = true
    public var battery: String = "--"
    public var batteryWatts: String? = nil
    public var batteryHealth: String = "--"
    public var batteryState: String = "--"
    public var batteryDrain: String = ""
    public var batteryLevel: Double = 0

    public var processCount: Int = 0
    public var processes: [ProcessRowData] = []

    /// Shown before the first sample: every value reads "--".
    public init() {}

    public static let placeholder = StatusData()
}

/// One process row, formatted.
public struct ProcessRowData: Identifiable, Hashable, Sendable {
    public let id: Int32
    public let name: String
    public let memory: String
    public let cpu: Double
    public let cpuText: String
    public let power: String
    public var bundlePath: String?
    /// Raw values for sorting (S-012).
    public var memoryBytes: Int64
    public var watts: Double?
    /// False for processes of other users: Quit is unavailable (S-014).
    public var ownedByUser: Bool

    public init(id: Int32, name: String, memory: String, cpu: Double, cpuText: String, power: String,
                bundlePath: String? = nil, memoryBytes: Int64 = 0, watts: Double? = nil, ownedByUser: Bool = true) {
        self.id = id
        self.name = name
        self.memory = memory
        self.cpu = cpu
        self.cpuText = cpuText
        self.power = power
        self.bundlePath = bundlePath
        self.memoryBytes = memoryBytes
        self.watts = watts
        self.ownedByUser = ownedByUser
    }

    /// Over 20 % CPU the row is marked hot (design/KIT.md, Process row).
    public var hot: Bool { cpu >= 20 }
}
