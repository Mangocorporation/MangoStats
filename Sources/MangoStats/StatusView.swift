import SwiftUI
import MangoStatsKit

/// The main window: Overview | History tabs (design/reference/overview.png).
struct StatusView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            if KitGallery.enabled {
                KitGallery()
            } else if model.page == .network {
                NetworkView()
            } else if model.page == .history {
                HistoryView()
                    .padding(.horizontal, Metric.windowMargin)
                    .padding(.top, Metric.windowTop)
                    .padding(.bottom, Metric.windowMargin)
            } else {
                OverviewView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Ink.windowBackground)
        .overlay(alignment: .top) {
            if !KitGallery.enabled {
                @Bindable var model = model
                KitTabBar(tabs: Page.allCases, selection: $model.page, title: \.title)
                    .padding(.top, Metric.tabBarTop)
            }
        }
        .ignoresSafeArea()
        .background(WindowChrome())
        .focusEffectDisabled()
        .preferredColorScheme(.dark)
        .noInitialFocus()
        .onAppear { model.windowOpen = true }
        .onDisappear { model.windowOpen = false }
        .task {
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings)
        }
    }
}

/// The Overview page: what's worth a look, the stats, and the processes.
struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let data = model.status
        ScrollView {
            VStack(alignment: .leading, spacing: Metric.sectionGap) {
                header(data)
                HStack(alignment: .top, spacing: Metric.cardGap) {
                    InsightCard(data: data)
                        .containerRelativeFrame(.horizontal) { width, _ in
                            (width - Metric.windowMargin * 2 - Metric.cardGap) * Metric.insightRatio
                        }
                    StorageCard(data: data)
                }
                HStack(spacing: Metric.cardGap) {
                    CPUCard(data: data)
                    GPUCard(data: data)
                    NetworkCard(data: data)
                    BatteryCard(data: data)
                    FanCard(data: data)
                }
                ProcessTableView(data: data)
            }
            .padding(.horizontal, Metric.windowMargin)
            .padding(.top, Metric.windowTop)
            .padding(.bottom, Metric.windowMargin)
        }
        .scrollIndicators(.automatic)
    }

    private func header(_ data: StatusData) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Metric.iconGap) {
                Text("Overview").kitType(.pageTitle).foregroundStyle(Ink.text)
                Text(model.healthLine).kitType(.pageSubtitle).foregroundStyle(Ink.secondary)
                    .help(data.healthReasons.isEmpty ? "Nothing needs attention" : data.healthReasons.joined(separator: "\n"))
            }
            Spacer()
            LivePill(text: "Live · every \(model.refreshInterval) s")
            Button("Settings…", systemImage: KitIcon.settings.symbol) {
                NSApp.activate()
                openSettings()
            }
            .buttonStyle(KitIconButtonStyle(size: Metric.iconButton, outlined: true))
            .keyboardShortcut(",")
            .help("Open Settings (⌘,)")
        }
    }
}

// MARK: - Insight and storage

/// The most urgent thing worth a look, or a calm note (S-037).
struct InsightCard: View {
    @Environment(AppModel.self) private var model
    let data: StatusData

