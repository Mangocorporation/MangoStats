import SwiftUI
import MangoStatsKit

/// The Network tab (S-039 to S-044): where a problem is, the router, Wi-Fi,
/// a speed test, the internet and DNS, outages, and devices.
struct NetworkView: View {
    @Environment(AppModel.self) private var model
    private var monitor = NetworkMonitor.shared

    private let row = [GridItem(.flexible(), spacing: Metric.cardGap, alignment: .top),
                       GridItem(.flexible(), spacing: Metric.cardGap, alignment: .top),
                       GridItem(.flexible(), spacing: Metric.cardGap, alignment: .top)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metric.sectionGap) {
                header
                VerdictCard(monitor: monitor)
                LazyVGrid(columns: row, spacing: Metric.cardGap) {
                    RouterCard(monitor: monitor)
                    WiFiCard(monitor: monitor)
                    SpeedTestCard(monitor: monitor)
                }
                HStack(alignment: .top, spacing: Metric.cardGap) {
                    InternetCard(monitor: monitor)
                    OutagesCard(monitor: monitor)
                }
                DevicesCard(monitor: monitor)
            }
            .padding(.horizontal, Metric.windowMargin)
            .padding(.top, Metric.windowTop)
            .padding(.bottom, Metric.windowMargin)
        }
        .defaultScrollAnchor(.top)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Metric.iconGap) {
                Text("Network").kitType(.pageTitle).foregroundStyle(Ink.text)
                Text(subtitle).kitType(.pageSubtitle).foregroundStyle(Ink.secondary)
            }
            Spacer()
            LivePill(text: "Live · every 2 s")
            if monitor.speedTestRunning {
                Button("Cancel Speed Test") { monitor.cancelSpeedTest() }
                    .buttonStyle(SecondaryButtonStyle())
                    .help("Stop the speed test")
            } else {
                Button("Run Speed Test") { monitor.runSpeedTest() }
                    .buttonStyle(PrimaryButtonStyle())
                    .help("Measure download, upload, and responsiveness with Apple's servers (uses a few hundred MB)")
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = [monitor.wifi?.connected == true ? "Wi-Fi" : "Ethernet"]
        if let ms = monitor.router.average { parts.append("router \(Self.ms(ms))") }
        if let ms = monitor.internet.average { parts.append("internet \(Self.ms(ms))") }
        return parts.count == 1 ? "Measuring…" : parts.joined(separator: " · ")
    }

    static func ms(_ value: Double) -> String { "\(Format.number(value, digits: value < 10 ? 1 : 0)) ms" }
    static func percent(_ value: Double) -> String { "\(Format.number(value * 100, digits: 0)) %" }
}

// MARK: - Verdict and path

private struct VerdictCard: View {
    let monitor: NetworkMonitor

    var body: some View {
        let verdict = monitor.verdict
        let calm = verdict.culprit == nil
        KitCard(height: nil, fitsContent: true, tinted: !calm, padding: Metric.insightPadding) {
            Eyebrow(text: calm ? "Connection" : "Worth a look", icon: calm ? .health : .warning,
                    color: calm ? Ink.live : Ink.accent)
            Text(monitor.router.samples.isEmpty ? "Checking your network…" : verdict.title)
                .kitType(.insightTitle)
                .foregroundStyle(Ink.text)
                .padding(.top, Metric.cardGap - 2)
            Text(monitor.router.samples.isEmpty ? "Pinging your router and the internet." : verdict.body)
                .kitType(.body)
                .foregroundStyle(Ink.body)
                .padding(.top, Metric.iconGap)
            PathDiagram(monitor: monitor, health: verdict.health)
                .padding(.top, Metric.sectionGap - 8)
        }
        .accessibilityElement(children: .contain)
    }
}

/// This Mac → Wi-Fi → Router → ISP → Internet, a color per step.
private struct PathDiagram: View {
    let monitor: NetworkMonitor
    let health: [PathStep: StepHealth]

