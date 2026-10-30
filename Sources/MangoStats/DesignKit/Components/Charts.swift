import SwiftUI
import MangoStatsKit

/// CPU history: the last samples as bars, newest on the right (design/KIT.md, Bar history).
/// Values are 0…1.
struct BarHistory: View {
    let values: [Double]
    var tint: Color = Ink.cpu

    var body: some View {
        let bars = Array(values.suffix(Metric.barCount))
        let padded = Array(repeating: 0.0, count: Metric.barCount - bars.count) + bars
        HStack(alignment: .bottom, spacing: Metric.barGap) {
            ForEach(padded.indices, id: \.self) { index in
                UnevenRoundedRectangle(topLeadingRadius: Metric.barRadius, topTrailingRadius: Metric.barRadius,
                                       style: .continuous)
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    .frame(height: max(Metric.barRadius, Metric.barHeight * min(max(padded[index], 0), 1)))
            }
        }
        .frame(height: Metric.barHeight, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// A line through samples scaled to the view (0…1, or to `ceiling`).
nonisolated private struct SparkLine: Shape {
    let values: [Double]
    var ceiling: Double?
    var closed = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let top = ceiling ?? max(values.max() ?? 1, 0.0001)
        let step = rect.width / CGFloat(values.count - 1)
        func point(_ index: Int) -> CGPoint {
            let fraction = min(max(values[index] / top, 0), 1)
            // Keep a 1 pt inset so the line never touches the edges.
            return CGPoint(x: rect.minX + CGFloat(index) * step,
                           y: rect.maxY - 1 - CGFloat(fraction) * (rect.height - 2))
        }
        path.move(to: point(0))
        for index in 1..<values.count { path.addLine(to: point(index)) }
        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// GPU and network: a thin line (design/KIT.md, Line chart).
struct LineChart: View {
    let values: [Double]
    var tint: Color
    /// nil scales to the largest sample, for speeds.
    var ceiling: Double? = 1

    var body: some View {
        SparkLine(values: values, ceiling: ceiling)
            .stroke(tint, style: StrokeStyle(lineWidth: Metric.lineWidth, lineCap: .round, lineJoin: .round))
            .frame(height: Metric.chartHeight)
            .accessibilityHidden(true)
    }
}

/// Memory: a line with a fading fill below (design/KIT.md, Area chart).
struct AreaChart: View {
    let values: [Double]
    var tint: Color = Ink.memory
    var height: CGFloat = Metric.chartHeight

    var body: some View {
        ZStack {
            SparkLine(values: values, ceiling: 1, closed: true)
                .fill(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
            SparkLine(values: values, ceiling: 1)
                .stroke(tint, style: StrokeStyle(lineWidth: Metric.lineWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Free space: a filled bar (design/KIT.md, Progress bar). `value` is 0…1.
struct KitProgressBar: View {
    let value: Double
    var fill: AnyShapeStyle = AnyShapeStyle(LinearGradient(colors: [Ink.diskStart, Ink.disk],
                                                           startPoint: .leading, endPoint: .trailing))

    var body: some View {
        GeometryReader { proxy in
            Capsule().fill(Ink.track)
                .overlay(alignment: .leading) {
                    Capsule().fill(fill)
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                }
        }
        .frame(height: Metric.progressHeight)
        .accessibilityElement()
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

/// The process table's CPU bar.
struct MiniBar: View {
    let value: Double
    var hot = false

    var body: some View {
        Capsule().fill(Ink.track)
            .overlay(alignment: .leading) {
                Capsule().fill(hot ? Ink.hot : Ink.secondary)
                    .frame(width: Metric.miniBar.width * min(max(value, 0), 1))
            }
            .frame(width: Metric.miniBar.width, height: Metric.miniBar.height)
            .accessibilityHidden(true)
    }
}

/// The Health card's planet: our own warm sphere, not the reference's art.
struct HealthOrb: View {
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Ink.memory, Ink.disk, Ink.warning],
                                 center: UnitPoint(x: 0.35, y: 0.3),
                                 startRadius: 2, endRadius: Metric.orbSize * 0.7))
            .frame(width: Metric.orbSize, height: Metric.orbSize)
            .shadow(color: Ink.warning.opacity(0.35), radius: 10)
            .accessibilityHidden(true)
    }
}
