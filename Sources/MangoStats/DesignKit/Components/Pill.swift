import SwiftUI

/// Small grey tag on a card: "45°C", "Wi-Fi", "100% Health" (design/KIT.md, Pill).
struct KitPill: View {
    let text: String
    var hot = false

    var body: some View {
        Text(text)
            .kitType(.pill)
            .foregroundStyle(hot ? Ink.hot : Ink.secondary)
            .lineLimit(1)
            .padding(.horizontal, Metric.pillPadding)
            .frame(height: Metric.pillHeight)
            .background(Ink.pillFill, in: RoundedRectangle(cornerRadius: Metric.pillRadius, style: .continuous))
    }
}

/// Larger tag in the popover header: "M5", "24 GB", "macOS 26.6.2".
struct KitChip: View {
    let text: String

    var body: some View {
        Text(text)
            .kitType(.chip)
            .foregroundStyle(Ink.secondary)
            .lineLimit(1)
            .padding(.horizontal, Metric.chipPadding)
            .frame(height: Metric.chipHeight)
            .background(Ink.pillFill, in: RoundedRectangle(cornerRadius: Metric.chipRadius, style: .continuous))
    }
}
