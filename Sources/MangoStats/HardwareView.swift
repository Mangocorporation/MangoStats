import Charts
import SwiftUI
import MangoStatsKit

/// The Hardware tab: battery details, what drains it, and disk activity
/// (S-048 to S-050). Sensors and clock speeds join it later (M17).
struct HardwareView: View {
    @Environment(AppModel.self) private var model
    @State private var healthHistory: [(day: Date, health: Int)] = []

    var body: some View {
        let data = model.status
        ScrollView {
            VStack(alignment: .leading, spacing: Metric.sectionGap) {
                VStack(alignment: .leading, spacing: Metric.iconGap) {
                    Text("Hardware").kitType(.pageTitle).foregroundStyle(Ink.text)
                    Text(data.hasBattery ? "Battery and storage" : "Storage")
                        .kitType(.pageSubtitle).foregroundStyle(Ink.secondary)
                }
                if data.hasBattery {
                    HStack(alignment: .top, spacing: Metric.cardGap) {
                        BatteryDetailCard(data: data, history: healthHistory)
                        BatteryDrainCard(data: data)
                    }
                }
                DiskActivityCard(data: data)
            }
            .padding(.horizontal, Metric.windowMargin)
            .padding(.top, Metric.windowTop)
            .padding(.bottom, Metric.windowMargin)
        }
        .defaultScrollAnchor(.top)
        .task { healthHistory = HistorySample.enabled ? Self.sampleHealth : await HistoryStore.shared.batteryHealthHistory() }
    }

    static let sampleHealth: [(day: Date, health: Int)] = (0..<120).map { offset in
        (Calendar.current.date(byAdding: .day, value: -119 + offset, to: .now)!, 100 - offset / 40)
    }
}

/// A label and a mono value on one line.
private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).kitType(.statLabel).foregroundStyle(Ink.secondary)
            Spacer(minLength: Metric.cardGap)
            Text(value).kitType(.mono).foregroundStyle(Ink.body).lineLimit(1)
        }
        .padding(.vertical, Metric.infoRowPadding)
    }
}

private struct BatteryDetailCard: View {
    let data: StatusData
    let history: [(day: Date, health: Int)]

    var body: some View {
        KitCard(height: nil, fitsContent: true, padding: Metric.insightPadding) {
            CardHeader(title: "Battery", detail: data.batteryCondition.lowercased(),
                       hot: data.batteryCondition != "Normal")
            HeroValue(value: data.batteryHealth.components(separatedBy: "%").first ?? "--", unit: "% health")
                .padding(.top, Metric.heroTop)
            VStack(spacing: 0) {
                DetailRow(label: "Charge", value: data.hasBattery ? "\(data.battery)% · \(data.batteryState)" : "–")
                DetailRow(label: "Cycles", value: data.batteryCycles)
                DetailRow(label: "Capacity", value: data.batteryCapacity)
                DetailRow(label: "Power", value: data.batteryPower)
                DetailRow(label: "Temperature", value: data.batteryTemperature)
                DetailRow(label: "Charger", value: data.batteryAdapter)
            }
            .padding(.top, Metric.cardGap)
            Text("Health over time").kitType(.statLabel).foregroundStyle(Ink.secondary)
                .padding(.top, Metric.cardGap)
            if history.count < 2 {
                Text("Builds up one point a day.").kitType(.footer).foregroundStyle(Ink.faint)
                    .padding(.top, Metric.iconGap)
            } else {
                Chart(history, id: \.day) { point in
                    LineMark(x: .value("Day", point.day), y: .value("Health", point.health))
                        .foregroundStyle(Ink.battery)
                        .interpolationMethod(.monotone)
                }
                .chartYScale(domain: max(0, (history.map(\.health).min() ?? 80) - 10)...max(100, history.map(\.health).max() ?? 100))
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(Ink.chartGrid)
                        AxisValueLabel { if let n = value.as(Int.self) { Text("\(n)%") } }.foregroundStyle(Ink.tertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Ink.tertiary)
                    }
                }
                .frame(height: Metric.historyChartHeight)
                .padding(.top, Metric.iconGap)
            }
        }
    }
}

/// Apps that used the most energy since they started (S-049).
private struct BatteryDrainCard: View {
    let data: StatusData

