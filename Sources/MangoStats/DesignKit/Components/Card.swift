import SwiftUI
import MangoStatsKit

/// Where a card sits: the window's larger cards or the popover's compact ones.
enum CardStyle {
    case window, popover

    var height: CGFloat { self == .window ? Metric.statHeight : Metric.popCardHeight }
    var header: KitType { self == .window ? .statLabel : .popLabel }
    var hero: KitType { self == .window ? .statValue : .popValue }
    var padding: CGFloat { self == .window ? Metric.cardPadding : Metric.popCardPadding }
    var paddingBottom: CGFloat { self == .window ? Metric.cardPaddingBottom : Metric.popCardPaddingBottom }
    var chartHeight: CGFloat { self == .window ? Metric.chartHeight : Metric.popChartHeight }
}

/// The card behind every block (design/KIT.md, Card). `tinted` is the insight card.
struct KitCard<Content: View>: View {
    var style: CardStyle = .window
    var height: CGFloat?
    /// Grow to the content instead of the style's fixed height (lists).
    var fitsContent = false
    var tinted = false
    var padding: CGFloat?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding([.top, .horizontal], padding ?? style.padding)
            .padding(.bottom, padding ?? style.paddingBottom)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: fitsContent ? nil : height ?? style.height, alignment: .top)
            .background(Ink.cardFill, in: shape)
            .background(tinted ? Ink.insightFill : .clear, in: shape)
            .overlay(shape.strokeBorder(tinted ? Ink.insightStroke : Ink.cardStroke, lineWidth: Metric.cardStroke))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
    }
}

/// "CPU" on the left, a mono detail on the right ("37°C", "Wi-Fi", "100% health").
struct CardHeader<Trailing: View>: View {
    let title: String
    var style: CardStyle = .window
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metric.iconGap) {
            Text(L10n.t(title))
                .kitType(style.header)
                .foregroundStyle(Ink.secondary)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 2)
            trailing
        }
    }
}

extension CardHeader where Trailing == KitPill? {
    init(title: String, detail: String?, hot: Bool = false, style: CardStyle = .window) {
        self.title = title
        self.style = style
        self.trailing = detail.map { KitPill(text: $0, hot: hot) }
    }
}

/// A mono detail in a card header. No fill, like the reference.
struct KitPill: View {
    let text: String
    var hot = false

    var body: some View {
        Text(L10n.t(text))
            .kitType(.pill)
            .foregroundStyle(hot ? Ink.hot : Ink.secondary)
            .lineLimit(1)
            .fixedSize()
    }
}

/// The big number with its small unit: "11 %", "3 KB/s".
struct HeroValue: View {
    let value: String
    var unit: String?
    var role: KitType = .statValue

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metric.unitGap) {
            Text(value)
                .kitType(role)
                .foregroundStyle(value == "--" ? Ink.faint : Ink.text)
            if let unit {
                Text(L10n.t(unit))
                    .kitType(.statUnit)
                    .foregroundStyle(Ink.secondary)
            }
        }
    }
}

/// The bottom line of a card.
struct CardFooter: View {
    let leading: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(L10n.t(leading)).lineLimit(1).layoutPriority(1)
            Spacer(minLength: Metric.iconGap)
            if let trailing { Text(trailing).lineLimit(1) }
        }
        .kitType(.footer)
        .foregroundStyle(Ink.secondary)
    }
}

/// "● Live · every 2 s" (design/KIT.md, Live pill).
struct LivePill: View {
    let text: String

    var body: some View {
        HStack(spacing: Metric.iconGap) {
            Circle().fill(Ink.live).frame(width: Metric.iconGap, height: Metric.iconGap)
            Text(L10n.t(text))
        }
        .kitType(.segment)
        .foregroundStyle(Ink.live)
        .padding(.horizontal, Metric.pillPadding + 4)
        .frame(height: Metric.liveHeight)
        .background(Capsule().fill(Ink.liveFill))
    }
}

/// Small capitals with an icon above the insight title: "⚠ MEMORY IS TIGHT".
struct Eyebrow: View {
    let text: String
    var icon: KitIcon?
    var color: Color = Ink.secondary

    var body: some View {
        HStack(spacing: Metric.iconGap + 2) {
            if let icon { icon.view(size: Metric.iconSize + 1, color: color) }
            Text(L10n.t(text)).kitType(.eyebrow)
        }
        .foregroundStyle(color)
    }
}
