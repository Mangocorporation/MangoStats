import SwiftUI

/// CPU history as bars, newest on the right. Values are 0…1. (Kept for the gallery.)
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
                    .fill(tint)
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

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else {
            // One sample or none: a flat line at the bottom, like an idle reading.
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - 1))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 1))
            return path
        }
        let top = ceiling ?? max(values.max() ?? 1, 0.0001)
        let step = rect.width / CGFloat(values.count - 1)
        func point(_ index: Int) -> CGPoint {
            let fraction = min(max(values[index] / top, 0), 1)
            return CGPoint(x: rect.minX + CGFloat(index) * step,
                           y: rect.maxY - 1 - CGFloat(fraction) * (rect.height - 2))
        }
        path.move(to: point(0))
        for index in 1..<values.count { path.addLine(to: point(index)) }
        return path
    }
}

/// The stat cards' sparkline (design/KIT.md, Sparkline): a thin line, no fill.
struct LineChart: View {
    let values: [Double]
    var tint: Color
    /// nil scales to the largest sample, for speeds.
    var ceiling: Double? = 1
    var height: CGFloat = Metric.chartHeight

    var body: some View {
        SparkLine(values: values, ceiling: ceiling)
            .stroke(tint, style: StrokeStyle(lineWidth: Metric.lineWidth, lineCap: .round, lineJoin: .round))
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

/// Same line with a soft fill (kept for the gallery).
struct AreaChart: View {
    let values: [Double]
    var tint: Color = Ink.memory
    var height: CGFloat = Metric.chartHeight

    var body: some View {
        LineChart(values: values, tint: tint, height: height)
    }
}

/// A rounded bar: memory in the insight card, storage, a process's CPU. `value` is 0…1.
struct KitProgressBar: View {
    let value: Double
    var fill: Color = Ink.accent
    var height: CGFloat = Metric.progressHeight

    var body: some View {
        GeometryReader { proxy in
            Capsule().fill(Ink.track)
                .overlay(alignment: .leading) {
                    Capsule().fill(fill)
                        .frame(width: max(height, proxy.size.width * min(max(value, 0), 1)))
                }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}
