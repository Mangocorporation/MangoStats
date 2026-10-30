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
        for index in sites.indices { sites[index].stats.add(result.1[index]) }
        wifi = result.2
        trackOutage(routerUp: result.0 != nil, internetUp: result.1.contains { $0 != nil })
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
