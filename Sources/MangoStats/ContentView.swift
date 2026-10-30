import SwiftUI
import MangoStatsKit

/// The menu bar item: the stats people chose in Settings > Menu Bar.
/// Values arrive with the sampler (S-001); until then each shows "--".
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let stats = model.menuBar.visible
        if stats.isEmpty {
            // Never invisible: with every stat off, show the app's symbol.
            KitIcon.chart.image
        } else {
            HStack(spacing: Space.xs) {
                ForEach(stats) { stat in
                    if model.menuBarStyle == .iconAndValue {
                        stat.icon.image
                    }
                    Text("--").monospacedDigit()
                }
            }
        }
    }
}

/// The popover that opens from the menu bar item. Cards arrive with S-002 to S-008.
struct PopoverView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("MangoStats").font(.title2.bold())
            Text("Stats arrive in the next stories.")
                .foregroundStyle(.secondary)
            Divider()
            HStack(spacing: Space.sm) {
                Button("Open MangoStats", systemImage: "macwindow") {
                    NSApp.activate()
                    openWindow(id: "status")
                }
                .keyboardShortcut("1")
                .help("Open the Status window (⌘1)")
                Spacer()
                Button("Settings…", systemImage: "gearshape") {
                    NSApp.activate()
                    openSettings()
                }
                .keyboardShortcut(",")
                .help("Change which stats show in the menu bar (⌘,)")
                Button("Quit MangoStats", systemImage: "power") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
                    .help("Quit MangoStats (⌘Q)")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
        .padding(Space.lg)
        .frame(width: 360)
    }
}