    var body: some View {
        let wired = monitor.wifi?.connected != true
        HStack(alignment: .top, spacing: 0) {
            // Snapshots are public: never the Mac's own name there.
            node("This Mac", icon: .window, detail: HistorySample.enabled ? "MacBook Pro" : Host.current().localizedName ?? "",
                 health: .good)
            link(health[.wifi] ?? .unknown)
            node(wired ? "Ethernet" : "Wi-Fi", icon: .network,
                 detail: monitor.wifi.map { $0.connected ? "\(WiFiWords.signal(snr: $0.snr)) · \(Int($0.snr)) dB SNR" : "Not connected" } ?? "Cable",
                 health: health[.wifi] ?? .unknown)
            link(health[.router] ?? .unknown)
            node("Router", icon: .storage, detail: latency(monitor.router), health: health[.router] ?? .unknown)
            link(health[.isp] ?? .unknown)
            node("ISP", icon: .network, detail: monitor.isp.map { NetworkView.ms($0.ms) } ?? "–",
                 health: health[.isp] ?? .unknown)
            link(health[.internet] ?? .unknown)
            node("Internet", icon: .network, detail: latency(monitor.internet), health: health[.internet] ?? .unknown)
        }
    }

    private func latency(_ stats: LatencyStats) -> String {
        guard let average = stats.average else { return stats.samples.isEmpty ? "–" : "No answer" }
        let loss = stats.loss > 0 ? " · \(NetworkView.percent(stats.loss)) lost" : ""
        return NetworkView.ms(average) + loss
    }

    private func node(_ title: String, icon: KitIcon, detail: String, health: StepHealth) -> some View {
        VStack(spacing: Metric.iconGap) {
            Circle()
                .fill(color(health).opacity(0.14))
                .overlay(Circle().strokeBorder(color(health), lineWidth: Metric.lineWidth))
                .overlay(icon.view(size: Metric.iconSize + 2, color: color(health)))
                .frame(width: Metric.iconButton, height: Metric.iconButton)
            Text(title).kitType(.statLabel).foregroundStyle(Ink.text)
            Text(detail).kitType(.mono).foregroundStyle(Ink.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail), \(word(health))")
    }

    private func link(_ health: StepHealth) -> some View {
        Capsule()
            .fill(color(health))
            .frame(height: Metric.pathStroke)
            .frame(maxWidth: .infinity)
            .padding(.top, Metric.iconButton / 2 - 1)
    }

    private func color(_ health: StepHealth) -> Color {
        switch health {
        case .good: Ink.live
        case .slow: Ink.accent
        case .failing: Ink.warning
        case .unknown: Ink.faint
        }
    }

    private func word(_ health: StepHealth) -> String {
        switch health {
        case .good: "fine"
        case .slow: "slow"
        case .failing: "failing"
        case .unknown: "not measured yet"
        }
    }
}

// MARK: - Cards

/// A label and a mono value on one line.
private struct InfoRow: View {
    let label: String
    let value: String
    var highlight = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).kitType(.statLabel).foregroundStyle(Ink.secondary)
            Spacer(minLength: Metric.cardGap)
            Text(value).kitType(.mono).foregroundStyle(highlight ? Ink.accent : Ink.body)
                .lineLimit(1).truncationMode(.middle)
        }
        .padding(.vertical, Metric.infoRowPadding)
    }
}

private struct RouterCard: View {
    let monitor: NetworkMonitor

    var body: some View {
        KitCard(height: nil, fitsContent: true) {
            CardHeader(title: "Router", detail: monitor.gateway)
            HeroValue(value: monitor.router.average.map { Format.number($0, digits: 1) } ?? "--", unit: "ms")
                .padding(.top, Metric.heroTop)
            VStack(spacing: 0) {
                InfoRow(label: "Maker", value: monitor.routerVendor ?? (monitor.routerMAC == nil ? "–" : "Unknown"))
                InfoRow(label: "Jitter", value: monitor.router.jitter.map(NetworkView.ms) ?? "–")
                InfoRow(label: "Loss", value: NetworkView.percent(monitor.router.loss), highlight: monitor.router.loss > 0.02)
                InfoRow(label: "DHCP lease", value: monitor.leaseSeconds.map { Format.duration(minutes: $0 / 60) } ?? "–")
                InfoRow(label: "Also your DNS", value: monitor.gateway.map { gw in monitor.dns.contains { $0.server == gw } ? "Yes" : "No" } ?? "–")
                InfoRow(label: "Model", value: model)
            }
            .padding(.top, Metric.cardGap)
        }
    }

    private var model: String {
        if let upnp = monitor.routerUPnP { return [upnp.manufacturer, upnp.model].compactMap { $0 }.joined(separator: " ") }
        return monitor.upnpChecked ? "Not shared (UPnP is off)" : "–"
    }
}

