import SwiftUI
import MangoStatsKit

/// The Status window: eight cards in a 4 × 2 grid and the process table,
/// laid out like local/reference/status-window.png.
struct StatusView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            if KitGallery.enabled {
                KitGallery()
            } else {
                dashboard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Ink.windowBackground)
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

    private var dashboard: some View {
        let data = model.status
        return VStack(spacing: Metric.cardGap) {
            CardGrid {
                HealthCard(data: data)
                CPUCard(data: data)
                GPUCard(data: data)
                MemoryCard(data: data)
            }
            CardGrid {
                BatteryCard(data: data)
                DiskCard(data: data)
                NetworkCard(data: data)
                FanCard(data: data)
            }
            ProcessTable(data: data)
        }
        .padding(.horizontal, Metric.windowMargin)
        .padding(.top, Metric.windowTop)
        .padding(.bottom, Metric.windowMargin)
    }
}

/// One row of cards: the first is wider (Health, Battery), the rest share the space.
nonisolated private struct CardGrid: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? Metric.windowWidth, height: Metric.cardHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let gaps = Metric.cardGap * CGFloat(subviews.count - 1)
        let unit = (bounds.width - gaps) / (CGFloat(subviews.count - 1) + Metric.wideCardRatio)
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let width = index == 0 ? unit * Metric.wideCardRatio : unit
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + Metric.cardGap
        }
    }
}

// MARK: - Cards

private struct HealthCard: View {
    let data: StatusData

