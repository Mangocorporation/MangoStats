import Foundation

/// Latency to one target from a run of pings (S-039).
public struct LatencyStats: Equatable, Sendable {
    /// Milliseconds, or nil for a lost ping, oldest first.
    public var samples: [Double?]

    public init(samples: [Double?] = []) {
        self.samples = samples
    }

    public var received: [Double] { samples.compactMap { $0 } }
    public var average: Double? { received.isEmpty ? nil : received.reduce(0, +) / Double(received.count) }
    /// Mean absolute difference between consecutive answers, like RFC 3550.
    public var jitter: Double? {
        let values = received
        guard values.count > 1 else { return nil }
        return zip(values, values.dropFirst()).map { abs($1 - $0) }.reduce(0, +) / Double(values.count - 1)
    }
    /// Share of pings lost, 0…1.
    public var loss: Double { samples.isEmpty ? 0 : Double(samples.count - received.count) / Double(samples.count) }
    public var reachable: Bool { !received.isEmpty }

    /// Keeps the last `limit` samples.
    public mutating func add(_ milliseconds: Double?, limit: Int = 30) {
        samples.append(milliseconds)
        if samples.count > limit { samples.removeFirst(samples.count - limit) }
    }
}

/// One step of the path from this Mac to the internet.
public enum PathStep: String, CaseIterable, Sendable {
    case wifi, router, isp, internet
}

public enum StepHealth: Equatable, Sendable {
    case unknown, good, slow, failing
}

/// Where the network problem is, in plain words (S-039).
public struct NetworkVerdict: Equatable, Sendable {
    public var title: String
    public var body: String
    /// The step to blame, or nil when all is fine.
    public var culprit: PathStep?
    public var health: [PathStep: StepHealth]

    public struct Input: Sendable {
        public var wired: Bool
        public var wifiSNR: Double?
        public var wifiRate: Double?
        public var router: LatencyStats
        /// The first hop past the router (the ISP), milliseconds.
        public var ispHop: Double?
        public var internet: LatencyStats

        public init(wired: Bool = false, wifiSNR: Double? = nil, wifiRate: Double? = nil, router: LatencyStats,
                    ispHop: Double? = nil, internet: LatencyStats) {
            self.wired = wired
            self.wifiSNR = wifiSNR
            self.wifiRate = wifiRate
            self.router = router
            self.ispHop = ispHop
            self.internet = internet
        }
    }

    public init(title: String, body: String, culprit: PathStep?, health: [PathStep: StepHealth]) {
        self.title = title
        self.body = body
        self.culprit = culprit
        self.health = health
    }

    public init(_ input: Input) {
        var health: [PathStep: StepHealth] = [:]
        if input.wired {
            health[.wifi] = .good
        } else if let snr = input.wifiSNR {
            health[.wifi] = snr < 15 ? .failing : (snr < 20 || (input.wifiRate ?? 999) < 50) ? .slow : .good
        } else {
            health[.wifi] = .unknown
        }
        let router = input.router
        if router.samples.isEmpty {
            health[.router] = .unknown
        } else if !router.reachable || router.loss > 0.2 {
            health[.router] = .failing
        } else {
            // On Wi-Fi the router's latency includes the radio link, whose power saving
            // often adds 10–30 ms; on Ethernet anything over 20 ms is slow.
            let slowRouter = input.wired ? 20.0 : 50.0
            health[.router] = router.loss > 0.02 || (router.average ?? 0) > slowRouter ? .slow : .good
        }
        if let hop = input.ispHop {
            health[.isp] = hop > 40 ? .slow : .good
        } else {
            health[.isp] = .unknown
        }
        let internet = input.internet
        if internet.samples.isEmpty {
            health[.internet] = .unknown
        } else if !internet.reachable || internet.loss > 0.2 {
            health[.internet] = .failing
        } else {
            health[.internet] = internet.loss > 0.02 || (internet.average ?? 0) > 100 ? .slow : .good
        }

        let wifiWord = input.wired ? "Ethernet" : "Wi-Fi"
        if health[.router] == .failing && !router.reachable {
            self.init(title: "Offline", body: "Your router isn't answering. Check that \(wifiWord) is connected and the router is on.",
                      culprit: .router, health: health)
        } else if let step = PathStep.allCases.first(where: { health[$0] == .failing || health[$0] == .slow }) {
            let text: (String, String) = switch step {
            case .wifi: ("Your Wi-Fi is the weak link",
                         "The signal is weak or the link is slow. Moving closer to the router, or to a less crowded channel, helps most.")
            case .router where router.loss > 0.02:
                ("Your router is dropping packets",
                 "\(Int((router.loss * 100).rounded()))% of pings to the router are lost, so every connection suffers. Restarting the router often helps.")
            case .router: ("Your router is slow to answer",
                           "Pings to the router take \(Int((router.average ?? 0).rounded())) ms, so every connection waits. Restarting the router often helps.")
            case .isp: ("Your ISP is slow right now",
                        "Your Wi-Fi and router are fine; the delay starts at your internet provider.")
            case .internet: ("The internet is slow right now",
                             "Everything up to your ISP is fine; the sites themselves are slow or far away.")
            }
            self.init(title: text.0, body: text.1, culprit: step, health: health)
        } else {
            self.init(title: "All good", body: "\(wifiWord), router, ISP, and internet all answer quickly.",
                      culprit: nil, health: health)
        }
    }
}

