import Charts
import Combine
import SwiftUI
import MangoStatsKit

/// The History page of the Status window (S-028, S-029): charts of the
/// recorded minutes for the last hour, day, week, or month.
struct HistoryView: View {
    @State private var range = HistoryRange.day
    @State private var minutes: [MinuteSample] = []
    @State private var loaded = false
    /// The time under the pointer, shared by every chart (S-029).
    @State private var hovered: Date?
    private let reload = Timer.publish(every: 60, tolerance: 10, on: .main, in: .common).autoconnect()

    private let columns = [GridItem(.flexible(), spacing: Metric.cardGap),
                           GridItem(.flexible(), spacing: Metric.cardGap)]

    var body: some View {
        let points = range.downsample(minutes, now: .now)
        VStack(alignment: .leading, spacing: Metric.cardGap) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: Metric.iconGap) {
                    Text("History").kitType(.pageTitle).foregroundStyle(Ink.text)
                    Text("Last \(range.title.lowercased()) · one sample per minute")
                        .kitType(.pageSubtitle).foregroundStyle(Ink.secondary)
                }
                Spacer()
                KitSegmented(options: HistoryRange.allCases, selection: $range, title: \.title,
                             help: { L10n.f("Show the last %@", $0.title.lowercased()) })
            }
            .padding(.bottom, Metric.sectionGap - Metric.cardGap)
            if loaded && points.isEmpty {
                ContentUnavailableView("No History Yet", systemImage: KitIcon.chart.symbol,
                                       description: Text("History starts after a minute of recording."))
                    .foregroundStyle(Ink.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Metric.cardGap) {
                        ForEach(HistoryChart.all) { chart in
                            if chart.hasData(points) {
                                HistoryCard(chart: chart, points: points, range: range, hovered: $hovered)
                            }
                        }
                    }
                }
                .scrollIndicators(.automatic)
            }
        }
        .task(id: range) { await load() }
        .onReceive(reload) { _ in Task { await load() } }
    }

    private func load() async {
        if HistorySample.enabled {
            minutes = HistorySample.minutes(now: .now)
        } else {
            minutes = await HistoryStore.shared.minutes(since: Date.now.addingTimeInterval(-range.duration))
        }
        loaded = true
    }
}

/// One series of a chart: a name for the legend, a color, and how to read it.
struct HistorySeries: Identifiable {
    let name: String
    let color: Color
    let value: (MinuteSample) -> Double?
    var id: String { name }
}

/// The seven History charts (S-028).
struct HistoryChart: Identifiable {
    let title: String
    let icon: KitIcon
    let tint: Color
    let series: [HistorySeries]
    /// A fixed top (100 % for shares), or nil to fit the data.
    let ceiling: Double?
    let filled: Bool
    let format: (Double) -> String

    var id: String { title }

    func hasData(_ points: [MinuteSample]) -> Bool {
        series.contains { s in points.contains { s.value($0) != nil } }
    }

    static let percent: (Double) -> String = { "\(Format.number($0 * 100, digits: 0)) %" }

