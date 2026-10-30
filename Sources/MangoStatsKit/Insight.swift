import Foundation

/// The one thing worth a look, shown in the Overview's insight card and the
/// popover's header (design/KIT.md, Insight card). Calm when nothing is.
public struct Insight: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case calm, memory, disk, hot, busyApp, battery, network
    }

    public var kind: Kind
    /// Small capitals above the title: "Memory is tight".
    public var eyebrow: String
    public var title: String
    public var body: String
    /// The app the primary button reviews ("Review Chrome"), if any.
    public var app: String?

    public var isCalm: Bool { kind == .calm }

    public static var calm: Insight {
        Insight(kind: .calm, eyebrow: L10n.t("All good"), title: L10n.t("Nothing needs a look"),
                body: L10n.t("Memory, storage, and temperatures are fine."), app: nil)
    }

    public init(kind: Kind, eyebrow: String, title: String, body: String, app: String?) {
        self.kind = kind
        self.eyebrow = eyebrow
        self.title = title
        self.body = body
        self.app = app
    }

    /// What the Overview says, most urgent first.
    public struct Input: Sendable {
        public var memoryFraction: Double
        public var swap: Int64
        public var pressure: MemoryPressure
        public var diskFree: Int64?
        public var diskTotal: Int64?
        public var cpuTemperature: Double?
        /// Largest app by memory, and by CPU (% of one core).
        public var topMemory: (name: String, bytes: Int64)?
        public var topCPU: (name: String, cpu: Double)?
        public var battery: (percent: Int, onBattery: Bool)?

        public init(memoryFraction: Double, swap: Int64, pressure: MemoryPressure, diskFree: Int64? = nil,
                    diskTotal: Int64? = nil, cpuTemperature: Double? = nil, topMemory: (name: String, bytes: Int64)? = nil,
                    topCPU: (name: String, cpu: Double)? = nil, battery: (percent: Int, onBattery: Bool)? = nil) {
            self.memoryFraction = memoryFraction
            self.swap = swap
            self.pressure = pressure
            self.diskFree = diskFree
            self.diskTotal = diskTotal
            self.cpuTemperature = cpuTemperature
            self.topMemory = topMemory
            self.topCPU = topCPU
            self.battery = battery
        }
    }

    /// Every issue that's worth a look, most urgent first.
    public static func all(_ input: Input, locale: Locale = .current) -> [Insight] {
        var found: [Insight] = []
        let percent = Int((input.memoryFraction * 100).rounded())
        if input.pressure != .normal || input.memoryFraction >= 0.85 || input.swap > 2 << 30 {
            let full = input.swap > 0
                ? L10n.f("Memory is %ld%% full and macOS has moved %@ to swap.", percent, Format.bytes(input.swap, digits: 2, locale: locale))
                : L10n.f("Memory is %ld%% full.", percent)
            let advice = L10n.t("Quitting what you aren't using is the quickest way to get memory back.")
            if let top = input.topMemory {
                found.append(Insight(kind: .memory, eyebrow: L10n.t("Memory is tight"),
                                     title: L10n.f("%@ is holding %@", top.name, Format.bytes(top.bytes, digits: 1, locale: locale)),
                                     body: full + " " + advice, app: top.name))
            } else {
                found.append(Insight(kind: .memory, eyebrow: L10n.t("Memory is tight"),
                                     title: L10n.f("Memory is %ld%% full", percent), body: advice, app: nil))
            }
        }
        if let temperature = input.cpuTemperature, temperature >= 90 {
            let culprit = input.topCPU.map { " " + L10n.f("%@ is using the most CPU.", $0.name) } ?? ""
            found.append(Insight(kind: .hot, eyebrow: L10n.t("Running hot"),
                                 title: L10n.f("CPU is at %ld°C", Int(temperature.rounded())),
                                 body: L10n.t("The Mac may slow down to cool off.") + culprit, app: input.topCPU?.name))
        }
        if let top = input.topCPU, top.cpu >= 80 {
            found.append(Insight(kind: .busyApp, eyebrow: L10n.t("Busy app"),
                                 title: L10n.f("%@ is using %ld%% CPU", top.name, Int(top.cpu.rounded())),
                                 body: L10n.t("If it isn't doing something you asked for, quitting it gives the time back."),
                                 app: top.name))
        }
        if let free = input.diskFree, let total = input.diskTotal, total > 0, Double(free) / Double(total) < 0.10 {
            found.append(Insight(kind: .disk, eyebrow: L10n.t("Storage is filling up"),
                                 title: L10n.f("%@ free", Format.bytes(free, binary: false, digits: 0, locale: locale)),
                                 body: L10n.t("Below 10% free, macOS can't keep caches and updates may fail."), app: nil))
        }
        if let battery = input.battery, battery.onBattery, battery.percent <= 20 {
            found.append(Insight(kind: .battery, eyebrow: L10n.t("Battery is low"), title: L10n.f("%ld%% left", battery.percent),
                                 body: L10n.t("Connect power to keep working."), app: nil))
        }
        return found
    }
}
