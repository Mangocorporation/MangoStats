import Foundation

/// The fan modes people pick on the Fan card (S-025).
public enum FanMode: Int, CaseIterable, Sendable, Identifiable {
    case auto = 0, cool = 1, max = 2

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .auto: L10n.t("Auto")
        case .cool: L10n.t("Cool")
        case .max: L10n.t("Max")
        }
    }

    public var help: String {
        switch self {
        case .auto: L10n.t("Let macOS control the fan")
        case .cool: L10n.t("Run the fan at 60 % for cooler temperatures")
        case .max: L10n.t("Run the fan at full speed")
        }
    }
}

/// Safety rules for fan control, shared by the app and the root helper (S-025, S-026).
/// Cool and Max only ever add cooling; anything unclear falls back to Auto.
public enum FanPolicy {
    /// Cool runs at this share of the range between the fan's min and max.
    public static let coolShare = 0.6
    /// The helper returns to Auto when the app hasn't asked for a mode this long.
    public static let pingTimeout: TimeInterval = 15
    /// In Cool, a CPU this hot switches to Max until it cools below `hotOff`.
    public static let hotOn = 90.0
    public static let hotOff = 80.0

    /// RPM to ask for, or nil for Auto. Never below the fan's minimum.
    public static func target(_ mode: FanMode, min: Double, max: Double) -> Double? {
        guard max > 0 else { return nil }
        switch mode {
        case .auto: return nil
        case .cool: return Swift.max(min, min + coolShare * (max - min)).rounded()
        case .max: return max
        }
    }

    /// The mode to apply now, from what the app asked for and when.
    /// `boosted` is the hot override's memory between calls.
    public static func effective(requested: FanMode, lastPing: Date?, now: Date, cpuTemperature: Double?,
                                 boosted: Bool) -> (mode: FanMode, boosted: Bool) {
        guard let lastPing, now.timeIntervalSince(lastPing) < pingTimeout else { return (.auto, false) }
        guard requested == .cool, let temperature = cpuTemperature else { return (requested, false) }
        let hot = boosted ? temperature >= hotOff : temperature >= hotOn
        return (hot ? .max : .cool, hot)
    }

    /// The Fan card's note: "Managed by macOS", "Cool · 4,800 RPM target".
    public static func note(_ mode: FanMode, min: Double, max: Double, locale: Locale = .current) -> String {
        guard let target = target(mode, min: min, max: max) else { return L10n.t("Managed by macOS") }
        let rpm = target.formatted(.number.precision(.fractionLength(0)).locale(locale))
        return L10n.f("%@ · %@ RPM target", mode.title, rpm)
    }
}
