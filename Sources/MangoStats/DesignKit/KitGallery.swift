import SwiftUI
import MangoStatsKit

/// Every kit part in every state, like a storybook. Shown instead of the
/// Status window when APP_KIT_GALLERY=1 (tools/snap.sh captures it).
struct KitGallery: View {
    static let enabled = ProcessInfo.processInfo.environment["APP_KIT_GALLERY"] == "1"
    private let data = StatusData.sample

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metric.cardGap * 2) {
                section("Ink") {
                    HStack(spacing: Metric.cardGap) {
                        swatch("text", Ink.text); swatch("label", Ink.label); swatch("secondary", Ink.secondary)
                        swatch("tertiary", Ink.tertiary); swatch("hot", Ink.hot); swatch("cpu", Ink.cpu)
                        swatch("gpu", Ink.gpu); swatch("memory", Ink.memory); swatch("disk", Ink.disk)
                        swatch("network", Ink.network); swatch("battery", Ink.battery)
                    }
                }
                section("Type") {
                    HStack(alignment: .firstTextBaseline, spacing: Metric.cardGap * 2) {
                        Text("CPU").kitType(.cardHeader); Text("Free space").kitType(.popHeader)
                        Text("15").kitType(.hero); Text("%").kitType(.unit); Text("idle · 0.9W").kitType(.footer)
                        Text("84").kitType(.health); Text("Good").kitType(.healthWord)
                        Text("Google Chrome").kitType(.row); Text("18.5 GB").kitType(.rowNumber)
                        Text("Name (156)").kitType(.columnHeader)
                    }
                    .foregroundStyle(Ink.label)
                }
                section("Icons") {
                    HStack(spacing: Metric.cardGap * 2) {
                        ForEach(KitIcon.allCases, id: \.self) { $0.view(size: 13, color: Ink.label) }
                    }
                }
                section("Pills and chips") {
                    HStack(spacing: Metric.cardGap) {
                        KitPill(text: "45°C"); KitPill(text: "100% Health"); KitPill(text: "47.7", hot: true)
                        KitChip(text: "M5"); KitChip(text: "macOS 26.6.2"); KitChip(text: "up 51 days, 10 hrs")
                    }
                }
                section("Cards and charts") {
                    HStack(alignment: .top, spacing: Metric.cardGap) {
                        KitCard {
                            CardHeader(icon: .cpu, title: "CPU", tint: Ink.cpu, pill: "45°C")
                            HeroValue(value: "15", unit: "%").padding(.top, Metric.heroTop)
                            Spacer(minLength: 0)
                            BarHistory(values: data.cpuHistory)
                            Spacer(minLength: 0)
                            CardFooter(leading: "idle · 0.9W")
                        }
                        KitCard(style: .popover) {
                            CardHeader(icon: .memory, title: "MEM", tint: Ink.memory, pill: "Normal", style: .popover)
                            HeroValue(value: "84", unit: "%", role: CardStyle.popover.hero)
                                .padding(.top, Metric.iconGap)
                            Spacer(minLength: 0)
                            AreaChart(values: data.memoryHistory, height: CardStyle.popover.chartHeight)
                            Spacer(minLength: 0)
                            CardFooter(leading: "20,25 GB / 24 GB")
                        }
                        KitCard {
                            CardHeader(icon: .gpu, title: "GPU", tint: Ink.gpu, pill: nil)
                            HeroValue(value: "--", unit: "%").padding(.top, Metric.heroTop)
                            Spacer(minLength: 0)
                            LineChart(values: data.gpuHistory, tint: Ink.gpu)
                            Spacer(minLength: 0)
                            CardFooter(leading: "no data", trailing: "Low Lag")
                        }
                    }
                    HStack(spacing: Metric.cardGap) {
                        KitProgressBar(value: 0.8)
                        KitProgressBar(value: 0.6, fill: AnyShapeStyle(Ink.diskPopover))
                        LineChart(values: data.networkHistory, tint: Ink.network, ceiling: nil)
                        HealthOrb()
                    }
                }
                section("Buttons: rest, hover, pressed, disabled") {
                    HStack(spacing: Metric.cardGap * 2) {
                        ForEach(KitForcedState.allCases, id: \.self) { state in
                            HStack(spacing: Metric.cardGap) {
                                Button("Battery", systemImage: KitIcon.laptop.symbol) {}
                                    .buttonStyle(RingButtonStyle(progress: 0.75))
                                Button("Cool") {}.buttonStyle(SegmentButtonStyle())
                                Button("More", systemImage: KitIcon.more.symbol) {}.buttonStyle(KitIconButtonStyle())
                            }
                            .environment(\.kitForcedState, state)
                        }
                        Button("Auto") {}.buttonStyle(SegmentButtonStyle(selected: true))
                    }
                }
                section("Process rows: rest, hover, hot, long name") {
                    VStack(spacing: 0) {
                        ProcessRow(process: data.processes[1])
                        ProcessRow(process: data.processes[4]).environment(\.kitForcedState, .hover)
                        ProcessRow(process: data.processes[0])
                        ProcessRow(process: data.processes[13])
                    }
                    VStack(spacing: 0) {
                        PopoverProcessRow(process: data.processes[0])
                        PopoverProcessRow(process: data.processes[1])
                    }
                    .frame(width: Metric.popoverWidth - Metric.popoverMargin * 2)
                }
            }
            .padding(Metric.windowMargin * 2)
            .padding(.top, Metric.windowTop / 2)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Metric.cardGap) {
            Text(title).kitType(.cardHeader).foregroundStyle(Ink.tertiary)
            content()
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: Metric.iconGap) {
            RoundedRectangle(cornerRadius: Metric.pillRadius).fill(color)
                .frame(width: Metric.ringSize, height: Metric.ringSize)
            Text(name).kitType(.pill).foregroundStyle(Ink.secondary)
        }
    }
}
