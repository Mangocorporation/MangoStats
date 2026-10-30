import Foundation

// What the system readers return (Sources/MangoStats/Sampling/Readers.swift).
// Plain values, so StatusBuilder can be tested with made-up readings.

public struct MemoryReading: Sendable {
    public var total: Int64
    /// App memory + wired + compressed, like Activity Monitor's "Memory Used".
    public var used: Int64
    public var swap: Int64
    public var pressure: MemoryPressure

    public init(total: Int64, used: Int64, swap: Int64, pressure: MemoryPressure) {
        self.total = total
        self.used = used
        self.swap = swap
        self.pressure = pressure
    }
}

public struct DiskReading: Sendable {
    public var total: Int64
    /// Includes purgeable space, like Finder (S-005).
    public var free: Int64
    /// Bytes read and written by the disks since startup (S-050).
    public var readBytes: Int64?
    public var writtenBytes: Int64?

    public init(total: Int64, free: Int64, readBytes: Int64? = nil, writtenBytes: Int64? = nil) {
        self.total = total
        self.free = free
        self.readBytes = readBytes
        self.writtenBytes = writtenBytes
    }
}

public struct BatteryReading: Sendable {
    public var percent: Int
    public var health: Int
    public var charging: Bool
    public var pluggedIn: Bool
    public var charged: Bool
    public var adapterWatts: Int?
    /// Minutes to full or to empty; nil while macOS is still estimating.
    public var minutesLeft: Int?
    /// Details for the Hardware tab (S-048); nil where the battery doesn't report them.
    public var cycleCount: Int?
    public var designCycles: Int?
    public var maxCapacity: Int?
    public var designCapacity: Int?
    /// Volts and amps (amps are negative while discharging).
    public var voltage: Double?
    public var amperage: Double?
    /// °C.
    public var temperature: Double?
    public var adapterName: String?

    public init(percent: Int, health: Int, charging: Bool, pluggedIn: Bool, charged: Bool,
                adapterWatts: Int?, minutesLeft: Int?, cycleCount: Int? = nil, designCycles: Int? = nil,
                maxCapacity: Int? = nil, designCapacity: Int? = nil, voltage: Double? = nil, amperage: Double? = nil,
                temperature: Double? = nil, adapterName: String? = nil) {
        self.cycleCount = cycleCount
        self.designCycles = designCycles
        self.maxCapacity = maxCapacity
        self.designCapacity = designCapacity
        self.voltage = voltage
        self.amperage = amperage
        self.temperature = temperature
        self.adapterName = adapterName
        self.percent = percent
        self.health = health
        self.charging = charging
        self.pluggedIn = pluggedIn
        self.charged = charged
        self.adapterWatts = adapterWatts
        self.minutesLeft = minutesLeft
    }
}

public struct SystemInfo: Sendable {
    public var chip: String
    public var memory: Int64
    public var macOS: String
    public var boot: Date
    /// The startup disk's name: "Macintosh HD".
    public var volumeName: String

    public init(chip: String, memory: Int64, macOS: String, boot: Date, volumeName: String = "Macintosh HD") {
        self.chip = chip
        self.memory = memory
        self.macOS = macOS
        self.boot = boot
        self.volumeName = volumeName
    }
}

/// One read of the whole system.
public struct Reading: Sendable {
    public var ticks: [CPUTicks]
    public var memory: MemoryReading
    public var disk: DiskReading?
    public var network: NetworkCounters
    public var battery: BatteryReading?
    /// nil when nobody looks at processes (popover and window closed).
    public var processes: [ProcessSample]?
    public var sensors: SensorReading
    public var privacy: PrivacyReading
    public var time: Date

    public init(ticks: [CPUTicks], memory: MemoryReading, disk: DiskReading?, network: NetworkCounters,
                battery: BatteryReading?, processes: [ProcessSample]?, sensors: SensorReading = SensorReading(),
                privacy: PrivacyReading = PrivacyReading(), time: Date) {
        self.sensors = sensors
        self.privacy = privacy
        self.ticks = ticks
        self.memory = memory
        self.disk = disk
        self.network = network
        self.battery = battery
        self.processes = processes
        self.time = time
    }
}

public struct NetworkCounters: Sendable, Equatable {
    public var received: UInt64
    public var sent: UInt64

    public init(received: UInt64, sent: UInt64) {
        self.received = received
        self.sent = sent
    }
}

/// Sensor values from the GPU, the SMC, and IOReport (S-015 to S-018).
/// Each is nil when this Mac can't provide it.
public struct SensorReading: Sendable, Equatable {
    /// GPU load, 0…1.
    public var gpu: Double?
    /// °C, averaged over the CPU (Tp*, Te*) or GPU (Tg*) sensors.
    public var cpuTemperature: Double?
    public var gpuTemperature: Double?
    /// Watts since the previous reading.
    public var cpuWatts: Double?
    public var gpuWatts: Double?
    public var fans: [FanReading]

    public init(gpu: Double? = nil, cpuTemperature: Double? = nil, gpuTemperature: Double? = nil,
                cpuWatts: Double? = nil, gpuWatts: Double? = nil, fans: [FanReading] = []) {
        self.gpu = gpu
        self.cpuTemperature = cpuTemperature
        self.gpuTemperature = gpuTemperature
        self.cpuWatts = cpuWatts
        self.gpuWatts = gpuWatts
        self.fans = fans
    }
}

public struct FanReading: Sendable, Equatable {
    public var rpm: Double
    public var min: Double
    public var max: Double

    public init(rpm: Double, min: Double = 0, max: Double) {
        self.rpm = rpm
        self.min = min
        self.max = max
    }

    /// Share of the top speed, 0…1.
    public var speed: Double { max > 0 ? Swift.min(rpm / max, 1) : 0 }
}

/// Camera, microphone, and sleep state (S-019).
public struct PrivacyReading: Sendable, Equatable {
    public var cameraInUse: Bool
    public var micInUse: Bool
    /// Names of processes keeping the Mac or its screen awake.
    public var keepingAwake: [String]
    public var keepingScreenOn: [String]

    public init(cameraInUse: Bool = false, micInUse: Bool = false,
                keepingAwake: [String] = [], keepingScreenOn: [String] = []) {
        self.cameraInUse = cameraInUse
        self.micInUse = micInUse
        self.keepingAwake = keepingAwake
        self.keepingScreenOn = keepingScreenOn
    }
}

/// When to read processes: at most every 2 s, even at a 1 s refresh (S-021).
public enum SampleSchedule {
    public static let processInterval: TimeInterval = 2
    public static let intervals: [Int] = [1, 2, 5]

    public static func readProcesses(now: Date, last: Date?) -> Bool {
        guard let last else { return true }
        return now.timeIntervalSince(last) >= processInterval - 0.1
    }
}
