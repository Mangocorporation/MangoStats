import AppKit
import SwiftUI
import MangoStatsKit

/// The menu bar item: the stats people chose in Settings > Menu Bar (S-001, S-009).
/// MenuBarExtra flattens a label to one image or text, so the stats are
/// drawn into one template image: the menu bar tints it for light and dark.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

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
        .task {
            model.startSampling()
            Profile.start(model: model, openWindow: openWindow)
        }
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
    /// The last image and what it shows: most samples change nothing in the menu bar.
    private static var cache: (key: String, image: NSImage)?

    static func render(stats: [MenuBarStat], values: [MenuBarStat: String], style: MenuBarStyle) -> NSImage {
        let key = "\(style.rawValue)|" + stats.map { "\($0.rawValue)=\(values[$0] ?? "--")" }.joined(separator: ",")
        if let cache, cache.key == key { return cache.image }
        let image = draw(stats: stats, values: values, style: style)
        cache = (key, image)
        return image
    }

    private static func draw(stats: [MenuBarStat], values: [MenuBarStat: String], style: MenuBarStyle) -> NSImage {
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

/// Energy measurement mode for tools/energy.sh (S-023):
///   APP_PROFILE=closed | popover | window
/// keeps the app live with that surface open until it is quit.
enum Profile {
    private static var panel: NSPanel?

    static func start(model: AppModel, openWindow: OpenWindowAction) {
        switch ProcessInfo.processInfo.environment["APP_PROFILE"] {
        case "window":
            openWindow(id: "status")
        case "popover":
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
            panel.contentView = NSHostingView(rootView: PopoverView().environment(model).themed())
            panel.setContentSize(panel.contentView?.fittingSize ?? .zero)
            panel.center()
            panel.orderFrontRegardless()
            self.panel = panel
        default:
            break
        }
    }
}