    static let all: [HistoryChart] = [
        HistoryChart(title: "CPU", icon: .cpu, tint: Ink.cpu,
                     series: [HistorySeries(name: "CPU", color: Ink.cpu, value: { $0.cpu })],
                     ceiling: 1, filled: true, format: percent),
        HistoryChart(title: "GPU", icon: .gpu, tint: Ink.gpu,
                     series: [HistorySeries(name: "GPU", color: Ink.gpu, value: { $0.gpu })],
                     ceiling: 1, filled: true, format: percent),
        HistoryChart(title: "Memory", icon: .memory, tint: Ink.memory,
                     series: [HistorySeries(name: "Memory", color: Ink.memory, value: { $0.memory })],
                     ceiling: 1, filled: true, format: percent),
        HistoryChart(title: "Temperature", icon: .thermometer, tint: Ink.hot,
                     series: [HistorySeries(name: "CPU", color: Ink.cpu, value: { $0.cpuTemperature }),
                              HistorySeries(name: "GPU", color: Ink.gpu, value: { $0.gpuTemperature })],
                     ceiling: nil, filled: false, format: { Format.celsius($0) }),
        HistoryChart(title: "Network", icon: .network, tint: Ink.network,
                     series: [HistorySeries(name: "Down", color: Ink.network, value: { $0.download }),
                              HistorySeries(name: "Up", color: Ink.memory, value: { $0.upload })],
                     ceiling: nil, filled: false, format: { let s = Format.speed($0); return "\(s.value) \(s.unit)" }),
        HistoryChart(title: "Battery", icon: .battery, tint: Ink.battery,
                     series: [HistorySeries(name: "Battery", color: Ink.battery, value: { $0.battery })],
                     ceiling: 1, filled: true, format: percent),
        HistoryChart(title: "Power", icon: .bolt, tint: Ink.disk,
                     series: [HistorySeries(name: "CPU", color: Ink.cpu, value: { $0.cpuWatts }),
                              HistorySeries(name: "GPU", color: Ink.gpu, value: { $0.gpuWatts })],
                     ceiling: nil, filled: false, format: { Format.watts($0) }),
    ]
}

/// A chart card: header with the average and peak, the chart, the legend.
private struct HistoryCard: View {
    let chart: HistoryChart
    let points: [MinuteSample]
    let range: HistoryRange
    @Binding var hovered: Date?

    var body: some View {
        KitCard(height: Metric.historyCardHeight) {
            CardHeader(title: chart.title, detail: summary)
            HistoryPlot(chart: chart, points: points, range: range, hovered: $hovered)
                .padding(.top, Metric.cardPadding / 2)
            if chart.series.count > 1 {
                HStack(spacing: Metric.cardPadding) {
                    ForEach(chart.series) { series in
                        HStack(spacing: Metric.iconGap) {
                            Capsule().fill(series.color).frame(width: Metric.cardPadding / 2, height: Metric.legendStroke)
                            Text(series.name)
                        }
                    }
                }
                .kitType(.pill)
                .foregroundStyle(Ink.secondary)
                .padding(.top, Metric.iconGap)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(chart.title), last \(range.title.lowercased()), \(summary)")
    }

    /// "avg 18 % · peak 64 %" for the first series.
    private var summary: String {
        let values = points.compactMap { chart.series[0].value($0) }
        guard !values.isEmpty, let peak = values.max() else { return "--" }
        let average = values.reduce(0, +) / Double(values.count)
        return L10n.f("avg %@ · peak %@", chart.format(average), chart.format(peak))
    }
}

private struct HistoryPlot: View {
    let chart: HistoryChart
    let points: [MinuteSample]
    let range: HistoryRange
    @Binding var hovered: Date?

    var body: some View {
        Chart {
            ForEach(chart.series) { series in
                ForEach(segments(series), id: \.offset) { segment in
                    ForEach(segment.element, id: \.time) { point in
                        if let value = series.value(point) {
                            if chart.filled {
                                AreaMark(x: .value("Time", point.time), y: .value(series.name, value),
                                         series: .value("Segment", "\(series.name)\(segment.offset)"))
                                    .foregroundStyle(LinearGradient(colors: [series.color.opacity(0.35), series.color.opacity(0)],
                                                                    startPoint: .top, endPoint: .bottom))
                                    .interpolationMethod(.monotone)
                            }
                            LineMark(x: .value("Time", point.time), y: .value(series.name, value),
                                     series: .value("Segment", "\(series.name)\(segment.offset)"))
                                .foregroundStyle(series.color)
                                .lineStyle(StrokeStyle(lineWidth: Metric.lineWidth, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.monotone)
                        }
                    }
                }
            }
            if let hovered, let point = nearest(hovered) {
                RuleMark(x: .value("Time", point.time))
                    .foregroundStyle(Ink.secondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: 2,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        Text(callout(point))
                            .kitType(.pill)
                            .foregroundStyle(Ink.text)
                            .padding(.horizontal, Metric.pillPadding)
                            .padding(.vertical, 2)
                            .background(Ink.selectedSegment, in: RoundedRectangle(cornerRadius: Metric.pillRadius))
                    }
            }
        }
        .chartXScale(domain: Date.now.addingTimeInterval(-range.duration)...Date.now)
        .chartYScale(domain: 0...(chart.ceiling ?? max(peak * 1.15, 0.001)))
        .chartXSelection(value: $hovered)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Ink.chartGrid)
                AxisValueLabel {
                    if let number = value.as(Double.self) { Text(chart.format(number)) }
                }
                .foregroundStyle(Ink.tertiary)
            }
        }
        .chartXAxis {
            // .aligned keeps the first and last labels inside the plot instead of clipping them.
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: range == .hour || range == .day
                               ? .dateTime.hour().minute() : .dateTime.weekday(.abbreviated).day())
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .frame(height: Metric.historyChartHeight)
    }

