import SwiftUI

/// Where a card sits: the Status window uses uppercase tracked headers,
/// the popover uses sentence-case headers and shorter cards.
enum CardStyle {
    case window, popover

    var height: CGFloat { self == .window ? Metric.cardHeight : Metric.popCardHeight }
    var header: KitType { self == .window ? .cardHeader : .popHeader }
    var hero: KitType { self == .window ? .hero : .popHero }
    var chartHeight: CGFloat { self == .window ? Metric.chartHeight : Metric.popChartHeight }
    var padding: CGFloat { self == .window ? Metric.cardPadding : Metric.popCardPadding }
    var paddingBottom: CGFloat { self == .window ? Metric.cardPaddingBottom : Metric.popCardPaddingBottom }
}

/// The rounded card behind every stat (design/KIT.md, Stat card).
struct KitCard<Content: View>: View {
    var style: CardStyle = .window
    var height: CGFloat?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding([.top, .horizontal], style.padding)
            .padding(.bottom, style.paddingBottom)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: height ?? style.height, alignment: .top)
            .background(Ink.cardFill, in: shape)
            .overlay(shape.strokeBorder(Ink.cardStroke, lineWidth: Metric.cardStroke))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
    }
}

/// Icon, header text, and an optional pill on the right.
struct CardHeader: View {
    let icon: KitIcon?
    let title: String
    var tint: Color = Ink.secondary
    var pill: String?
    var pillHot = false
    var style: CardStyle = .window

    var body: some View {
        HStack(spacing: Metric.iconGap) {
            if let icon { icon.view(color: tint) }
            Text(title)
                .kitType(style.header)
                .foregroundStyle(Ink.label)
            Spacer(minLength: Metric.iconGap)
            if let pill { KitPill(text: pill, hot: pillHot) }
        }
        .frame(height: Metric.pillHeight)
    }
}

/// The big number with its small unit: "15 %", "99 GB".
struct HeroValue: View {
    let value: String
    var unit: String?
    var role: KitType = .hero

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metric.unitGap) {
            Text(value)
                .kitType(role)
                .foregroundStyle(value == "--" ? Ink.secondary : Ink.text)
                .contentTransition(.numericText())
            if let unit {
                Text(unit)
                    .kitType(.unit)
                    .foregroundStyle(Ink.secondary)
            }
        }
    }
}

/// The bottom line of a card, with optional text on the right.
struct CardFooter: View {
    let leading: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(leading).lineLimit(1)
            Spacer(minLength: Metric.iconGap)
            if let trailing { Text(trailing).lineLimit(1) }
        }
        .kitType(.footer)
        .foregroundStyle(Ink.secondary)
    }
}
