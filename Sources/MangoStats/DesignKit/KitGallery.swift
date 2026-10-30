import SwiftUI
import MangoStatsKit

/// Every kit part in every state, like a storybook. Shown instead of the
/// Overview when APP_KIT_GALLERY=1 (tools/snap.sh captures it).
struct KitGallery: View {
    static let enabled = ProcessInfo.processInfo.environment["APP_KIT_GALLERY"] == "1"
    private let data = StatusData.sample
    @State private var kind = ProcessKind.all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metric.sectionGap) {
                section("Ink") {
                    HStack(spacing: Metric.cardGap) {
                        swatch("text", Ink.text); swatch("body", Ink.body); swatch("secondary", Ink.secondary)
                        swatch("faint", Ink.faint); swatch("accent", Ink.accent); swatch("cpu", Ink.cpu)
                        swatch("gpu", Ink.gpu); swatch("network", Ink.network); swatch("disk", Ink.disk)
                        swatch("card", Ink.cardFill); swatch("hairline", Ink.cardStroke)
                    }
                }
                section("Type") {
                    VStack(alignment: .leading, spacing: Metric.iconGap) {
                        Text("Overview").kitType(.pageTitle)
                        Text("Health 84 · Good — 2 things worth a look").kitType(.pageSubtitle)
                        Text("Memory is tight").kitType(.eyebrow)
                        Text("Google Chrome is holding 19,4 GB").kitType(.insightTitle)
                        Text("Memory is 86% full and macOS has moved 5,32 GB to swap.").kitType(.body)
                        Text("20,62 GB used of 24 GB").kitType(.mono)
                        HStack(alignment: .firstTextBaseline) {
                            Text("CPU").kitType(.statLabel)
                            HeroValue(value: "11", unit: "%")
                            Text("Processes").kitType(.sectionTitle)
                            Text("Name").kitType(.columnHeader)
                            Text("47,0").kitType(.rowNumber)
                        }
                    }
                    .foregroundStyle(Ink.text)
                }
                section("Buttons: rest, hover, pressed, disabled") {
                    ForEach(KitForcedState.allCases, id: \.self) { state in
                        buttonRow.environment(\.kitForcedState, state)
                    }
                    HStack(spacing: Metric.cardGap) {
                        KitSegmented(options: ProcessKind.allCases, selection: $kind, title: \.title)
                        LivePill(text: "Live · every 2 s")
                        Button("Show all 541") {}.buttonStyle(LinkButtonStyle())
                    }
                }
                section("Cards") { cards }
                section("Process rows: app, background, hover, long name") { rows }
            }
            .padding(Metric.windowMargin)
            .padding(.top, Metric.windowTop / 2)
        }
        .background(Ink.windowBackground)
    }

    private var buttonRow: some View {
        HStack(spacing: Metric.cardGap) {
            Button("Review Chrome") {}.buttonStyle(PrimaryButtonStyle())
            Button("Dismiss") {}.buttonStyle(SecondaryButtonStyle())
            Button("Settings", systemImage: KitIcon.settings.symbol) {}
                .buttonStyle(KitIconButtonStyle(size: Metric.iconButton, outlined: true))
            Button("More", systemImage: KitIcon.more.symbol) {}.buttonStyle(KitIconButtonStyle())
            Button("Cool") {}.buttonStyle(SegmentButtonStyle())
        }
    }

    private var cards: some View {
        HStack(alignment: .top, spacing: Metric.cardGap) {
            KitCard(height: Metric.insightHeight, tinted: true, padding: Metric.insightPadding) {
                Eyebrow(text: "Memory is tight", icon: .warning, color: Ink.accent)
                Text("Google Chrome is holding 19,4 GB").kitType(.insightTitle).foregroundStyle(Ink.text)
                    .padding(.top, Metric.cardGap - 2)
                Spacer()
                KitProgressBar(value: 0.86)
            }
            statCard(title: "CPU", detail: "37°C", value: "11", values: data.cpuHistory, footer: "Idle · 0,9 W")
            statCard(title: "GPU", detail: nil, value: "--", values: [], footer: "No data")
        }
    }

    private func statCard(title: String, detail: String?, value: String, values: [Double], footer: String) -> some View {
        KitCard {
            CardHeader(title: title, detail: detail)
            HeroValue(value: value, unit: "%").padding(.top, Metric.heroTop)
            Spacer(minLength: 0)
            LineChart(values: values, tint: Ink.cpu)
            Spacer(minLength: 0)
            CardFooter(leading: footer)
        }
        .frame(width: 260)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: Metric.cardGap) {
            VStack(spacing: 0) {
                ProcessRow(process: data.processes[0], highlightCPU: true, highlightMemory: true)
                ProcessRow(process: data.processes[2])
                ProcessRow(process: data.processes[1]).environment(\.kitForcedState, .hover)
                ProcessRow(process: data.processes[13])
            }
            .background(Ink.cardFill)
            VStack(spacing: 0) {
                PopoverProcessRow(process: data.processes[0])
                PopoverProcessRow(process: data.processes[2])
            }
            .frame(width: Metric.popoverWidth - Metric.popoverMargin * 2)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Metric.cardGap - 4) {
            Text(title).kitType(.eyebrow).foregroundStyle(Ink.secondary)
            content()
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: Metric.iconGap) {
            RoundedRectangle(cornerRadius: Metric.pillRadius).fill(color)
                .overlay(RoundedRectangle(cornerRadius: Metric.pillRadius).strokeBorder(Ink.cardStroke))
                .frame(width: Metric.iconButton, height: Metric.iconButton)
            Text(name).kitType(.pill).foregroundStyle(Ink.secondary)
        }
    }
}
