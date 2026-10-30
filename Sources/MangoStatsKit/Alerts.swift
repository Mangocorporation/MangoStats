import Foundation

/// The alert rules (S-032, S-034).
public enum AlertKind: String, CaseIterable, Sendable, Identifiable, Codable {
    case memoryPressure, cpuHot, cpuBusy, diskLow, batteryLow, busyApp

    public var id: String { rawValue }

    /// The Settings row title.
    public var title: String {
        switch self {
        case .memoryPressure: L10n.t("Memory pressure is critical")
        case .cpuHot: L10n.t("CPU temperature above")
        case .cpuBusy: L10n.t("CPU busy above")
        case .diskLow: L10n.t("Disk space below")
        case .batteryLow: L10n.t("Battery below")
        case .busyApp: L10n.t("An app uses more than")
        }
    }

    /// Threshold choices; memory pressure has none.
    public var choices: [Double] {
        switch self {
        case .memoryPressure: []
        case .cpuHot: [90, 95]
        case .cpuBusy: [0.8, 0.9]
        case .diskLow: [5, 10, 20]
        case .batteryLow: [10, 20]
        case .busyApp: [50, 80, 100]
        }
    }

    public var defaultThreshold: Double {
        switch self {
        case .memoryPressure: 0
        case .cpuHot: 90
        case .cpuBusy: 0.9
        case .diskLow: 10
        case .batteryLow: 20
        case .busyApp: 80
        }
    }

    /// How long the condition must hold before the alert shows.
    public var sustain: TimeInterval {
        switch self {
        case .cpuHot: 60
        case .cpuBusy, .busyApp: 300
        default: 0
        }
    }

    /// "90°C", "90 %", "10 GB", "20 %", "80 % CPU".
    public func label(_ value: Double) -> String {
        switch self {
        case .memoryPressure: ""
        case .cpuHot: "\(Int(value))°C"
        case .cpuBusy: "\(Int((value * 100).rounded())) %"
        case .diskLow: "\(Int(value)) GB"
        case .batteryLow: "\(Int(value)) %"
        case .busyApp: "\(Int(value)) % CPU"
        }
    }
}

/// What people chose in Settings → Alerts.
public struct AlertSettings: Equatable, Sendable, Codable {
    /// The master switch. Off by default: nothing asks for permission at launch (S-031).
    public var showAlerts = false
    public var enabled: Set<AlertKind> = [.memoryPressure, .cpuHot, .diskLow, .busyApp]
    public var thresholds: [AlertKind: Double] = [:]

    public init() {}

    public func threshold(_ kind: AlertKind) -> Double {
        let value = thresholds[kind] ?? kind.defaultThreshold
        return kind.choices.isEmpty || kind.choices.contains(value) ? value : kind.defaultThreshold
    }

    public func isOn(_ kind: AlertKind) -> Bool { showAlerts && enabled.contains(kind) }

    /// Saved as JSON; anything unreadable falls back to the defaults.
    public static func decode(_ data: Data?) -> AlertSettings {
        data.flatMap { try? JSONDecoder().decode(AlertSettings.self, from: $0) } ?? AlertSettings()
    }

    public var encoded: Data? { try? JSONEncoder().encode(self) }
}

/// One sample of what the rules look at.
public struct AlertInput: Sendable {
    public var time: Date
    public var cpu: Double?
    public var pressure: MemoryPressure
    public var cpuTemperature: Double?
    public var diskFree: Int64?
    /// Percent, and whether the Mac runs on battery.
    public var battery: (percent: Int, onBattery: Bool, minutesLeft: Int?)?
    /// The app using the most CPU (% of one core), and the one using the most memory.
    public var topCPU: (name: String, cpu: Double)?
    public var topMemory: String?

    public init(time: Date, cpu: Double? = nil, pressure: MemoryPressure = .normal, cpuTemperature: Double? = nil,
                diskFree: Int64? = nil, battery: (percent: Int, onBattery: Bool, minutesLeft: Int?)? = nil,
                topCPU: (name: String, cpu: Double)? = nil, topMemory: String? = nil) {
        self.time = time
        self.cpu = cpu
        self.pressure = pressure
        self.cpuTemperature = cpuTemperature
        self.diskFree = diskFree
        self.battery = battery
        self.topCPU = topCPU
        self.topMemory = topMemory
    }
}

public struct AlertEvent: Equatable, Sendable {
    public var kind: AlertKind
    public var title: String
    public var body: String
    /// For a busy-app alert: the app, so a click can filter the process table (S-033).
    public var app: String?

    public init(kind: AlertKind, title: String, body: String, app: String? = nil) {
        self.kind = kind
        self.title = title
        self.body = body
        self.app = app
    }
}

/// Decides when to show alerts (S-032). Each rule fires once per episode:
/// the condition must clear (with a margin) before it can fire again, and
/// never sooner than `cooldown` after the last time.
public struct AlertEngine: Sendable {
    public static let cooldown: TimeInterval = 30 * 60

