import Foundation

/// The last samples of one stat, oldest first (S-003).
public struct History: Equatable, Sendable {
    public let capacity: Int
    public private(set) var values: [Double] = []

    public init(capacity: Int = 60) {
        self.capacity = capacity
    }

    public mutating func append(_ value: Double) {
        values.append(value)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
    }
}

/// One core's tick counters from `host_processor_info`.
public struct CPUTicks: Equatable, Sendable {
    public var user, system, idle, nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

public enum CPUUsage {
    /// Busy share of all cores between two reads, 0…1 (S-001).
    public static func fraction(previous: [CPUTicks], current: [CPUTicks]) -> Double {
        guard previous.count == current.count, !current.isEmpty else { return 0 }
        var busy: UInt64 = 0
        var total: UInt64 = 0
        for (old, new) in zip(previous, current) {
            // Counters only grow; a smaller value means a reset, so skip that core.
            guard new.user >= old.user, new.system >= old.system, new.idle >= old.idle, new.nice >= old.nice else { continue }
            let used = (new.user - old.user) + (new.system - old.system) + (new.nice - old.nice)
            busy += used
            total += used + (new.idle - old.idle)
        }
        return total == 0 ? 0 : Double(busy) / Double(total)
    }

    /// "idle" under 20 %, "normal" up to 60 %, "busy" above (S-003).
    public static func label(_ fraction: Double) -> String {
        switch fraction {
        case ..<0.2: "idle"
        case ...0.6: "normal"
        default: "busy"
        }
    }
}

/// macOS memory pressure, from `kern.memorystatus_vm_pressure_level` (S-004).
public enum MemoryPressure: Int, Sendable {
    case normal = 1, warning = 2, critical = 4

    public init(level: Int) {
        self = MemoryPressure(rawValue: level) ?? .normal
    }

    public var title: String {
        switch self {
        case .normal: "Normal"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }
}

/// How fast the internet answers (S-006).
public enum Latency {
    public static func label(milliseconds: Double?) -> String {
        guard let milliseconds else { return "Offline" }
        switch milliseconds {
        case ..<50: return "Low Lag"
        case ..<150: return "Medium Lag"
        default: return "High Lag"
        }
    }
}

public enum Rate {
    /// Bytes per second between two counter reads; 0 when a counter went back (reset).
    public static func perSecond(previous: UInt64, current: UInt64, seconds: Double) -> Double {
        guard seconds > 0, current >= previous else { return 0 }
        return Double(current - previous) / seconds
    }
}

public enum Battery {
    /// Max capacity as a share of design capacity, in whole percent, at most 100 (S-007).
    public static func health(maxCapacity: Int, designCapacity: Int) -> Int {
        guard designCapacity > 0, maxCapacity > 0 else { return 0 }
        return min(100, Int((Double(maxCapacity) / Double(designCapacity) * 100).rounded()))
    }
}

/// The health score (S-002): 100 minus a penalty per problem, with the reasons.
public struct Health: Equatable, Sendable {
    public struct Input: Sendable {
        public var pressure: MemoryPressure
        public var diskFreeFraction: Double
        public var diskFreeBytes: Int64
        public var swapBytes: Int64
        public var cpuTemperature: Double?
        /// Average CPU over the last minute, 0…1.
        public var sustainedCPU: Double

        public init(pressure: MemoryPressure, diskFreeFraction: Double, diskFreeBytes: Int64, swapBytes: Int64,
                    cpuTemperature: Double?, sustainedCPU: Double) {
            self.pressure = pressure
            self.diskFreeFraction = diskFreeFraction
            self.diskFreeBytes = diskFreeBytes
            self.swapBytes = swapBytes
            self.cpuTemperature = cpuTemperature
            self.sustainedCPU = sustainedCPU
        }
    }

    public let score: Int
    public let reasons: [String]

    public var word: String {
        switch score {
        case 80...: "Good"
        case 60...: "Fair"
        default: "Poor"
        }
    }

    public init(_ input: Input, locale: Locale = .current) {
        var score = 100
        var reasons: [String] = []
        switch input.pressure {
        case .warning: score -= 15; reasons.append("Memory pressure high")
        case .critical: score -= 30; reasons.append("Memory pressure critical")
        case .normal: break
        }
        if input.diskFreeFraction < 0.10 {
            score -= 20
            reasons.append("Disk space very low · \(Format.bytes(input.diskFreeBytes, binary: false, digits: 0, locale: locale)) Free")
        } else if input.diskFreeFraction < 0.25 {
            score -= 10
            reasons.append("Disk space low · \(Format.bytes(input.diskFreeBytes, binary: false, digits: 0, locale: locale)) Free")
        }
        if input.swapBytes > 2 << 30 {
            score -= 6
            reasons.append("Using swap")
        }
        if let temperature = input.cpuTemperature, temperature > 90 {
            score -= 15
            reasons.append("CPU hot")
        }
        if input.sustainedCPU > 0.8 {
            score -= 10
            reasons.append("CPU busy for a minute")
        }
        self.score = max(0, score)
        self.reasons = reasons
    }
}

public enum Format {
    /// "20,25 GB" in pt_BR, "20.25 GB" in en_US. Memory uses binary units
    /// (24 GB of RAM is 24 GiB), disks use decimal ones, like Finder.
    public static func bytes(_ bytes: Int64, binary: Bool = true, digits: Int = 1, locale: Locale = .current) -> String {
        let base: Double = binary ? 1024 : 1000
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unit = 0
        while value >= base, unit < units.count - 1 {
            value /= base
            unit += 1
        }
        let shown = unit <= 2 ? 0 : digits
        return "\(number(value, digits: shown, locale: locale)) \(units[unit])"
    }

    /// A speed as value and unit: (<1, KB/s), (4, KB/s), (1.2, MB/s) (S-006).
    public static func speed(_ bytesPerSecond: Double, locale: Locale = .current) -> (value: String, unit: String) {
        let kilo = bytesPerSecond / 1000
        if kilo < 1 { return ("<1", "KB/s") }
        if kilo < 1000 { return (number(kilo, digits: 0, locale: locale), "KB/s") }
        return (number(kilo / 1000, digits: 1, locale: locale), "MB/s")
    }

    /// "up 51 days, 10 hrs" (S-002).
    public static func uptime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let days = minutes / 1440
        let hours = minutes % 1440 / 60
        func plural(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }
        if days > 0 { return "up \(plural(days, "day")), \(plural(hours, "hr"))" }
        if hours > 0 { return "up \(plural(hours, "hr")), \(plural(minutes % 60, "min"))" }
        return "up \(plural(minutes, "min"))"
    }

    /// "0.9W", "12W": one decimal under 10 W.
    public static func watts(_ value: Double, locale: Locale = .current) -> String {
        "\(number(value, digits: value < 10 ? 1 : 0, locale: locale))W"
    }

    /// "48°C".
    public static func celsius(_ value: Double) -> String {
        "\(Int(value.rounded()))°C"
    }

    /// "1 h 20 min", "45 min".
    public static func duration(minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    public static func number(_ value: Double, digits: Int, locale: Locale = .current) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).grouping(.never).locale(locale))
    }
}
