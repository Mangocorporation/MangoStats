import SwiftUI
import MangoStatsKit

/// The popover that opens from the menu bar item, laid out like
/// local/reference/menubar-popover.png (S-002 to S-008).
struct PopoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private let columns = [GridItem(.flexible(), spacing: Metric.cardGap * 0.7),
                           GridItem(.flexible(), spacing: Metric.cardGap * 0.7)]

    var body: some View {
        let data = model.status
        VStack(alignment: .leading, spacing: Metric.popoverMargin) {
            HealthHeader(data: data)
            LazyVGrid(columns: columns, spacing: Metric.cardGap * 0.7) {
                PopCPUCard(data: data)
                PopGPUCard(data: data)
                PopMemoryCard(data: data)
                PopDiskCard(data: data)
                PopNetworkCard(data: data)
                PopFanCard(data: data)
            }
            PopBatteryCard(data: data)
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

    private var footer: some View {
        HStack(spacing: Metric.iconGap) {
            Button("Open MangoStats", systemImage: KitIcon.window.symbol) {
                NSApp.activate()
                openWindow(id: "status")
            }
            .keyboardShortcut("1")
            .help("Open the Status window (⌘1)")
            Spacer()
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
        .padding(.horizontal, Metric.iconGap)
    }
}

/// Camera, mic, awake, and screen (S-019).
private struct PrivacyRow: View {
    let data: StatusData

    var body: some View {
        KitCard(style: .popover, fitsContent: true) {
            HStack(spacing: Metric.cardPadding) {
                HStack(spacing: Metric.iconGap) {
                    KitIcon.camera.view(size: Metric.iconSize + 2, color: data.privacyActive ? Ink.hot : Ink.secondary)
                    KitIcon.mic.view(size: Metric.iconSize + 2, color: data.privacyActive ? Ink.hot : Ink.secondary)
                    Text(data.privacyText)
                        .foregroundStyle(data.privacyActive ? Ink.hot : Ink.label)
                        .fontWeight(data.privacyActive ? .semibold : .regular)
                }
                .help(data.privacyActive ? "\(data.privacyText) by an app" : "No app is using the camera or microphone")
                Spacer(minLength: 0)
                Label { Text(data.awakeText) } icon: { KitIcon.awake.view(size: Metric.iconSize + 2) }
                    .help(data.awakeHelp)
                Label { Text(data.screenText) } icon: { KitIcon.display.view(size: Metric.iconSize + 2) }
                    .help(data.screenHelp)
            }
            .labelStyle(PrivacyLabelStyle())
            .kitType(.footer)
            .foregroundStyle(Ink.label)
            .lineLimit(1)
        }
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

// MARK: - Header

private struct HealthHeader: View {
    let data: StatusData

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.popoverMargin) {
            HStack(alignment: .firstTextBaseline, spacing: Metric.iconGap * 2) {
                KitIcon.health.view(size: Metric.headerIcon, color: Ink.health)
                HStack(alignment: .firstTextBaseline, spacing: Metric.iconGap) {
                    Text(data.health)
                        .kitType(.health)
                        .foregroundStyle(data.health == "--" ? Ink.secondary : Ink.text)
                    Text(data.healthWord).kitType(.healthWord).foregroundStyle(Ink.label)
                }
            }
            .help(data.healthReasons.isEmpty ? "Nothing needs attention" : data.healthReasons.joined(separator: "\n"))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Health \(data.health), \(data.healthWord)")
            HStack(spacing: Metric.iconGap) {
                KitChip(text: data.chip)
                KitChip(text: data.ram)
                KitChip(text: data.macOS)
                KitChip(text: data.uptime)
            }
        }
        .padding(.horizontal, Metric.iconGap)
        .padding(.top, Metric.iconGap)
    }
}

// MARK: - Cards

private struct PopCPUCard: View {
    let data: StatusData

    var body: some View {
        KitCard(style: .popover) {
            CardHeader(icon: .cpu, title: "CPU", tint: Ink.cpu, pill: data.cpuTemp, style: .popover)
            HeroValue(value: data.cpu, unit: "%", role: .popHero).padding(.top, Metric.iconGap)
            Spacer(minLength: 0)
            BarHistory(values: data.cpuHistory)
            Spacer(minLength: 0)
            CardFooter(leading: data.cpuFooter)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PopGPUCard: View {
    let data: StatusData

    var body: some View {
        KitCard(style: .popover) {
            CardHeader(icon: .gpu, title: "GPU", tint: Ink.gpu, pill: data.gpuTemp, style: .popover)
            HeroValue(value: data.gpu, unit: "%", role: .popHero).padding(.top, Metric.iconGap)
            Spacer(minLength: 0)
            LineChart(values: data.gpuHistory, tint: Ink.gpu).frame(height: Metric.popChartHeight)
            Spacer(minLength: 0)
            CardFooter(leading: data.gpuFooter)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PopMemoryCard: View {
    let data: StatusData

    var body: some View {
        KitCard(style: .popover) {
            CardHeader(icon: .memory, title: "MEM", tint: Ink.memory,
                       pill: data.memoryPressure == "--" ? nil : data.memoryPressure,
                       pillHot: data.memoryPressureLevel != .normal, style: .popover)
            HeroValue(value: data.memory, unit: "%", role: .popHero).padding(.top, Metric.iconGap)
            Spacer(minLength: 0)
            AreaChart(values: data.memoryHistory, height: Metric.popChartHeight)
            Spacer(minLength: 0)
            CardFooter(leading: data.memoryUsedOfTotal)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Memory, \(data.memory) percent, pressure \(data.memoryPressure), \(data.memoryUsedOfTotal)")
    }
}

private struct PopDiskCard: View {
    let data: StatusData

    var body: some View {
        Button {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/"))
        } label: {
            KitCard(style: .popover) {
                CardHeader(icon: .disk, title: "Free space", tint: Ink.network, pill: data.diskTotal, style: .popover)
                HeroValue(value: data.diskFree, unit: data.diskFreeUnit, role: .popHero).padding(.top, Metric.iconGap)
                Spacer(minLength: 0)
                KitProgressBar(value: data.diskUsed, fill: AnyShapeStyle(Ink.diskPopover))
                Spacer(minLength: 0)
                CardFooter(leading: data.diskFooter)
            }
        }
        .buttonStyle(.plain)
        .help("Open the startup disk in Finder")
        .accessibilityLabel("Free space, \(data.diskFree) \(data.diskFreeUnit) of \(data.diskTotal), \(data.diskFooter)")
    }
}

private struct PopNetworkCard: View {
    let data: StatusData

    var body: some View {
        KitCard(style: .popover) {
            CardHeader(icon: .network, title: "Network", tint: Ink.network, pill: data.networkInterface, style: .popover)
            HeroValue(value: data.network, unit: data.networkUnit, role: .popHero).padding(.top, Metric.iconGap)
            Spacer(minLength: 0)
            LineChart(values: data.networkHistory, tint: Ink.network, ceiling: nil).frame(height: Metric.popChartHeight)
            Spacer(minLength: 0)
            CardFooter(leading: data.networkUploadShort, trailing: data.networkLatency)
                .accessibilityLabel("\(data.networkUpload), \(data.networkLatency)")
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PopFanCard: View {
    let data: StatusData

    var body: some View {
        KitCard(style: .popover) {
            CardHeader(icon: .fan, title: "Fan", tint: Ink.gpu, pill: data.fanSpeed, style: .popover)
            HeroValue(value: data.fanRPM, unit: "RPM", role: .popHero).padding(.top, Metric.iconGap)
            Text(data.fanNote).kitType(.footer).foregroundStyle(Ink.secondary)
            Spacer(minLength: 0)
            FanModePicker(compact: true)
        }
    }
}

private struct PopBatteryCard: View {
    let data: StatusData

    var body: some View {
        KitCard(style: .popover, fitsContent: true) {
            CardHeader(icon: nil, title: "Battery", pill: data.hasBattery ? data.batteryHealth : nil, style: .popover)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: Metric.iconGap) {
                    HStack(alignment: .firstTextBaseline, spacing: Metric.iconGap) {
                        Text(data.hasBattery ? "\(data.battery)%" : "--")
                            .kitType(.health)
                            .foregroundStyle(data.hasBattery ? Ink.text : Ink.secondary)
                        if let watts = data.batteryWatts {
                            HStack(spacing: 2) {
                                KitIcon.bolt.view(size: Metric.headerIcon * 0.7, color: Ink.label)
                                Text(watts).kitType(.healthWord).foregroundStyle(Ink.label)
                            }
                        }
                    }
                    Text(data.batteryState).kitType(.footer).foregroundStyle(Ink.secondary)
                }
                Spacer()
                Button("Open Battery Settings", systemImage: KitIcon.laptop.symbol) {
                    SystemSettings.open("com.apple.Battery-Settings.extension")
                }
                .buttonStyle(RingButtonStyle(progress: data.batteryLevel))
                .help("Open Battery settings")
                Button("Open Energy Settings", systemImage: KitIcon.waves.symbol) {
                    SystemSettings.open("com.apple.Lock-Screen-Settings.extension")
                }
                .buttonStyle(RingButtonStyle(progress: 0.8))
                .help("Open Energy settings")
            }
            .padding(.top, Metric.iconGap)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Battery, \(data.battery) percent, \(data.batteryState), \(data.batteryHealth)")
    }
}
