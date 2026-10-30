import AppKit
import SwiftUI
import MangoStatsKit

/// The menu bar item: the stats people chose in Settings > Menu Bar (S-001, S-009).
/// MenuBarExtra flattens a label to one image or text, so the stats are
/// drawn into one template image: the menu bar tints it for light and dark.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let stats = model.shownStats
        Group {
            if stats.isEmpty {
                // Never invisible: with every stat off, show the app's symbol.
                KitIcon.chart.image
            } else {
                Image(nsImage: MenuBarImage.render(stats: stats, values: model.menuValues, style: model.menuBarStyle))
            }
        }
        .task { model.startSampling() }
        .accessibilityLabel(MenuBarImage.spoken(stats: stats, values: model.menuValues))
    }
}

/// The stats in a row, as the menu bar draws them.
struct MenuBarStatsRow: View {
    let stats: [MenuBarStat]
    let values: [MenuBarStat: String]
    let style: MenuBarStyle

    var body: some View {
        HStack(spacing: Space.sm) {
            ForEach(stats) { stat in
                HStack(spacing: 2) {
                    if style == .iconAndValue {
                        stat.icon.image.font(.system(size: 12, weight: .medium))
                    }
                    Text(values[stat] ?? "--")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                }
            }
        }
        .foregroundStyle(.black)
        .fixedSize()
    }
}

enum MenuBarImage {
    static func render(stats: [MenuBarStat], values: [MenuBarStat: String], style: MenuBarStyle) -> NSImage {
        let renderer = ImageRenderer(content: MenuBarStatsRow(stats: stats, values: values, style: style))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }

    /// "MangoStats, CPU 15 percent, Memory 84 percent" for VoiceOver.
    static func spoken(stats: [MenuBarStat], values: [MenuBarStat: String]) -> String {
        let parts = stats.map { "\($0.title) \((values[$0] ?? "not measured yet").replacingOccurrences(of: "%", with: " percent"))" }
        return (["MangoStats"] + parts).joined(separator: ", ")
    }
}