    private var since: [AlertKind: Date] = [:]
    private var firedThisEpisode: Set<AlertKind> = []
    private var lastFired: [AlertKind: Date] = [:]
    /// The busy app being timed; a different app restarts the timer.
    private var busyAppName: String?
    private var cpuSum: (total: Double, count: Int) = (0, 0)

    public init() {}

    public mutating func evaluate(_ input: AlertInput, settings: AlertSettings) -> [AlertEvent] {
        guard settings.showAlerts else { return [] }
        var events: [AlertEvent] = []
        for kind in AlertKind.allCases where settings.enabled.contains(kind) {
            let threshold = settings.threshold(kind)
            switch state(kind, input, threshold) {
            case .clear:
                since[kind] = nil
                firedThisEpisode.remove(kind)
                if kind == .cpuBusy { cpuSum = (0, 0) }
            case .between:
                break   // inside the margin: keep the episode, don't start a new one
            case .active:
                let start = since[kind] ?? input.time
                since[kind] = start
                if kind == .cpuBusy, let cpu = input.cpu { cpuSum = (cpuSum.total + cpu, cpuSum.count + 1) }
                guard input.time.timeIntervalSince(start) >= kind.sustain, !firedThisEpisode.contains(kind),
                      lastFired[kind].map({ input.time.timeIntervalSince($0) >= Self.cooldown }) ?? true
                else { continue }
                firedThisEpisode.insert(kind)
                lastFired[kind] = input.time
                events.append(event(kind, input, threshold))
            }
        }
        return events
    }

    private enum State { case clear, between, active }

    private mutating func state(_ kind: AlertKind, _ input: AlertInput, _ threshold: Double) -> State {
        func compare(_ value: Double?, on: Double, off: Double, above: Bool = true) -> State {
            guard let value else { return .clear }
            if above ? value >= on : value <= on { return .active }
            return (above ? value < off : value > off) ? .clear : .between
        }
        switch kind {
        case .memoryPressure:
            return input.pressure == .critical ? .active : input.pressure == .normal ? .clear : .between
        case .cpuHot:
            return compare(input.cpuTemperature, on: threshold, off: threshold - 10)
        case .cpuBusy:
            return compare(input.cpu, on: threshold, off: threshold - 0.2)
        case .diskLow:
            return compare(input.diskFree.map { Double($0) / 1e9 }, on: threshold, off: threshold + 2, above: false)
        case .batteryLow:
            guard let battery = input.battery, battery.onBattery else { return .clear }
            return compare(Double(battery.percent), on: threshold, off: threshold + 5, above: false)
        case .busyApp:
            guard let top = input.topCPU else { return .between }
            if top.name != busyAppName {
                busyAppName = top.name
                since[.busyApp] = nil
                firedThisEpisode.remove(.busyApp)
            }
            return compare(top.cpu, on: threshold, off: threshold * 0.6)
        }
    }

    private func event(_ kind: AlertKind, _ input: AlertInput, _ threshold: Double) -> AlertEvent {
        let topCPU = input.topCPU.map { " " + L10n.f("Top CPU: %@.", $0.name) } ?? ""
        switch kind {
        case .memoryPressure:
            let top = input.topMemory.map { " " + L10n.f("Most memory: %@.", $0) } ?? ""
            return AlertEvent(kind: kind, title: L10n.t("Memory pressure is critical"),
                              body: L10n.t("The Mac is short on memory and may slow down. Quit apps you don't need.") + top)
        case .cpuHot:
            let temperature = Int((input.cpuTemperature ?? threshold).rounded())
            return AlertEvent(kind: kind, title: L10n.f("CPU is hot: %ld°C", temperature),
                              body: L10n.f("Above %ld°C for a minute.", Int(threshold)) + topCPU)
        case .cpuBusy:
            let average = cpuSum.count > 0 ? cpuSum.total / Double(cpuSum.count) : input.cpu ?? threshold
            return AlertEvent(kind: kind, title: L10n.t("CPU busy for 5 minutes"),
                              body: L10n.f("Average %ld %%.", Int((average * 100).rounded())) + topCPU)
        case .diskLow:
            let free = Int((Double(input.diskFree ?? 0) / 1e9).rounded())
            return AlertEvent(kind: kind, title: L10n.f("Disk space low: %ld GB free", free),
                              body: L10n.t("Empty the Trash or move large files to make room."))
        case .batteryLow:
            let percent = input.battery?.percent ?? Int(threshold)
            let left = input.battery?.minutesLeft.map { L10n.f("About %@ left.", Format.duration(minutes: $0)) + " " } ?? ""
            return AlertEvent(kind: kind, title: L10n.f("Battery at %ld %%", percent), body: left + L10n.t("Connect power to keep working."))
        case .busyApp:
            let name = input.topCPU?.name ?? L10n.t("An app")
            let cpu = Int((input.topCPU?.cpu ?? threshold).rounded())
            return AlertEvent(kind: kind, title: L10n.f("%@ is using %ld %% CPU", name, cpu),
                              body: L10n.t("For 5 minutes. Click to see it in MangoStats."), app: name)
        }
    }
}
