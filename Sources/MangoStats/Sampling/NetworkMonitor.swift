import CoreLocation
import Foundation
import MangoStatsKit
import Network
import Observation

/// One thing on the local network (S-044).
struct NetworkDevice: Identifiable, Hashable {
    var ip: String
    var mac: String?
    var vendor: String?
    /// The name it announces over Bonjour, if any.
    var name: String?
    var isRouter = false
    var id: String { ip }
}

/// A site the Network tab pings (S-042).
struct NetworkSite: Identifiable {
    let name: String
    let address: String
    var stats = LatencyStats()
    var id: String { address }
}

/// Runs the Network tab's checks while the tab is open (S-039 to S-044).
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var running = false
    private(set) var interface = "en0"
    private(set) var gateway: String?
    private(set) var router = LatencyStats()
    private(set) var routerMAC: String?
    private(set) var routerVendor: String?
    private(set) var routerUPnP: UPnPGateway?
    private(set) var upnpChecked = false
    private(set) var leaseSeconds: Int?
    private(set) var sites: [NetworkSite] = [
        NetworkSite(name: "Cloudflare", address: "1.1.1.1"),
        NetworkSite(name: "Google", address: "8.8.8.8"),
        NetworkSite(name: "Apple", address: "17.253.144.10"),
    ]
    private(set) var hops: [(hop: Int, address: String?, ms: Double?)] = []
    private(set) var dns: [(server: String, ms: Double?)] = []
    private(set) var wifi: WiFiReading?
    private(set) var devices: [NetworkDevice] = []
    private(set) var outages: [Outage] = []
    private(set) var speedResults: [NetworkParse.SpeedResult] = []
    private(set) var speedTestRunning = false
    private(set) var locationAllowed = false
    /// Apps using the network right now, busiest first (S-046).
    private(set) var appTraffic: [AppTraffic] = []
    /// The app that has led heavy traffic for 30 s, if any (S-047).
    private(set) var heavyApp: AppTraffic?

    struct Outage: Identifiable, Hashable {
        var start: Date
        var end: Date?
        var what: String
        var id: Date { start }
    }

    /// The combined internet latency: every site's samples together.
    var internet: LatencyStats {
        var all = LatencyStats()
        for site in sites { for sample in site.stats.samples.suffix(10) { all.add(sample, limit: 30) } }
        return all
    }

    var isp: (address: String, ms: Double)? { NetworkParse.ispHop(hops) }

    var verdict: NetworkVerdict {
        NetworkVerdict(.init(wired: wifi == nil || wifi?.interface != interface, wifiSNR: wifi?.snr, wifiRate: wifi?.rate,
                             router: router, ispHop: isp?.ms, internet: internet))
    }

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var slowTask: Task<Void, Never>?
    @ObservationIgnored private var browsers: [NWBrowser] = []
    @ObservationIgnored private var bonjourNames: [String: String] = [:]
    @ObservationIgnored private var speedProcess: Process?
    @ObservationIgnored private var misses = 0
    @ObservationIgnored private var trafficMeter = TrafficMeter()
    @ObservationIgnored private var heavySince: (key: String, start: Date)?
    @ObservationIgnored private let location = LocationPermission()
    @ObservationIgnored private lazy var vendors: VendorDirectory = {
        let url = Bundle.main.url(forResource: "oui", withExtension: "txt")
        return VendorDirectory(text: url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "")
    }()

    private init() {
        locationAllowed = location.allowed
    }

    // MARK: Start and stop with the tab

    func start() {
        guard !running else { return }
        if HistorySample.enabled {
            // Snapshots show a made-up home network, never the real one (README screenshots are public).
            loadSample()
            return
        }
        running = true
        locationAllowed = location.allowed
        Task { speedResults = await HistoryStore.shared.speedTests() }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fastCheck()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        slowTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.slowCheck()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        browseBonjour()
    }

    func stop() {
        running = false
        task?.cancel()
        slowTask?.cancel()
        browsers.forEach { $0.cancel() }
        browsers = []
    }

    // MARK: Checks

    /// Every 2 s: ping the router and the sites, read Wi-Fi.
    private func fastCheck() async {
        let route = await Task.detached { NetworkProbe.defaultRoute() }.value
        if let route {
            gateway = route.gateway
            interface = route.interface
        }
        let gatewayAddress = gateway
        let addresses = sites.map(\.address)
        let result = await Task.detached(priority: .utility) { () -> (Double?, [Double?], WiFiReading?) in
            async let routerPing = gatewayAddress.flatMap { NetworkProbe.ping($0) }
            let pings = await withTaskGroup(of: (Int, Double?).self) { group in
                for (index, address) in addresses.enumerated() {
                    group.addTask { (index, NetworkProbe.ping(address)) }
                }
                var results = [Double?](repeating: nil, count: addresses.count)
                for await (index, ms) in group { results[index] = ms }
                return results
            }
            return (await routerPing, pings, NetworkProbe.wifi())
        }.value
        if gatewayAddress != nil { router.add(result.0) }
        await measureTraffic()
        for index in sites.indices { sites[index].stats.add(result.1[index]) }
        wifi = result.2
        trackOutage(routerUp: result.0 != nil, internetUp: result.1.contains { $0 != nil })
    }

    /// Per-app traffic from nettop, and the app behind heavy traffic (S-046, S-047).
    private func measureTraffic() async {
        let reading = await Task.detached(priority: .utility) { NetworkProbe.traffic() }.value
        appTraffic = trafficMeter.update(counters: reading.counters, paths: reading.paths, names: reading.names, time: .now)
        if let leader = HeavyTraffic.leader(appTraffic) {
            if heavySince?.key != leader.id { heavySince = (leader.id, .now) }
            heavyApp = Date.now.timeIntervalSince(heavySince?.start ?? .now) >= 30 ? leader : nil
        } else {
            heavySince = nil
            heavyApp = nil
        }
    }

    /// Every minute: the path, DNS, devices, the lease, and UPnP.
    private func slowCheck() async {
        // The first slow check can run before the fast one found the route.
        if gateway == nil, let route = await Task.detached(operation: { NetworkProbe.defaultRoute() }).value {
            gateway = route.gateway
            interface = route.interface
        }
        let iface = interface
        let gatewayAddress = gateway
        let checkUPnP = !upnpChecked
        let result = await Task.detached(priority: .utility) {
            (NetworkProbe.hops(), NetworkProbe.dnsServers().map { ($0, NetworkProbe.dnsTime(server: $0)) },
             NetworkProbe.arp(), NetworkProbe.leaseSeconds(interface: iface),
             checkUPnP ? NetworkProbe.upnpGateway() : nil)
        }.value
        hops = result.0
        dns = result.1.map { (server: $0.0, ms: $0.1) }
        leaseSeconds = result.3
        if checkUPnP {
            routerUPnP = result.4
            upnpChecked = true
        }
        var found: [NetworkDevice] = []
        for entry in result.2 where !NetworkParse.isMulticastOrBroadcast(entry.ip) {
            let isRouter = entry.ip == gatewayAddress
            let mac = NetworkParse.paddedMAC(entry.mac)
            let vendor = vendors.vendor(mac: mac).map(NetworkParse.readableVendor)
            if isRouter {
                routerMAC = mac
                routerVendor = vendor
            }
            found.append(NetworkDevice(ip: entry.ip, mac: mac, vendor: vendor, name: bonjourNames[entry.ip], isRouter: isRouter))
        }
        devices = found.sorted { ($0.isRouter ? 0 : 1, $0.ip.ipSortKey) < ($1.isRouter ? 0 : 1, $1.ip.ipSortKey) }
    }

    /// 5 misses in a row (10 s) starts an outage; an answer ends it (S-042).
    private func trackOutage(routerUp: Bool, internetUp: Bool) {
        if routerUp && internetUp {
            misses = 0
            if let last = outages.indices.last, outages[last].end == nil {
                outages[last].end = .now
                HistoryStore.shared.addOutage(start: outages[last].start, end: .now, what: outages[last].what)
            }
            return
        }
        misses += 1
        if misses == 5 {
            let what = routerUp ? "Internet unreachable" : "Router unreachable"
            outages.append(Outage(start: Date.now.addingTimeInterval(-10), end: nil, what: what))
        }
    }

    // MARK: Devices (Bonjour)

    private func browseBonjour() {
        for type in Self.bonjourTypes {
            let browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: .tcp)
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                for result in results {
                    guard case let .service(name, _, _, _) = result.endpoint else { continue }
                    Task { @MainActor in self?.resolve(name: name, endpoint: result.endpoint) }
                }
            }
            browser.start(queue: .global(qos: .utility))
            browsers.append(browser)
        }
    }

    /// Resolves a Bonjour service to its address, to name the device in the list.
    private func resolve(name: String, endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state, case let .hostPort(host, _)? = connection.currentPath?.remoteEndpoint {
                let ip = "\(host)".components(separatedBy: "%").first ?? "\(host)"
                guard let name = NetworkParse.deviceName(fromService: name) else { return }
                Task { @MainActor in
                    self?.bonjourNames[ip] = name
                    if let index = self?.devices.firstIndex(where: { $0.ip == ip }) { self?.devices[index].name = name }
                }
            }
            if case .ready = state { connection.cancel() }
            if case .failed = state { connection.cancel() }
        }
        connection.start(queue: .global(qos: .utility))
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { connection.cancel() }
    }

    /// Service types listed in NSBonjourServices (Info.plist.in).
    static let bonjourTypes = ["_airplay._tcp", "_raop._tcp", "_ipp._tcp", "_printer._tcp", "_googlecast._tcp",
                               "_companion-link._tcp", "_smb._tcp", "_hap._tcp", "_spotify-connect._tcp",
                               "_device-info._tcp", "_homekit._tcp", "_ssh._tcp"]

    // MARK: Speed test (S-043)

    func runSpeedTest() {
        guard !speedTestRunning else { return }
        speedTestRunning = true
        let process = Process()
        speedProcess = process
        Task {
            let result = await Task.detached(priority: .userInitiated) { NetworkProbe.speedTest(process: process) }.value
            speedTestRunning = false
            speedProcess = nil
            if let result {
                speedResults.insert(result, at: 0)
                HistoryStore.shared.addSpeedTest(result)
            }
        }
    }

    func cancelSpeedTest() {
        speedProcess?.terminate()
    }

    /// The snapshot's network: invented addresses and devices.
    private func loadSample() {
        running = true
        gateway = "192.168.1.1"
        interface = "en0"
        router = LatencyStats(samples: [4.1, 5.2, 3.9, 6.0, 4.4, 5.1, 4.6, 4.8])
        routerMAC = "a0:b1:c2:d3:e4:f5"
        routerVendor = "Example Networks"
        upnpChecked = true
        leaseSeconds = 86_400
        sites[0].stats = LatencyStats(samples: [14, 15, 13, 16, 14, 15])
        sites[1].stats = LatencyStats(samples: [16, 17, 15, 18, 16, 17])
        sites[2].stats = LatencyStats(samples: [19, 21, 18, 20, 19, 22])
        hops = [(1, "192.168.1.1", 4.8), (2, "100.64.0.1", 9.2), (3, "203.0.113.1", 11.5), (4, "198.51.100.7", 13.1)]
        dns = [(server: "192.168.1.1", ms: 9.4), (server: "1.1.1.1", ms: 15.2)]
        wifi = WiFiReading(interface: "en0", connected: true, ssid: "Home", rssi: -58, noise: -95, rate: 866,
                           channel: 44, band: 2, width: 3, phyMode: 6, security: 4) // grid: ok CoreWLAN raw values
        devices = [
            NetworkDevice(ip: "192.168.1.1", mac: "a0:b1:c2:d3:e4:f5", vendor: "Example Networks", isRouter: true),
            NetworkDevice(ip: "192.168.1.20", mac: "3c:22:fb:10:20:30", vendor: "Apple, Inc.", name: "Living Room TV"),
            NetworkDevice(ip: "192.168.1.31", mac: "00:1b:a9:44:55:66", vendor: "Brother Industries, Ltd.", name: "Office Printer"),
            NetworkDevice(ip: "192.168.1.42", mac: "ba:11:22:33:44:55", vendor: "Private address"),
        ]
        appTraffic = [
            AppTraffic(name: "Dropbox", bundlePath: "/Applications/Dropbox.app", download: 12_000, upload: 4_200_000, sessionBytes: 1_900_000_000),
            AppTraffic(name: "Safari", bundlePath: "/Applications/Safari.app", download: 640_000, upload: 22_000, sessionBytes: 310_000_000),
            AppTraffic(name: "Music", bundlePath: "/System/Applications/Music.app", download: 320_000, upload: 4_000, sessionBytes: 96_000_000),
            AppTraffic(name: "mDNSResponder", bundlePath: nil, download: 2_100, upload: 1_400, sessionBytes: 3_100_000),
        ]
        heavyApp = appTraffic[0]
        speedResults = [NetworkParse.SpeedResult(date: .now.addingTimeInterval(-3_600), download: 412, upload: 38.5,
                                                 responsiveness: 1_450, idleLatency: 18)]
    }

    // MARK: Location (S-041)

    func requestLocation() {
        location.request { [weak self] allowed in self?.locationAllowed = allowed }
    }
}

/// Location permission, only for the Wi-Fi network's name: macOS hides the
/// SSID from apps without it (S-041).
final class LocationPermission: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((Bool) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    var allowed: Bool {
        let status = manager.authorizationStatus
        return status == .authorizedAlways || status == .authorized
    }

    var denied: Bool { manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted }

    func request(_ completion: @escaping (Bool) -> Void) {
        self.completion = completion
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            completion(allowed)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.completion?(self.allowed) }
    }
}

private extension String {
    /// "192.168.15.9" sorts after "192.168.15.10" as text; this sorts by number.
    var ipSortKey: String {
        split(separator: ".").map { String(repeating: "0", count: max(0, 3 - $0.count)) + $0 }.joined(separator: ".")
    }
}
