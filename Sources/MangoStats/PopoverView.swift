import SwiftUI
import MangoStatsKit

/// The popover that opens from the menu bar item: the Overview in small
/// (design/KIT.md, Popover).
struct PopoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private let columns = [GridItem(.flexible(), spacing: Metric.popoverMargin - 2),
                           GridItem(.flexible(), spacing: Metric.popoverMargin - 2)]

    var body: some View {
        let data = model.status
        VStack(alignment: .leading, spacing: Metric.popoverMargin - 2) {
            header(data)
            let insight = model.currentInsight
            if !insight.isCalm { PopInsight(insight: insight) }
            LazyVGrid(columns: columns, spacing: Metric.popoverMargin - 2) {
                PopStat(title: "CPU", detail: data.cpuTemp, value: data.cpu, unit: "%",
                        chart: data.cpuHistory, tint: Ink.cpu, footer: data.cpuFooter.capitalizedFirst)
                PopStat(title: "GPU", detail: data.gpuTemp, value: data.gpu, unit: "%",
                        chart: data.gpuHistory, tint: Ink.gpu, footer: data.gpuFooter.capitalizedFirst)
                PopStat(title: "Memory", detail: data.memoryPressure == "--" ? nil : data.memoryPressure.lowercased(),
                        value: data.memory, unit: "%", chart: data.memoryHistory, tint: Ink.memory,
                        footer: data.memoryUsedOfTotal, hot: data.memoryPressureLevel != .normal)
                PopStorage(data: data)
                PopStat(title: "Network", detail: data.networkInterface, value: data.network, unit: data.networkUnit,
                        chart: data.networkHistory, tint: Ink.network, ceiling: nil, footer: data.networkUploadShort,
                        accessibility: data.networkUpload)
                PopFan(data: data)
            }
            if data.hasBattery { PopBattery(data: data) }
            KitCard(style: .popover, fitsContent: true) {
                PopoverProcessHeader()
                    .padding(.bottom, Metric.iconGap)
                if data.processes.isEmpty {
                    Text("Reading processes…")
                        .kitType(.footer)
                        .foregroundStyle(Ink.secondary)
                        .frame(height: Metric.popRowHeight)
                }
                ForEach(data.processes.prefix(5), id: \.self) { process in
                    PopoverProcessRow(process: process) { AnyView(ProcessMenu(process: process)) }
                }
            }
            PrivacyRow(data: data)
            footer
        }
        .padding(Metric.popoverMargin)
        .frame(width: Metric.popoverWidth)
        .background(Ink.popoverBackground)
        .preferredColorScheme(.dark)
        .onAppear { model.popoverOpen = true }
        .onDisappear { model.popoverOpen = false }
    }

    private func header(_ data: StatusData) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Metric.iconGap) {
                    Text(data.health).kitType(.health)
                        .foregroundStyle(data.health == "--" ? Ink.faint : Ink.text)
                    Text(data.healthWord).kitType(.healthWord).foregroundStyle(Ink.body)
                }
                Text(model.healthLine.components(separatedBy: " — ").last ?? "")
                    .kitType(.popLabel)
                    .foregroundStyle(Ink.secondary)
            }
            .help(data.healthReasons.isEmpty ? "Nothing needs attention" : data.healthReasons.joined(separator: "\n"))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(model.healthLine)
            Spacer()
            LivePill(text: "Live")
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private var footer: some View {
        HStack(spacing: Metric.iconGap) {
            Button("Open MangoStats", systemImage: KitIcon.window.symbol) {
                NSApp.activate()
                openWindow(id: "status")
            }
            .keyboardShortcut("1")
            .help("Open the Overview window (⌘1)")
            Spacer()
            if let version = model.updater.available {
                // A background check found an update: offer it here too (S-035).
                Button("Install MangoStats \(version)…") { model.updater.check() }
                    .buttonStyle(SegmentButtonStyle(selected: true, compact: true))
                    .help("Download and install MangoStats \(version)")
            }
            Button("Settings…", systemImage: KitIcon.gear.symbol) {
                NSApp.activate()
                openSettings()
            }
            .keyboardShortcut(",")
            .help("Change which stats show in the menu bar (⌘,)")
            Button("Quit MangoStats", systemImage: KitIcon.power.symbol) { NSApp.terminate(nil) }
                .keyboardShortcut("q")
                .help("Quit MangoStats (⌘Q)")
        }
        .buttonStyle(KitIconButtonStyle())
    }
}

// MARK: - Cards