private struct WiFiCard: View {
    let monitor: NetworkMonitor

    var body: some View {
        KitCard(height: nil, fitsContent: true) {
            if let wifi = monitor.wifi, wifi.connected {
                CardHeader(title: "Wi-Fi", detail: WiFiWords.standard(phyMode: wifi.phyMode))
                HeroValue(value: WiFiWords.signal(snr: wifi.snr), unit: "\(Int(wifi.snr)) dB SNR")
                    .padding(.top, Metric.heroTop)
                VStack(spacing: 0) {
                    HStack {
                        Text("Network").kitType(.statLabel).foregroundStyle(Ink.secondary)
                        Spacer()
                        if let ssid = wifi.ssid {
                            Text(ssid).kitType(.mono).foregroundStyle(Ink.body)
                        } else {
                            Button("Show Name…") { monitor.requestLocation() }
                                .buttonStyle(LinkButtonStyle())
                                .help("macOS shares the network's name only with apps allowed to use Location")
                        }
                    }
                    .padding(.vertical, Metric.infoRowPadding)
                    InfoRow(label: "Signal · noise", value: "\(Int(wifi.rssi)) · \(Int(wifi.noise)) dBm")
                    InfoRow(label: "Link rate", value: "\(Format.number(wifi.rate, digits: 0)) Mbps", highlight: wifi.rate < 50)
                    InfoRow(label: "Band", value: "\(WiFiWords.band(wifi.band)) · ch \(wifi.channel) · \(WiFiWords.width(wifi.width))")
                    InfoRow(label: "Security", value: security(wifi.security))
                }
                .padding(.top, Metric.cardGap)
            } else {
                CardHeader(title: "Wi-Fi", detail: monitor.wifi == nil ? "Off" : "Not connected")
                Text(monitor.wifi == nil ? "Connected by Ethernet or Wi-Fi is off." : "Wi-Fi is on but not connected.")
                    .kitType(.body).foregroundStyle(Ink.body)
                    .padding(.top, Metric.heroTop)
            }
        }
    }

    /// CWSecurity raw values.
    private func security(_ raw: Int) -> String {
        switch raw {
        case 0: "None"
        case 1: "WEP"
        case 2, 3: "WPA"
        case 4: "WPA2"
        case 11, 12, 15: "WPA3"
        default: "WPA2/WPA3"
        }
    }
}

private struct SpeedTestCard: View {
    let monitor: NetworkMonitor

    var body: some View {
        KitCard(height: nil, fitsContent: true) {
            CardHeader(title: "Speed test", detail: monitor.speedResults.first.map { $0.date.formatted(date: .abbreviated, time: .shortened) })
            if monitor.speedTestRunning {
                HStack(spacing: Metric.iconGap * 2) {
                    ProgressView().controlSize(.small)
                    Text("Testing with Apple's servers… about 20 s").kitType(.body).foregroundStyle(Ink.body)
                }
                .padding(.top, Metric.heroTop)
            } else if let last = monitor.speedResults.first {
                HeroValue(value: Format.number(last.download, digits: 0), unit: "Mbps down").padding(.top, Metric.heroTop)
                VStack(spacing: 0) {
                    InfoRow(label: "Upload", value: "\(Format.number(last.upload, digits: 0)) Mbps")
                    InfoRow(label: "Responsiveness", value: last.responsiveness.map { "\(last.responsivenessWord ?? "") · \(Int($0)) RPM" } ?? "–")
                    InfoRow(label: "Idle latency", value: last.idleLatency.map(NetworkView.ms) ?? "–")
                    ForEach(monitor.speedResults.dropFirst().prefix(3), id: \.date) { past in
                        InfoRow(label: past.date.formatted(date: .abbreviated, time: .shortened),
                                value: "↓ \(Format.number(past.download, digits: 0)) · ↑ \(Format.number(past.upload, digits: 0))")
                    }
                }
                .padding(.top, Metric.cardGap)
            } else {
                Text("Run a test to measure download, upload, and how responsive the connection stays under load.")
                    .kitType(.body).foregroundStyle(Ink.body)
                    .padding(.top, Metric.heroTop)
            }
        }
    }
}

private struct InternetCard: View {
    let monitor: NetworkMonitor

