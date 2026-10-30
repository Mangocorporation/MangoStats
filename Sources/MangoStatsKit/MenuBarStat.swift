import Foundation

/// A stat that can show in the menu bar item. The order of `allCases` is the
/// default order in Settings > Menu Bar.
public enum MenuBarStat: String, CaseIterable, Codable, Sendable, Identifiable {
    case cpu, gpu, memory, disk, network, temperature, fan, battery

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: "Memory"
        case .disk: "Disk"
        case .network: "Network"
        case .temperature: "Temperature"
        case .fan: "Fan"
        case .battery: "Battery"
        }
    }
}

/// How each stat shows in the menu bar.
public enum MenuBarStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case iconAndValue, valueOnly

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .iconAndValue: "Icon and Value"
        case .valueOnly: "Value Only"
        }
    }
}

/// Which stats the menu bar item shows, in order. Saved as a comma list of
/// raw values, so unknown or repeated keys from older versions drop out.
public struct MenuBarLayout: Equatable, Sendable {
    /// Every stat in the order people arranged them.
    public var order: [MenuBarStat]
    /// The stats that are on.
    public var enabled: Set<MenuBarStat>

    public static let `default` = MenuBarLayout(order: MenuBarStat.allCases, enabled: [.cpu, .memory])

    public init(order: [MenuBarStat], enabled: Set<MenuBarStat>) {
        // Keep each stat once, then add any stat missing from the saved order.
        var seen = Set<MenuBarStat>()
        var clean = order.filter { seen.insert($0).inserted }
        clean += MenuBarStat.allCases.filter { !seen.contains($0) }
        self.order = clean
        self.enabled = enabled
    }

    /// The stats to draw, left to right.
    public var visible: [MenuBarStat] { order.filter(enabled.contains) }

    public var encodedOrder: String { order.map(\.rawValue).joined(separator: ",") }
    public var encodedEnabled: String { visible.map(\.rawValue).joined(separator: ",") }

    public init(encodedOrder: String?, encodedEnabled: String?) {
        guard let encodedOrder, let encodedEnabled else {
            self = .default
            return
        }
        func parse(_ text: String) -> [MenuBarStat] {
            text.split(separator: ",").compactMap { MenuBarStat(rawValue: String($0)) }
        }
        self.init(order: parse(encodedOrder), enabled: Set(parse(encodedEnabled)))
    }

    /// Moves rows like `List.onMove` does.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { order[$0] }
        let before = source.filter { $0 < destination }.count
        order = order.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        order.insert(contentsOf: moving, at: destination - before)
    }
}
