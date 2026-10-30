import CoreWLAN
import Darwin
import Foundation
import MangoStatsKit

/// The Network tab's readers (S-039 to S-044). None need root: ICMP datagram
/// sockets for ping, and the system's own route, arp, traceroute, ipconfig,
/// scutil, and networkQuality tools.
nonisolated enum NetworkProbe {
    /// Round trip to an IPv4 address in milliseconds, or nil when lost.
    static func ping(_ address: String, timeout: TimeInterval = 1) -> Double? {
        var target = sockaddr_in()
        target.sin_family = sa_family_t(AF_INET)
        target.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        guard inet_pton(AF_INET, address, &target.sin_addr) == 1 else { return nil }
        // An ICMP datagram socket: macOS lets any user send echo requests on it.
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        var wait = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - floor(timeout)) * 1_000_000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &wait, socklen_t(MemoryLayout<timeval>.size))

        let identifier = UInt16.random(in: 1...UInt16.max)
        var packet: [UInt8] = [8, 0, 0, 0, UInt8(identifier >> 8), UInt8(identifier & 0xFF), 0, 1]
        packet += Array("MangoStats".utf8)
        let checksum = Self.checksum(packet)
        packet[2] = UInt8(checksum >> 8)
        packet[3] = UInt8(checksum & 0xFF)

        let start = DispatchTime.now().uptimeNanoseconds
        let sent = withUnsafePointer(to: &target) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(sock, packet, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard sent == packet.count else { return nil }
        var buffer = [UInt8](repeating: 0, count: 1024)
        let deadline = start + UInt64(timeout * 1e9)
        while DispatchTime.now().uptimeNanoseconds < deadline {
            // Every ICMP datagram socket can see every echo reply on the Mac, so keep only
            // replies from our target that carry our identifier (pings run in parallel).
            var from = sockaddr_in()
            var fromLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &from) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(sock, &buffer, buffer.count, 0, $0, &fromLength) }
            }
            guard count > 0 else { return nil }
            guard from.sin_addr.s_addr == target.sin_addr.s_addr else { continue }
            // The reply may start with the IP header (20 bytes) or with ICMP itself.
            let offset = buffer[0] >> 4 == 4 ? Int(buffer[0] & 0x0F) * 4 : 0
            guard count >= offset + 8 else { continue }
            let replyID = UInt16(buffer[offset + 4]) << 8 | UInt16(buffer[offset + 5])
            if buffer[offset] == 0 && replyID == identifier {   // our echo reply
                return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            }
        }
        return nil
    }

    private static func checksum(_ bytes: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var index = 0
        while index + 1 < bytes.count {
            sum += UInt32(bytes[index]) << 8 | UInt32(bytes[index + 1])
            index += 2
        }
        if index < bytes.count { sum += UInt32(bytes[index]) << 8 }
        while sum >> 16 != 0 { sum = (sum & 0xFFFF) + (sum >> 16) }
        return ~UInt16(sum)
    }

    /// Milliseconds for one DNS server to answer an A query, or nil.
    static func dnsTime(server: String, name: String = "apple.com", timeout: TimeInterval = 1.5) -> Double? {
        var hints = addrinfo(ai_flags: AI_NUMERICHOST, ai_family: AF_UNSPEC, ai_socktype: SOCK_DGRAM,
                             ai_protocol: IPPROTO_UDP, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(server, "53", &hints, &info) == 0, let address = info else { return nil }
        defer { freeaddrinfo(info) }
        let sock = socket(address.pointee.ai_family, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        var wait = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - floor(timeout)) * 1_000_000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &wait, socklen_t(MemoryLayout<timeval>.size))
        let id = UInt16.random(in: 1...UInt16.max)
        let query = [UInt8](DNSQuery.encode(name: name, id: id))
        let start = DispatchTime.now().uptimeNanoseconds
        guard sendto(sock, query, query.count, 0, address.pointee.ai_addr, address.pointee.ai_addrlen) == query.count
        else { return nil }
        var buffer = [UInt8](repeating: 0, count: 1500)
        let count = recv(sock, &buffer, buffer.count, 0)
        guard count > 0, DNSQuery.isAnswer(Data(buffer.prefix(count)), id: id) else { return nil }
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    /// Runs a system tool and returns what it printed, waiting at most `timeout`.
    static func run(_ path: String, _ arguments: [String], timeout: TimeInterval = 10) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return "" }
        let timer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timer.cancel()
        return String(decoding: data, as: UTF8.self)
    }

    /// Cumulative bytes per process from `nettop` (no root needed), with each pid's path.
    static func traffic() -> (counters: [Int32: (received: Int64, sent: Int64)], names: [Int32: String], paths: [Int32: String]) {
        let parsed = NetworkParse.nettop(run("/usr/bin/nettop", ["-P", "-L", "1", "-J", "bytes_in,bytes_out", "-x"], timeout: 5))
        var paths: [Int32: String] = [:]
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        for pid in parsed.counters.keys {
            let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
            if length > 0 { paths[pid] = String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self) }
        }
        return (parsed.counters, parsed.names, paths)
    }

    static func defaultRoute() -> (gateway: String, interface: String)? {
        NetworkParse.defaultRoute(run("/sbin/route", ["-n", "get", "default"], timeout: 3))
    }

    static func arp() -> [(ip: String, mac: String)] {
        NetworkParse.arp(run("/usr/sbin/arp", ["-an"], timeout: 5))
    }

    static func hops(to target: String = "1.1.1.1") -> [(hop: Int, address: String?, ms: Double?)] {
        NetworkParse.traceroute(run("/usr/sbin/traceroute", ["-n", "-q", "1", "-w", "1", "-m", "8", target], timeout: 15))
    }

    static func leaseSeconds(interface: String) -> Int? {
        NetworkParse.leaseSeconds(run("/usr/sbin/ipconfig", ["getpacket", interface], timeout: 3))
    }

    static func dnsServers() -> [String] {
        NetworkParse.dnsServers(run("/usr/sbin/scutil", ["--dns"], timeout: 3))
    }

    /// Wi-Fi details from CoreWLAN; the name needs Location permission.
    static func wifi() -> WiFiReading? {
        guard let interface = CWWiFiClient.shared().interface(), interface.powerOn() else { return nil }
        let rssi = interface.rssiValue()
        guard rssi != 0 else { return WiFiReading(interface: interface.interfaceName ?? "en0", connected: false) }
        let channel = interface.wlanChannel()
        return WiFiReading(interface: interface.interfaceName ?? "en0", connected: true, ssid: interface.ssid(),
                           rssi: Double(rssi), noise: Double(interface.noiseMeasurement()),
                           rate: interface.transmitRate(), channel: channel?.channelNumber ?? 0,
                           band: channel?.channelBand.rawValue ?? 0, width: channel?.channelWidth.rawValue ?? 0,
                           phyMode: interface.activePHYMode().rawValue, security: interface.security().rawValue)
    }

    /// Asks UPnP gateways to describe themselves (needs Local Network permission).
    static func upnpGateway(timeout: TimeInterval = 2.5) -> UPnPGateway? {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        var wait = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &wait, socklen_t(MemoryLayout<timeval>.size))
        var group = sockaddr_in()
        group.sin_family = sa_family_t(AF_INET)
        group.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        group.sin_port = UInt16(1900).bigEndian
        inet_pton(AF_INET, "239.255.255.250", &group.sin_addr)
        let message = Array(("M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\n"
            + "ST: urn:schemas-upnp-org:device:InternetGatewayDevice:1\r\n\r\n").utf8)
        _ = withUnsafePointer(to: &group) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(sock, message, message.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = recv(sock, &buffer, buffer.count, 0)
        guard count > 0 else { return nil }
        let text = String(decoding: buffer.prefix(count), as: UTF8.self)
        guard let line = text.split(separator: "\r\n").first(where: { $0.lowercased().hasPrefix("location:") }),
              let url = URL(string: line.dropFirst("location:".count).trimmingCharacters(in: .whitespaces)),
              let xml = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        func tag(_ name: String) -> String? {
            guard let open = xml.range(of: "<\(name)>"), let close = xml.range(of: "</\(name)>", range: open.upperBound..<xml.endIndex)
            else { return nil }
            return String(xml[open.upperBound..<close.lowerBound])
        }
        return UPnPGateway(manufacturer: tag("manufacturer"), model: tag("modelName") ?? tag("friendlyName"))
    }

    /// Apple's speed test (networkQuality -c prints JSON). Takes about 20 s.
    static func speedTest(process: Process) -> NetworkParse.SpeedResult? {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
        process.arguments = ["-c"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return NetworkParse.speedTest(data)
    }
}

nonisolated struct WiFiReading: Sendable, Equatable {
    var interface: String
    var connected: Bool
    var ssid: String?
    var rssi: Double = 0
    var noise: Double = 0
    var rate: Double = 0
    var channel: Int = 0
    var band: Int = 0
    var width: Int = 0
    var phyMode: Int = 0
    var security: Int = 0

    var snr: Double { rssi - noise }
}

nonisolated struct UPnPGateway: Sendable, Equatable {
    var manufacturer: String?
    var model: String?
}
