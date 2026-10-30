import SwiftUI
import MangoStatsKit

/// The Status window's top switch, "Status | History" (design/KIT.md, Tab bar):
/// a capsule track, the selected tab a white pill with dark text.
struct KitTabBar<Tab: Hashable & Identifiable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let title: (Tab) -> String
    @Environment(\.kitForcedState) private var forced

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                let selected = tab == selection
                Button(L10n.t(title(tab))) { selection = tab }
                    .buttonStyle(TabButtonStyle(selected: selected))
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                    .help(L10n.f("Show %@ (⌘%ld)", L10n.t(title(tab)), index + 1))
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(Ink.cardFill))
        .overlay(Capsule().strokeBorder(Ink.cardStroke, lineWidth: Metric.cardStroke))
    }
}

private struct TabButtonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .kitType(.segment)
            .foregroundStyle(selected ? Ink.tabSelectedText : Ink.label)
            .padding(.horizontal, Metric.tabPadding)
            .frame(height: Metric.tabHeight)
            .background(Capsule().fill(selected ? Ink.tabSelected : configuration.isPressed ? Ink.controlPressed : .clear))
            .contentShape(Capsule())
    }
}