    var body: some View {
        KitCard {
            HStack(spacing: Metric.iconGap) {
                KitIcon.health.view(color: Ink.health)
                Text("Health").kitType(.cardHeader).foregroundStyle(Ink.health)
                Spacer(minLength: Metric.iconGap)
                KitPill(text: data.chip)
                KitPill(text: data.ram)
                KitPill(text: data.macOS)
            }
            .frame(height: Metric.pillHeight)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: Metric.iconGap) {
                        HeroValue(value: data.health)
                        Text(data.healthWord).kitType(.healthWord).foregroundStyle(Ink.label)
                    }
                    .padding(.top, Metric.heroTop)
                    Spacer(minLength: 0)
                    Text(data.healthReason).kitType(.footer).foregroundStyle(Ink.secondary)
                    Spacer(minLength: 0)
                    Text(data.uptime).kitType(.footer).foregroundStyle(Ink.secondary)
                }
                Spacer(minLength: 0)
                HealthOrb().padding(.top, Metric.iconGap)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CPUCard: View {
    let data: StatusData

    var body: some View {
        KitCard {
            CardHeader(icon: .cpu, title: "CPU", tint: Ink.cpu, pill: data.cpuTemp)
            HeroValue(value: data.cpu, unit: "%").padding(.top, Metric.heroTop)
            Spacer(minLength: 0)
            BarHistory(values: data.cpuHistory)
            Spacer(minLength: 0)
            CardFooter(leading: data.cpuFooter)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GPUCard: View {
    let data: StatusData

    var body: some View {
        KitCard {
            CardHeader(icon: .gpu, title: "GPU", tint: Ink.gpu, pill: data.gpuTemp)
            HeroValue(value: data.gpu, unit: "%").padding(.top, Metric.heroTop)
            Spacer(minLength: 0)
            LineChart(values: data.gpuHistory, tint: Ink.gpu)
            Spacer(minLength: 0)
            CardFooter(leading: data.gpuFooter)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MemoryCard: View {
    let data: StatusData

    var body: some View {
        KitCard {
            CardHeader(icon: .memory, title: "Memory", tint: Ink.memory,
                       pill: data.memoryPressure == "--" ? nil : "Pressure \(data.memoryPressure.lowercased())",
                       pillHot: data.memoryPressureLevel != .normal)
            HeroValue(value: data.memory, unit: "%").padding(.top, Metric.heroTop)
            Spacer(minLength: 0)
            AreaChart(values: data.memoryHistory)
            Spacer(minLength: 0)
            CardFooter(leading: data.memoryFooter)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BatteryCard: View {
    let data: StatusData

    var body: some View {
        KitCard {
            CardHeader(icon: .battery, title: "Battery", tint: Ink.battery, pill: data.batteryHealth)
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: Metric.iconGap) {
                    HeroValue(value: data.battery, unit: "%")
                    if let watts = data.batteryWatts {
                        Label(watts, systemImage: KitIcon.bolt.symbol)
                            .labelStyle(BoltLabelStyle())
                    }
                }
                Spacer()
                Button("Open Battery Settings", systemImage: KitIcon.laptop.symbol) {
                    SystemSettings.open("com.apple.Battery-Settings.extension")
                }
                .buttonStyle(RingButtonStyle(progress: data.batteryLevel))
                .help("Open Battery settings")
                Button("Open Energy Settings", systemImage: KitIcon.waves.symbol) {
                    SystemSettings.open("com.apple.Battery-Settings.extension")
                }
                .buttonStyle(RingButtonStyle(progress: 0.8))
                .help("Open Energy settings")
            }
            .padding(.top, Metric.iconGap)
            Text(data.batteryState).kitType(.footer).foregroundStyle(Ink.secondary)
            Spacer(minLength: 0)
            CardFooter(leading: data.batteryDrain)
        }
    }
}

private struct BoltLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.icon.kitType(.unit)
            configuration.title.kitType(.unit)
        }
        .foregroundStyle(Ink.label)
    }
}

private struct DiskCard: View {
    let data: StatusData

    var body: some View {
        KitCard {
            CardHeader(icon: .disk, title: "Free space", tint: Ink.network, pill: data.diskTotal)
            HeroValue(value: data.diskFree, unit: data.diskFreeUnit).padding(.top, Metric.heroTop)
            Spacer(minLength: 0)
            KitProgressBar(value: data.diskUsed)
            Spacer(minLength: 0)
            CardFooter(leading: data.diskFooter)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct NetworkCard: View {
    let data: StatusData

    var body: some View {
        KitCard {
            CardHeader(icon: .network, title: "Network", tint: Ink.network, pill: data.networkInterface)
            HeroValue(value: data.network, unit: data.networkUnit).padding(.top, Metric.heroTop)
            Spacer(minLength: 0)
            LineChart(values: data.networkHistory, tint: Ink.network, ceiling: nil)
            Spacer(minLength: 0)
            CardFooter(leading: data.networkUpload, trailing: data.networkLatency)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FanCard: View {
    let data: StatusData

    var body: some View {
        KitCard {
            CardHeader(icon: .fan, title: "Fan", tint: Ink.gpu, pill: data.fanSpeed)
            HeroValue(value: data.fanRPM, unit: "RPM").padding(.top, Metric.iconGap)
            Spacer(minLength: 0)
            HStack(spacing: Metric.segmentGap) {
                Button("Auto") {}.buttonStyle(SegmentButtonStyle(selected: true))
                Group {
                    Button("Cool") {}.buttonStyle(SegmentButtonStyle())
                    Button("Max") {}.buttonStyle(SegmentButtonStyle())
                }
                .disabled(true)
                .help("Fan control is coming in a later version")
            }
            Spacer(minLength: 0)
            CardFooter(leading: data.fanNote)
        }
    }
}

// MARK: - Process table

private struct ProcessTable: View {
    let data: StatusData

    var body: some View {
        VStack(spacing: 0) {
            ProcessTableHeader(count: data.processCount)
                .padding(.trailing, Metric.iconGap)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if data.processes.isEmpty {
                        Text("Reading processes…")
                            .kitType(.footer)
                            .foregroundStyle(Ink.secondary)
                            .frame(maxWidth: .infinity, minHeight: Metric.rowHeight, alignment: .leading)
                    }
                    ForEach(data.processes, id: \.self) { process in
                        ProcessRow(process: process)
                            .padding(.trailing, Metric.iconGap)
                    }
                }
            }
            .scrollIndicators(.automatic)
        }
        .padding(.leading, Metric.tableInset)
        .padding(.top, Metric.iconGap)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Ink.cardFill, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
            .strokeBorder(Ink.cardStroke, lineWidth: Metric.cardStroke))
        .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
    }
}

/// Opens a System Settings pane by its extension id.
enum SystemSettings {
    static func open(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