    var body: some View {
        let insight = model.currentInsight
        KitCard(height: Metric.insightHeight, tinted: !insight.isCalm, padding: Metric.insightPadding) {
            Eyebrow(text: insight.eyebrow, icon: insight.isCalm ? .health : .warning,
                    color: insight.isCalm ? Ink.live : Ink.accent)
            Text(insight.title)
                .kitType(.insightTitle)
                .foregroundStyle(Ink.text)
                .lineLimit(1)
                .padding(.top, Metric.cardGap - 2)
            HStack(alignment: .center, spacing: Metric.cardGap) {
                Text(insight.body)
                    .kitType(.body)
                    .foregroundStyle(Ink.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !insight.isCalm {
                    if let app = insight.app {
                        Button("Review \(app.split(separator: " ").last.map(String.init) ?? app)") { model.review(app) }
                            .buttonStyle(PrimaryButtonStyle())
                            .help("Show \(app) in the process list")
                    }
                    Button("Dismiss") { model.dismiss(insight) }
                        .buttonStyle(SecondaryButtonStyle())
                        .help("Hide this until something changes")
                }
            }
            .padding(.top, Metric.iconGap)
            Spacer(minLength: Metric.cardGap)
            KitProgressBar(value: data.memoryFraction, fill: insight.kind == .memory ? Ink.accent : Ink.cpu)
            HStack {
                Text(data.memoryUsedLine)
                Spacer()
                Text(data.memoryDetailLine)
            }
            .kitType(.mono)
            .foregroundStyle(Ink.body)
            .padding(.top, Metric.cardGap - 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(insight.eyebrow). \(insight.title). \(insight.body)")
    }
}

private struct StorageCard: View {
    let data: StatusData

    var body: some View {
        KitCard(height: Metric.insightHeight, padding: Metric.insightPadding) {
            Eyebrow(text: "Storage")
            Text(data.storageTitle)
                .kitType(.insightTitle)
                .foregroundStyle(Ink.text)
                .padding(.top, Metric.cardGap - 2)
            Text(data.storageLine)
                .kitType(.body)
                .foregroundStyle(Ink.body)
                .lineLimit(2)
                .padding(.top, Metric.iconGap)
            Spacer(minLength: Metric.cardGap)
            KitProgressBar(value: data.diskUsed, fill: data.diskUsed > 0.9 ? Ink.accent : Ink.disk)
            Button("See what's using space") { SystemSettings.open("com.apple.settings.Storage") }
                .buttonStyle(SecondaryButtonStyle())
                .help("Open Storage in System Settings")
                .padding(.top, Metric.cardGap)
        }
    }
}

// MARK: - Stat cards

private struct StatCard: View {
    let title: String
    let detail: String?
    let value: String
    let unit: String?
    let chart: AnyView
    let footer: String

    var body: some View {
        KitCard {
            CardHeader(title: title, detail: detail)
            HeroValue(value: value, unit: unit).padding(.top, Metric.heroTop)
            Spacer(minLength: 0)
            chart
            Spacer(minLength: 0)
            CardFooter(leading: footer)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CPUCard: View {
    let data: StatusData
    var body: some View {
        StatCard(title: "CPU", detail: data.cpuTemp, value: data.cpu, unit: "%",
                 chart: AnyView(LineChart(values: data.cpuHistory, tint: Ink.cpu)),
                 footer: data.cpuFooter.capitalizedFirst)
    }
}

private struct GPUCard: View {
    let data: StatusData
    var body: some View {
        StatCard(title: "GPU", detail: data.gpuTemp, value: data.gpu, unit: "%",
                 chart: AnyView(LineChart(values: data.gpuHistory, tint: Ink.gpu)),
                 footer: data.gpuFooter.capitalizedFirst)
    }
}

private struct NetworkCard: View {
    let data: StatusData
    var body: some View {
        StatCard(title: "Network", detail: data.networkInterface, value: data.network, unit: data.networkUnit,
                 chart: AnyView(LineChart(values: data.networkHistory, tint: Ink.network, ceiling: nil)),
                 footer: data.networkLine)
    }
}

private struct BatteryCard: View {
    let data: StatusData
    var body: some View {
        StatCard(title: "Battery", detail: data.hasBattery ? data.batteryHealth.lowercased() : nil,
                 value: data.hasBattery ? data.battery : "--", unit: "%",
                 chart: AnyView(LineChart(values: data.batteryHistory, tint: Ink.battery)),
                 footer: data.batteryLine)
    }
}

private struct FanCard: View {
    let data: StatusData

    var body: some View {
        KitCard {
            CardHeader(title: "Fan") { FanModeMenu() }
            HeroValue(value: data.fanRPM, unit: data.hasFan ? "RPM" : nil).padding(.top, Metric.heroTop)
            Spacer(minLength: 0)
            LineChart(values: data.fanHistory, tint: Ink.secondary, ceiling: 1)
            Spacer(minLength: 0)
            CardFooter(leading: data.fanNote)
        }
    }
}

extension String {
    /// "idle · 0.9W" -> "Idle · 0.9W".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// Opens a System Settings pane by its extension id.
enum SystemSettings {
    static func open(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
