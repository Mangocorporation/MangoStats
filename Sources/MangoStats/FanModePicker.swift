import SwiftUI
import MangoStatsKit

/// The Fan card's mode, "Auto", as a menu: Auto, Cool, Max (S-025).
/// Without the helper, Cool and Max are off and say where to turn fan control on.
struct FanModeMenu: View {
    private var fan = FanControl.shared

    var body: some View {
        Menu {
            ForEach(FanMode.allCases) { mode in
                Toggle(isOn: Binding(get: { fan.wanted == mode }, set: { if $0 { fan.pick(mode) } })) {
                    Text(mode.title)
                    Text(mode.help)
                }
                .disabled(mode != .auto && fan.state != .on)
            }
            if fan.state != .on {
                Divider()
                Text("Allow fan control in Settings › General")
            }
        } label: {
            HStack(spacing: 2) {
                Text(fan.applied == fan.wanted ? fan.wanted.title : L10n.f("%@ (hot)", fan.applied.title))
                KitIcon.sortDown.view(size: 7, color: Ink.secondary)
            }
            .kitType(.pill)
            .foregroundStyle(fan.wanted == .auto ? Ink.secondary : Ink.accent)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Fan mode: Auto lets macOS decide; Cool and Max add cooling")
        .accessibilityLabel("Fan mode \(fan.wanted.title)")
    }
}