/// The insight in small: eyebrow and title, tinted like the Overview's card.
private struct PopInsight: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    let insight: Insight

    var body: some View {
        KitCard(style: .popover, fitsContent: true, tinted: true) {
            Eyebrow(text: insight.eyebrow, icon: .warning, color: Ink.accent)
            Text(insight.title)
                .kitType(.rowName)
                .foregroundStyle(Ink.text)
                .lineLimit(1)
                .padding(.top, Metric.iconGap)
            if let app = insight.app {
                Button("Review \(app.split(separator: " ").last.map(String.init) ?? app)…") {
                    model.review(app)
                    NSApp.activate()
                    openWindow(id: "status")
                }
                .buttonStyle(LinkButtonStyle())
                .padding(.top, Metric.iconGap)
                .help("Open \(app) in the Overview's process list")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PopStat: View {
    let title: String
    let detail: String?
    let value: String
    let unit: String?
    let chart: [Double]
    let tint: Color
    var ceiling: Double? = 1
    let footer: String
    var hot = false
    var accessibility: String?

    var body: some View {
        KitCard(style: .popover) {
            CardHeader(title: title, detail: detail, hot: hot, style: .popover)
            HeroValue(value: value, unit: unit, role: .popValue).padding(.top, Metric.iconGap)
            Spacer(minLength: 0)
            LineChart(values: chart, tint: tint, ceiling: ceiling, height: Metric.popChartHeight)
            Spacer(minLength: 0)
            CardFooter(leading: footer)
                .accessibilityLabel(accessibility ?? footer)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PopStorage: View {
    let data: StatusData

    var body: some View {
        Button {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/"))
        } label: {
            KitCard(style: .popover) {
                CardHeader(title: "Storage", detail: data.diskTotal, style: .popover)
                HeroValue(value: data.diskFree, unit: L10n.f("%@ free", data.diskFreeUnit), role: .popValue)
                    .padding(.top, Metric.iconGap)
                Spacer(minLength: 0)
                KitProgressBar(value: data.diskUsed, fill: data.diskUsed > 0.9 ? Ink.accent : Ink.disk,
                               height: Metric.cpuBar.height)
                Spacer(minLength: 0)
                CardFooter(leading: data.diskFooter)
            }
        }
        .buttonStyle(.plain)
        .help("Open the startup disk in Finder")
        .accessibilityLabel("Storage, \(data.storageTitle), \(data.diskFooter)")
    }
}

private struct PopFan: View {
    let data: StatusData

    var body: some View {
        KitCard(style: .popover) {
            CardHeader(title: "Fan", style: .popover) { FanModeMenu() }
            HeroValue(value: data.fanRPM, unit: data.hasFan ? "RPM" : nil, role: .popValue)
                .padding(.top, Metric.iconGap)
            Spacer(minLength: 0)
            LineChart(values: data.fanHistory, tint: Ink.secondary, height: Metric.popChartHeight)
            Spacer(minLength: 0)
            // The short form: "Silent · managed by macOS" doesn't fit half the popover.
            CardFooter(leading: (data.fanNote.components(separatedBy: " · ").last ?? data.fanNote).capitalizedFirst)
        }
    }
}

private struct PopBattery: View {
    let data: StatusData

    var body: some View {
        KitCard(style: .popover, fitsContent: true) {
            HStack(alignment: .firstTextBaseline) {
                Text("Battery").kitType(.popLabel).foregroundStyle(Ink.secondary)
                HeroValue(value: data.battery, unit: "%", role: .popValue)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(data.batteryState).kitType(.footer).foregroundStyle(Ink.body)
                    KitPill(text: data.batteryHealth.lowercased())
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Column titles above the popover's process rows.
struct PopoverProcessHeader: View {
    var body: some View {
        HStack(spacing: Metric.cardGap - 6) {
            Text("Top processes").kitType(.popLabel).foregroundStyle(Ink.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Memory").frame(width: Metric.popColMemory, alignment: .trailing)
            Text("CPU").frame(width: Metric.colCPU, alignment: .trailing)
            Spacer().frame(width: Metric.compactSegmentHeight)
        }
        .kitType(.columnHeader)
        .foregroundStyle(Ink.secondary)
    }
}

/// Camera, mic, awake, and screen (S-019).
private struct PrivacyRow: View {
    let data: StatusData

    var body: some View {
        HStack(spacing: Metric.cardGap) {
            HStack(spacing: Metric.iconGap) {
                KitIcon.camera.view(color: data.privacyActive ? Ink.hot : Ink.secondary)
                KitIcon.mic.view(color: data.privacyActive ? Ink.hot : Ink.secondary)
                Text(data.privacyText)
                    .foregroundStyle(data.privacyActive ? Ink.hot : Ink.body)
                    .fontWeight(data.privacyActive ? .semibold : .regular)
            }
            .help(data.privacyActive ? "\(data.privacyText) by an app" : "No app is using the camera or microphone")
            Spacer(minLength: 0)
            Label { Text(data.awakeText) } icon: { KitIcon.awake.view() }
                .help(data.awakeHelp)
            Label { Text(data.screenText) } icon: { KitIcon.display.view() }
                .help(data.screenHelp)
        }
        .labelStyle(PrivacyLabelStyle())
        .kitType(.footer)
        .foregroundStyle(Ink.body)
        .lineLimit(1)
        .padding(.horizontal, Metric.popCardPadding)
        .padding(.vertical, Metric.popCardPaddingBottom - 2)
        .background(Ink.cardFill, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
            .strokeBorder(Ink.cardStroke, lineWidth: Metric.cardStroke))
        .accessibilityElement(children: .combine)
    }
}

private struct PrivacyLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Metric.iconGap) {
            configuration.icon
            configuration.title
        }
    }
}