/// Wi-Fi in words (S-041).
public enum WiFiWords {
    /// SNR in dB: ≥ 40 excellent, ≥ 25 good, ≥ 15 fair, else poor.
    public static func signal(snr: Double) -> String {
        switch snr {
        case 40...: "Excellent"
        case 25...: "Good"
        case 15...: "Fair"
        default: "Poor"
        }
    }

    /// CWPHYMode raw values: 1 a, 2 b, 3 g, 4 n, 5 ac, 6 ax, 7 be.
    public static func standard(phyMode: Int) -> String {
        switch phyMode {
        case 4: "Wi-Fi 4"
        case 5: "Wi-Fi 5"
        case 6: "Wi-Fi 6"
        case 7: "Wi-Fi 7"
        case 1, 2, 3: "Legacy Wi-Fi"
        default: "Wi-Fi"
        }
    }

    /// CWChannelBand raw values: 1 2.4 GHz, 2 5 GHz, 3 6 GHz.
    public static func band(_ raw: Int) -> String {
        switch raw {
        case 1: "2.4 GHz"
        case 2: "5 GHz"
        case 3: "6 GHz"
        default: "Unknown band"
        }
    }

    /// CWChannelWidth raw values: 1 20, 2 40, 3 80, 4 160 MHz.
    public static func width(_ raw: Int) -> String {
        switch raw {
        case 1: "20 MHz"
        case 2: "40 MHz"
        case 3: "80 MHz"
        case 4: "160 MHz"
        default: "–"
        }
    }
}

/// Device makers from the IEEE OUI list (S-040, S-044).
public struct VendorDirectory: Sendable {
    private let vendors: [String: String]

    /// `text` is "F45420\tSagemcom Broadband SAS" lines.
    public init(text: String) {
        var vendors: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1)
            if parts.count == 2 { vendors[String(parts[0])] = String(parts[1]) }
        }
        self.vendors = vendors
    }

    public var count: Int { vendors.count }

    /// "f4:54:20:55:4c:c0" -> the maker, "Private address" for a randomized MAC, or nil.
    public func vendor(mac: String) -> String? {
        let hex = mac.split(separator: ":").map { $0.count == 1 ? "0" + $0 : String($0) }
        guard hex.count == 6, let first = UInt8(hex[0], radix: 16) else { return nil }
        if first & 0x02 != 0 { return "Private address" }
        return vendors[hex.prefix(3).joined().uppercased()]
    }
}

/// Small parsers for the tools the Network tab runs (S-040, S-042 to S-044).
public enum NetworkParse {
    /// `arp -an` lines -> (ip, mac). Incomplete entries are skipped.
    public static func arp(_ output: String) -> [(ip: String, mac: String)] {
        output.split(separator: "\n").compactMap { line in
            guard let open = line.firstIndex(of: "("), let close = line.firstIndex(of: ")"),
                  let at = line.range(of: " at ") else { return nil }
            let ip = String(line[line.index(after: open)..<close])
            let mac = line[at.upperBound...].split(separator: " ").first.map(String.init) ?? ""
            return mac.contains(":") ? (ip, mac) : nil
        }
    }

    /// `traceroute -n -q 1` lines -> (hop, address or nil, milliseconds or nil).
    public static func traceroute(_ output: String) -> [(hop: Int, address: String?, ms: Double?)] {
        output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard let first = parts.first, let hop = Int(first) else { return nil }
            if parts.count >= 3, parts[1] != "*", let ms = Double(parts[2]) { return (hop, String(parts[1]), ms) }
            return (hop, nil, nil)
        }
    }

    /// `ipconfig getpacket en0` -> lease seconds (lease_time is hex).
    public static func leaseSeconds(_ output: String) -> Int? {
        guard let line = output.split(separator: "\n").first(where: { $0.contains("lease_time") }),
              let hex = line.split(separator: " ").last?.replacingOccurrences(of: "0x", with: "") else { return nil }
        return Int(hex, radix: 16)
    }

    public struct SpeedResult: Equatable, Sendable, Codable {
        public var date: Date
        /// Megabits per second.
        public var download: Double
        public var upload: Double
        /// Round trips per minute under load (Apple's responsiveness).
        public var responsiveness: Double?
        public var idleLatency: Double?

        public init(date: Date, download: Double, upload: Double, responsiveness: Double?, idleLatency: Double?) {
            self.date = date
            self.download = download
            self.upload = upload
            self.responsiveness = responsiveness
            self.idleLatency = idleLatency
        }

        /// "High", "Medium", or "Low" responsiveness, Apple's own bands.
        public var responsivenessWord: String? {
            responsiveness.map { $0 >= 1000 ? "High" : $0 >= 200 ? "Medium" : "Low" }
        }
    }

    /// `networkQuality -c` JSON -> a result. Throughputs are bits per second.
    public static func speedTest(_ data: Data, date: Date = .now) -> SpeedResult? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let down = (json["dl_throughput"] as? NSNumber)?.doubleValue,
              let up = (json["ul_throughput"] as? NSNumber)?.doubleValue else { return nil }
        let rpm = (json["responsiveness"] as? NSNumber)?.doubleValue
        let idle = (json["base_rtt"] as? NSNumber)?.doubleValue
        return SpeedResult(date: date, download: down / 1e6, upload: up / 1e6, responsiveness: rpm, idleLatency: idle)
    }
}

