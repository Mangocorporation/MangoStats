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
    /// Popover footer, where "Upload" doesn't fit next to the latency: "↑ 31 KB/s".
    public var networkUploadShort: String = "↑ --"
    public var networkLatency: String = ""
    public var networkHistory: [Double] = []

    /// Which sensor stats this Mac provides (Settings > Menu Bar lists the others as off).
    public var hasGPU = false
    public var hasTemperature = false
    public var hasFan = false
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

    /// Bottom row of the popover (S-019).
    public var privacyText: String = "Not in use"
    public var privacyActive = false
    public var awakeText: String = "Can sleep"
    public var awakeHelp: String = "Nothing keeps the Mac awake"
    public var screenText: String = "Screen can sleep"
    public var screenHelp: String = "Nothing keeps the screen on"

    /// The Overview's insight card and header line (S-037).
    public var insights: [Insight] = []
    public var memoryFraction: Double = 0
    /// "20,62 GB used of 24 GB" and "5,32 GB swap · pressure normal".
    public var memoryUsedLine: String = "--"
    public var memoryDetailLine: String = "--"
    /// "98 GB free", "396 of 494 GB used on Macintosh HD."
    public var storageTitle: String = "--"
    public var storageLine: String = "--"
    /// "↓ 3 KB/s · ↑ 3 KB/s · low lag"
    public var networkLine: String = "--"
    /// "11 h 47 min left · Chrome drains most"
    public var batteryLine: String = "--"
    public var batteryHistory: [Double] = []
    /// Fan speed as a share of its top speed.
    public var fanHistory: [Double] = []

    /// Hardware tab: battery details (S-048) and disk activity (S-050).
    public var batteryCycles: String = "–"
    public var batteryCapacity: String = "–"
    public var batteryPower: String = "–"
    public var batteryTemperature: String = "–"
    public var batteryCondition: String = "–"
    public var batteryAdapter: String = "–"
    public var diskRead: String = "--"
    public var diskWrite: String = "--"
    public var diskReadHistory: [Double] = []
    public var diskWriteHistory: [Double] = []

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
    /// An app (it lives in a .app bundle) or a background process.
    public var isApp: Bool { bundlePath != nil }
    /// Raw values for sorting (S-012).
    public var memoryBytes: Int64
    public var watts: Double?
    /// False for processes of other users: Quit is unavailable (S-014).
    public var ownedByUser: Bool
    /// Disk bytes per second, and energy used since the app started (watt-hours) (S-049, S-050).
    public var diskRate: Double?
    public var energyWh: Double?

    public init(id: Int32, name: String, memory: String, cpu: Double, cpuText: String, power: String,
                bundlePath: String? = nil, memoryBytes: Int64 = 0, watts: Double? = nil, ownedByUser: Bool = true,
                diskRate: Double? = nil, energyWh: Double? = nil) {
        self.diskRate = diskRate
        self.energyWh = energyWh
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
