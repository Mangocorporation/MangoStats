import SwiftUI

/// Search field in the process table header (design/KIT.md, Search field).
struct KitSearchField: View {
    @Binding var text: String
    var prompt: String
    var focused: FocusState<Bool>.Binding
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: Metric.iconGap) {
            KitIcon.search.view()
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .kitType(.rowNumber)
                .foregroundStyle(Ink.text)
                .focused(focused)
                .onExitCommand(perform: onClear)
            if !text.isEmpty {
                Button("Clear Search", systemImage: KitIcon.clear.symbol, action: onClear)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(Ink.secondary)
                    .help("Clear the search (Esc)")
            }
        }
        .padding(.horizontal, Metric.pillPadding)
        .frame(width: Metric.searchWidth, height: Metric.segmentHeight)
        .background(Ink.pillFill, in: RoundedRectangle(cornerRadius: Metric.pillRadius, style: .continuous))
    }
}

/// A column title that sorts the table when clicked (design/KIT.md, Column header).
struct ColumnHeaderButtonStyle: ButtonStyle {
    var active: Bool
    var descending: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.label
            if active {
                (descending ? KitIcon.sortDown : KitIcon.sortUp).view(size: 8, color: Ink.label)
            }
        }
        .kitType(.columnHeader)
        .foregroundStyle(active ? Ink.label : Ink.tertiary)
        .opacity(configuration.isPressed ? 0.6 : 1)
        .contentShape(Rectangle())
    }
}