    var body: some View {
        let apps = data.processes.filter { ($0.energyWh ?? 0) > 0 }
            .sorted { ($0.energyWh ?? 0) > ($1.energyWh ?? 0) }.prefix(10)
        KitCard(height: nil, fitsContent: true, padding: Metric.insightPadding) {
            CardHeader(title: "Energy used by apps", detail: "since each app started")
            if apps.isEmpty {
                Text("Measuring… Energy shows for your own apps; macOS doesn't share it for system processes.")
                    .kitType(.body).foregroundStyle(Ink.body)
                    .padding(.top, Metric.heroTop)
            } else {
                HStack {
                    Text("App").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Used").frame(width: Metric.colEnergy, alignment: .trailing)
                    Text("Now").frame(width: Metric.colEnergy, alignment: .trailing)
                }
                .kitType(.columnHeader).foregroundStyle(Ink.secondary)
                .padding(.top, Metric.heroTop)
                ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                    HStack {
                        Text(app.name).kitType(.rowName).foregroundStyle(Ink.text).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(Self.wh(app.energyWh ?? 0)).frame(width: Metric.colEnergy, alignment: .trailing)
                            .foregroundStyle(index == 0 ? Ink.accent : Ink.body)
                        Text(app.watts.map(Self.now) ?? "–").frame(width: Metric.colEnergy, alignment: .trailing)
                            .foregroundStyle(Ink.secondary)
                    }
                    .kitType(.rowNumber)
                    .frame(height: Metric.popRowHeight + 4)
                    .overlay(alignment: .bottom) { Rectangle().fill(Ink.divider).frame(height: Metric.cardStroke) }
                }
            }
        }
    }

    static func wh(_ value: Double) -> String { "\(Format.number(value, digits: value < 10 ? 2 : 1)) Wh" }

    /// Current power: most apps draw well under a watt, so two decimals, and "<0.01 W" for idle.
    static func now(_ watts: Double) -> String {
        watts < 0.01 ? "<\(Format.number(0.01, digits: 2)) W" : "\(Format.number(watts, digits: watts < 1 ? 2 : 1)) W"
    }
}

/// The disks' live read and write speed, and the apps behind them (S-050).
private struct DiskActivityCard: View {
    let data: StatusData

    var body: some View {
        let apps = data.processes.filter { ($0.diskRate ?? 0) > 0 }.sorted { ($0.diskRate ?? 0) > ($1.diskRate ?? 0) }.prefix(8)
        KitCard(height: nil, fitsContent: true, padding: Metric.insightPadding) {
            CardHeader(title: "Disk activity", detail: data.storageTitle)
            HStack(alignment: .top, spacing: Metric.sectionGap) {
                VStack(alignment: .leading, spacing: Metric.iconGap) {
                    HStack(alignment: .firstTextBaseline, spacing: Metric.cardGap) {
                        HeroValue(value: "↓ " + data.diskRead, role: .popValue)
                        HeroValue(value: "↑ " + data.diskWrite, role: .popValue)
                    }
                    ZStack {
                        LineChart(values: data.diskReadHistory, tint: Ink.network, ceiling: nil)
                        LineChart(values: data.diskWriteHistory, tint: Ink.gpu, ceiling: nil)
                    }
                    HStack(spacing: Metric.cardGap) {
                        legend("Read", Ink.network)
                        legend("Write", Ink.gpu)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Apps reading and writing files").kitType(.statLabel).foregroundStyle(Ink.secondary)
                    // Per-app counts include reads macOS serves from memory, so they can add up
                    // to more than the disk itself (checked: the disk counters track real writes).
                    Text("Includes files macOS serves from memory, so apps can add up to more than the disk.")
                        .kitType(.footer).foregroundStyle(Ink.faint)
                        .padding(.bottom, Metric.iconGap)
                    if apps.isEmpty {
                        Text("No app is using the disk right now.").kitType(.footer).foregroundStyle(Ink.faint)
                    }
                    ForEach(apps) { app in
                        HStack {
                            Text(app.name).kitType(.rowName).foregroundStyle(Ink.text).lineLimit(1)
                            Spacer()
                            Text(Self.speed(app.diskRate ?? 0)).kitType(.rowNumber).foregroundStyle(Ink.body)
                        }
                        .frame(height: Metric.popRowHeight)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, Metric.heroTop)
        }
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: Metric.iconGap) {
            Capsule().fill(color).frame(width: Metric.cardPadding / 2, height: Metric.legendStroke)
            Text(title).kitType(.pill).foregroundStyle(Ink.secondary)
        }
    }

    static func speed(_ value: Double) -> String {
        let s = Format.speed(value)
        return "\(s.value) \(s.unit)"
    }
}
