import SwiftUI
import MangoStatsKit

/// The process filter field (design/KIT.md, Field).
struct KitSearchField: View {
    @Binding var text: String
    var prompt: String
    var focused: FocusState<Bool>.Binding
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: Metric.iconGap + 2) {
            KitIcon.search.view(size: Metric.iconSize + 1)
            TextField(L10n.t(prompt), text: $text)
                .textFieldStyle(.plain)
                .kitType(.segment)
                .foregroundStyle(Ink.text)
                .focused(focused)
                .onExitCommand(perform: onClear)
            if !text.isEmpty {
                Button("Clear Filter", systemImage: KitIcon.clear.symbol, action: onClear)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(Ink.secondary)
                    .help("Clear the filter (Esc)")
            }
        }
        .padding(.horizontal, Metric.segmentPadding)
        .frame(width: Metric.fieldWidth, height: Metric.segmentHeight + Metric.segmentInset * 2)
        .background(RoundedRectangle(cornerRadius: Metric.segmentRadius, style: .continuous).fill(Ink.windowBackground))
        .overlay(RoundedRectangle(cornerRadius: Metric.segmentRadius, style: .continuous)
            .strokeBorder(Ink.cardStroke, lineWidth: Metric.cardStroke))
    }
}

/// A column title that sorts the table when clicked.
struct ColumnHeaderButtonStyle: ButtonStyle {
    var active: Bool
    var descending: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.label
            if active {
                (descending ? KitIcon.sortDown : KitIcon.sortUp).view(size: 8, color: Ink.text)
            }
        }
        .kitType(.columnHeader)
        .foregroundStyle(active ? Ink.text : Ink.secondary)
        .opacity(configuration.isPressed ? 0.6 : 1)
        .contentShape(Rectangle())
    }
}