    private var peak: Double {
        chart.series.flatMap { series in points.compactMap(series.value) }.max() ?? 0
    }

    /// Splits a series where buckets are missing, so sleep shows as a break.
    private func segments(_ series: HistorySeries) -> [EnumeratedSequence<[[MinuteSample]]>.Element] {
        var result: [[MinuteSample]] = []
        var current: [MinuteSample] = []
        for point in points where series.value(point) != nil {
            if let last = current.last, point.time.timeIntervalSince(last.time) > range.bucket * 2.5 {
                result.append(current)
                current = []
            }
            current.append(point)
        }
        if !current.isEmpty { result.append(current) }
        return Array(result.enumerated())
    }

    private func nearest(_ date: Date) -> MinuteSample? {
        points.min { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) }
    }

    /// "14:20 · 23 %", with the day for Week and Month.
    private func callout(_ point: MinuteSample) -> String {
        let time = range == .hour || range == .day
            ? point.time.formatted(date: .omitted, time: .shortened)
            : point.time.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        let values = chart.series.compactMap { series in
            series.value(point).map { chart.series.count > 1 ? "\(series.name) \(chart.format($0))" : chart.format($0) }
        }
        return "\(time) · \(values.joined(separator: ", "))"
    }
}

/// Made-up history for snapshots (APP_SNAPSHOT without APP_LIVE): a calm
/// day with a busy afternoon and a gap overnight while the Mac slept.
enum HistorySample {
    static var enabled: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["APP_SNAPSHOT"] != nil && env["APP_LIVE"] != "1"
    }

    static func minutes(now: Date) -> [MinuteSample] {
        let start = MinuteAggregator.minuteStart(now.addingTimeInterval(-30 * 86_400))
        var result: [MinuteSample] = []
        var time = start
        var index = 0.0
        while time <= now {
            let hour = Calendar.current.component(.hour, from: time)
            if hour >= 2 && hour < 7 {   // asleep
                time.addTimeInterval(60)
                continue
            }
            let busy = hour >= 14 && hour < 17 ? 0.35 : 0
            let wave = (sin(index / 37) + 1) / 2
            result.append(MinuteSample(time: time, cpu: 0.08 + 0.12 * wave + busy, memory: 0.78 + 0.06 * wave,
                                       gpu: 0.1 + 0.2 * wave + busy, cpuTemperature: 42 + 8 * wave + busy * 30,
                                       gpuTemperature: 40 + 6 * wave + busy * 25, download: 4_000 + 60_000 * wave * wave,
                                       upload: 800 + 9_000 * wave, battery: 1 - Double(Int(index) % 600) / 1_500,
                                       cpuWatts: 0.8 + 2 * wave + busy * 12, gpuWatts: 0.3 + 1.5 * wave + busy * 6))
            time.addTimeInterval(60)
            index += 1
        }
        return result
    }
}