    var body: some View {
        KitCard(height: nil, fitsContent: true) {
            CardHeader(title: "Internet", detail: "latency · jitter · loss")
            VStack(spacing: 0) {
                ForEach(monitor.sites) { site in
                    InfoRow(label: site.name, value: [site.stats.average.map(NetworkView.ms) ?? "–",
                                                      site.stats.jitter.map(NetworkView.ms) ?? "–",
                                                      NetworkView.percent(site.stats.loss)].joined(separator: " · "),
                            highlight: site.stats.loss > 0.02 || (site.stats.average ?? 0) > 100)
                }
            }
            .padding(.top, Metric.heroTop)
            Text("DNS").kitType(.statLabel).foregroundStyle(Ink.secondary).padding(.top, Metric.cardGap)
            VStack(spacing: 0) {
                if monitor.dns.isEmpty {
                    InfoRow(label: "Servers", value: "–")
                }
                ForEach(monitor.dns, id: \.server) { entry in
                    InfoRow(label: entry.server, value: entry.ms.map(NetworkView.ms) ?? "No answer", highlight: entry.ms == nil)
                }
            }
            .padding(.top, Metric.iconGap)
        }
    }
}

private struct OutagesCard: View {
    let monitor: NetworkMonitor

    var body: some View {
        KitCard(height: nil, fitsContent: true) {
            CardHeader(title: "Outages", detail: "while this tab is open")
            if monitor.outages.isEmpty {
                Text("None so far. MangoStats notes when the router or the internet stops answering for 10 seconds.")
                    .kitType(.body).foregroundStyle(Ink.body)
                    .padding(.top, Metric.heroTop)
            } else {
                VStack(spacing: 0) {
                    ForEach(monitor.outages.reversed()) { outage in
                        InfoRow(label: outage.what,
                                value: outage.end.map { "\(outage.start.formatted(date: .omitted, time: .shortened)) · \(Format.duration(minutes: max(1, Int($0.timeIntervalSince(outage.start) / 60))))" } ?? "Now",
                                highlight: outage.end == nil)
                    }
                }
                .padding(.top, Metric.heroTop)
            }
        }
        .frame(maxWidth: 420)
    }
}

private struct DevicesCard: View {
    let monitor: NetworkMonitor

    var body: some View {
        KitCard(height: nil, fitsContent: true) {
            CardHeader(title: "Devices", detail: monitor.devices.isEmpty ? nil : "\(monitor.devices.count) seen")
            if monitor.devices.isEmpty {
                Text("Devices appear here as your Mac talks to them. Names come from devices that announce themselves, like printers, speakers, and other Macs.")
                    .kitType(.body).foregroundStyle(Ink.body)
                    .padding(.top, Metric.heroTop)
            } else {
                VStack(spacing: 0) {
                    ForEach(monitor.devices) { device in
                        HStack(spacing: Metric.cardGap - 4) {
                            Text(String((device.name ?? device.vendor ?? "?").first ?? "?"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(device.isRouter ? Ink.onAccent : Ink.text)
                                .frame(width: Metric.avatar * 0.8, height: Metric.avatar * 0.8)
                                .background(device.isRouter ? Ink.accent : Ink.pillFill,
                                            in: RoundedRectangle(cornerRadius: Metric.avatarRadius - 2, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(device.name ?? (device.isRouter ? "Router" : device.vendor ?? "Unknown device"))
                                    .kitType(.rowName).foregroundStyle(Ink.text).lineLimit(1)
                                Text(device.isRouter ? (device.vendor ?? "Your router") : device.name == nil ? "Doesn't announce a name" : (device.vendor ?? ""))
                                    .kitType(.rowKind).foregroundStyle(Ink.secondary).lineLimit(1)
                            }
                            Spacer()
                            Text(device.ip).kitType(.rowNumber).foregroundStyle(Ink.body)
                                .frame(width: Metric.colPID + 20, alignment: .trailing)
                            Text(device.mac ?? "–").kitType(.mono).foregroundStyle(Ink.secondary)
                                .frame(width: Metric.colMemory + 40, alignment: .trailing)
                        }
                        .frame(height: Metric.rowHeight - 10)
                        .overlay(alignment: .bottom) { Rectangle().fill(Ink.divider).frame(height: Metric.cardStroke) }
                    }
                }
                .padding(.top, Metric.iconGap)
            }
        }
    }
}
