import SwiftUI
import MangoStatsKit

/// Every icon in the app. Views name a KitIcon, never an SF Symbol, so the
/// whole set can change here. SF Symbols, regular weight (design/KIT.md, Icons).
enum KitIcon: String, CaseIterable {
    case cpu, gpu, memory, disk, network, fan, battery, health, bolt, laptop, waves
    case camera, mic, awake, display, search, more, window, gear, power, chart, thermometer

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .gpu: "rectangle.3.group"
        case .memory: "memorychip"
        case .disk: "internaldrive"
        case .network: "globe"
        case .fan: "fan"
        case .battery: "battery.100percent"
        case .health: "sun.max"
        case .bolt: "bolt.fill"
        case .laptop: "laptopcomputer"
        case .waves: "dot.radiowaves.right"
        case .camera: "camera"
        case .mic: "mic"
        case .awake: "cup.and.heat.waves"
        case .display: "display"
        case .search: "magnifyingglass"
        case .more: "ellipsis"
        case .window: "macwindow"
        case .gear: "gearshape"
        case .power: "power"
        case .chart: "chart.bar.xaxis"
        case .thermometer: "thermometer.medium"
        }
    }

    var image: Image { Image(systemName: symbol) }
}

extension KitIcon {
    /// An icon at the kit's size and weight.
    func view(size: CGFloat = Metric.iconSize, color: Color = Ink.secondary) -> some View {
        image
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

extension MenuBarStat {
    /// The kit icon for a stat in the menu bar and Settings.
    var icon: KitIcon {
        switch self {
        case .cpu: .cpu
        case .gpu: .gpu
        case .memory: .memory
        case .disk: .disk
        case .network: .network
        case .temperature: .thermometer
        case .fan: .fan
        case .battery: .battery
        }
    }
}
