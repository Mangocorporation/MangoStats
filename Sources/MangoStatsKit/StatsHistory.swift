import Foundation

/// One stored minute of history (S-027). Optional values stay nil when the
/// Mac has no such sensor or nothing was read in that minute.
public struct MinuteSample: Equatable, Sendable {
    /// Start of the minute.
    public var time: Date
    public var cpu: Double
    public var memory: Double
    public var gpu: Double?
    public var cpuTemperature: Double?
    public var gpuTemperature: Double?
    /// Bytes per second.
    public var download: Double
    public var upload: Double
    /// 0…1.
    public var battery: Double?
    public var cpuWatts: Double?
    public var gpuWatts: Double?

    public init(time: Date, cpu: Double, memory: Double, gpu: Double? = nil, cpuTemperature: Double? = nil,
                gpuTemperature: Double? = nil, download: Double = 0, upload: Double = 0, battery: Double? = nil,
                cpuWatts: Double? = nil, gpuWatts: Double? = nil) {
        self.time = time
        self.cpu = cpu
        self.memory = memory
        self.gpu = gpu
        self.cpuTemperature = cpuTemperature
        self.gpuTemperature = gpuTemperature
        self.download = download
        self.upload = upload
        self.battery = battery
        self.cpuWatts = cpuWatts
        self.gpuWatts = gpuWatts
    }
}

/// Averages samples into minutes. `add` returns the finished minute when a
/// sample from a later minute arrives.
public struct MinuteAggregator: Sendable {
    private var minute: Date?
    private var points: [MinuteSample] = []

    public init() {}

    public mutating func add(_ point: MinuteSample) -> MinuteSample? {
        let start = Self.minuteStart(point.time)
        var finished: MinuteSample?
        if let minute, start != minute {
            finished = Self.average(points, at: minute)
            points.removeAll()
        }
        minute = start
        points.append(point)
        return finished
    }

    public static func minuteStart(_ date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded(.down) * 60)
    }

    /// The mean of each value; optional values average only where present.
    public static func average(_ points: [MinuteSample], at time: Date) -> MinuteSample? {
        guard !points.isEmpty else { return nil }
        func mean(_ values: [Double]) -> Double { values.reduce(0, +) / Double(values.count) }
        func mean(_ values: [Double?]) -> Double? {
            let present = values.compactMap { $0 }
            return present.isEmpty ? nil : mean(present)
        }
        return MinuteSample(time: time, cpu: mean(points.map(\.cpu)), memory: mean(points.map(\.memory)),
                            gpu: mean(points.map(\.gpu)), cpuTemperature: mean(points.map(\.cpuTemperature)),
                            gpuTemperature: mean(points.map(\.gpuTemperature)), download: mean(points.map(\.download)),
                            upload: mean(points.map(\.upload)), battery: mean(points.map(\.battery)),
                            cpuWatts: mean(points.map(\.cpuWatts)), gpuWatts: mean(points.map(\.gpuWatts)))
    }
}

/// The time span shown on the History page (S-028).
public enum HistoryRange: String, CaseIterable, Sendable, Identifiable {
    case hour, day, week, month

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hour: L10n.t("Hour")
        case .day: L10n.t("Day")
        case .week: L10n.t("Week")
        case .month: L10n.t("Month")
        }
    }

    public var duration: TimeInterval {
        switch self {
        case .hour: 3_600
        case .day: 86_400
        case .week: 7 * 86_400
        case .month: 30 * 86_400
        }
    }

    /// Bucket size, so a range draws at most ~180 points.
    public var bucket: TimeInterval {
        switch self {
        case .hour: 60
        case .day: 600
        case .week: 3_600
        case .month: 4 * 3_600
        }
    }

    /// Averages minutes into the range's buckets, oldest first. Buckets with
    /// no minutes are left out, so the charts break where the Mac slept.
    public func downsample(_ minutes: [MinuteSample], now: Date) -> [MinuteSample] {
        let start = now.addingTimeInterval(-duration)
        var buckets: [Int: [MinuteSample]] = [:]
        for minute in minutes where minute.time >= start && minute.time <= now {
            buckets[Int(minute.time.timeIntervalSince1970 / bucket), default: []].append(minute)
        }
        return buckets.keys.sorted().compactMap { key in
            MinuteAggregator.average(buckets[key]!, at: Date(timeIntervalSince1970: Double(key) * bucket))
        }
    }
}

/// How long history is kept (S-030).
public enum HistoryRetention {
    public static let choices = [7, 30, 90]
    public static let defaultDays = 30

    public static func cutoff(days: Int, now: Date) -> Date {
        now.addingTimeInterval(-Double(days) * 86_400)
    }
}