/// A minimal DNS query for an A record, to time each DNS server (S-042).
public enum DNSQuery {
    public static func encode(name: String, id: UInt16) -> Data {
        var data = Data([UInt8(id >> 8), UInt8(id & 0xFF), 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        for label in name.split(separator: ".") {
            data.append(UInt8(label.utf8.count))
            data.append(contentsOf: label.utf8)
        }
        data.append(contentsOf: [0x00, 0x00, 0x01, 0x00, 0x01])
        return data
    }

    /// True when `response` answers query `id` without an error.
    public static func isAnswer(_ response: Data, id: UInt16) -> Bool {
        guard response.count >= 12 else { return false }
        let bytes = [UInt8](response.prefix(12))
        let responseID = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        let isResponse = bytes[2] & 0x80 != 0
        let rcode = bytes[3] & 0x0F
        let answers = UInt16(bytes[6]) << 8 | UInt16(bytes[7])
        return responseID == id && isResponse && rcode == 0 && answers > 0
    }
}

extension NetworkParse {
    /// `route -n get default` -> (gateway, interface).
    public static func defaultRoute(_ output: String) -> (gateway: String, interface: String)? {
        func value(_ key: String) -> String? {
            output.split(separator: "\n").first { $0.trimmingCharacters(in: .whitespaces).hasPrefix(key + ":") }
                .map { $0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces) }
        }
        guard let gateway = value("gateway"), let interface = value("interface") else { return nil }
        return (gateway, interface)
    }

    /// `scutil --dns` -> unique nameservers, in order.
    public static func dnsServers(_ output: String) -> [String] {
        var seen: [String] = []
        for line in output.split(separator: "\n") where line.contains("nameserver[") {
            if let server = line.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces),
               !seen.contains(server) {
                seen.append(server)
            }
        }
        return seen
    }

    /// True for addresses that stay inside a home or carrier network (RFC 1918, CGNAT, link-local).
    public static func isPrivate(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return ip.hasPrefix("fe80") || ip.hasPrefix("fd") || ip.hasPrefix("fc") }
        switch (parts[0], parts[1]) {
        case (10, _), (127, _), (192, 168), (169, 254): return true
        case (172, 16...31): return true
        case (100, 64...127): return true
        default: return false
        }
    }

    /// The ISP's first hop: the first public address after the router.
    public static func ispHop(_ hops: [(hop: Int, address: String?, ms: Double?)]) -> (address: String, ms: Double)? {
        for hop in hops {
            if let address = hop.address, let ms = hop.ms, !isPrivate(address) { return (address, ms) }
        }
        return nil
    }
}

extension NetworkParse {
    /// 224.0.0.0–239.255.255.255 and *.255 are not devices.
    public static func isMulticastOrBroadcast(_ ip: String) -> Bool {
        guard let first = ip.split(separator: ".").first.flatMap({ Int($0) }) else { return false }
        return (224...239).contains(first) || ip.hasSuffix(".255")
    }

    /// arp drops leading zeros ("6:67:61:8:2d:9"); show "06:67:61:08:2d:09".
    public static func paddedMAC(_ mac: String) -> String {
        mac.split(separator: ":").map { $0.count == 1 ? "0" + $0 : String($0) }.joined(separator: ":")
    }

    /// "TELLESCOM INDUSTRIA E COMERCIO" -> "Tellescom Industria E Comercio"; mixed case stays.
    public static func readableVendor(_ name: String) -> String {
        name == name.uppercased() && name.count > 4 ? name.capitalized : name
    }

    /// A Bonjour instance name as a device name: "66176FE637F3@Daniel's MacBook Pro" -> "Daniel's
    /// MacBook Pro"; pure IDs ("57a335…" hex, UUIDs) -> nil.
    public static func deviceName(fromService name: String) -> String? {
        var cleaned = name
        if let at = cleaned.firstIndex(of: "@") { cleaned = String(cleaned[cleaned.index(after: at)...]) }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        let hex = cleaned.filter { $0.isHexDigit || $0 == "-" }
        if cleaned.count >= 12 && hex.count == cleaned.count { return nil }
        return cleaned.isEmpty ? nil : cleaned
    }
}
