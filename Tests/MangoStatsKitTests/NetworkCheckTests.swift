import Foundation
import Testing
@testable import MangoStatsKit

private func stats(_ values: [Double?]) -> LatencyStats { LatencyStats(samples: values) }

@Test("Latency stats: average, jitter, loss")
func latencyStats() {
    let s = stats([10, 12, nil, 14, 10])
    #expect(s.average == 11.5)
    #expect(abs((s.jitter ?? 0) - 8.0 / 3.0) < 1e-9)
    #expect(s.loss == 0.2)
    var rolling = LatencyStats()
    for i in 0..<40 { rolling.add(Double(i)) }
    #expect(rolling.samples.count == 30)
}

@Test("The verdict blames the first bad step")
func verdicts() {
    let fast = stats([5, 5, 6, 5])
    let web = stats([18, 17, 20, 16])
    #expect(NetworkVerdict(.init(wifiSNR: 30, wifiRate: 400, router: fast, ispHop: 11, internet: web)).title == "All good")
    let weak = NetworkVerdict(.init(wifiSNR: 18, wifiRate: 130, router: fast, ispHop: 11, internet: web))
    #expect(weak.culprit == .wifi)
    #expect(weak.title == "Your Wi-Fi is the weak link")
    let lossy = NetworkVerdict(.init(wifiSNR: 30, router: stats([5, nil, 5, 5, 5, 5, 5, 5, 5, 5]), internet: web))
    #expect(lossy.culprit == .router)
    #expect(lossy.title == "Your router is dropping packets")
    // 24 ms over Wi-Fi is normal radio latency; over Ethernet it's slow.
    let wifiRouter = stats([24, 25, 23, 24])
    #expect(NetworkVerdict(.init(wifiSNR: 30, router: wifiRouter, ispHop: 29, internet: web)).title == "All good")
    let wiredSlow = NetworkVerdict(.init(wired: true, router: wifiRouter, ispHop: 29, internet: web))
    #expect(wiredSlow.title == "Your router is slow to answer")
    #expect(NetworkVerdict(.init(wifiSNR: 30, router: fast, ispHop: 80, internet: web)).culprit == .isp)
    #expect(NetworkVerdict(.init(wifiSNR: 30, router: fast, ispHop: 11, internet: stats([150, 160]))).culprit == .internet)
    let offline = NetworkVerdict(.init(wifiSNR: 30, router: stats([nil, nil]), internet: stats([nil])))
    #expect(offline.title == "Offline")
    #expect(NetworkVerdict(.init(wired: true, router: fast, internet: web)).health[.wifi] == .good)
}

@Test("Wi-Fi words")
func wifiWords() {
    #expect(WiFiWords.signal(snr: 22) == "Fair")
    #expect(WiFiWords.signal(snr: 45) == "Excellent")
    #expect(WiFiWords.standard(phyMode: 6) == "Wi-Fi 6")
    #expect(WiFiWords.band(2) == "5 GHz")
    #expect(WiFiWords.width(3) == "80 MHz")
}

@Test("Vendors from MAC prefixes; private addresses")
func vendors() {
    let directory = VendorDirectory(text: "F45420\tSagemcom Broadband SAS\nACDE48\tPrivate\n")
    #expect(directory.vendor(mac: "f4:54:20:55:4c:c0") == "Sagemcom Broadband SAS")
    #expect(directory.vendor(mac: "f4:54:20:5:4c:c0") == "Sagemcom Broadband SAS")
    #expect(directory.vendor(mac: "a2:11:22:33:44:55") == "Private address")
    #expect(directory.vendor(mac: "00:11:22:33:44:55") == nil)
}

@Test("Parsers for arp, traceroute, ipconfig, networkQuality")
func parsers() {
    let arp = NetworkParse.arp("? (192.168.15.1) at f4:54:20:55:4c:c0 on en0 ifscope [ethernet]\n? (192.168.15.9) at (incomplete) on en0 ifscope [ethernet]\n")
    #expect(arp.count == 1 && arp[0].ip == "192.168.15.1" && arp[0].mac == "f4:54:20:55:4c:c0")
    let hops = NetworkParse.traceroute("traceroute to 1.1.1.1\n 1  192.168.15.1  8.456 ms\n 2  *\n 3  201.1.232.100  11.724 ms\n")
    #expect(hops.count == 3 && hops[0].ms == 8.456 && hops[1].address == nil && hops[2].address == "201.1.232.100")
    #expect(NetworkParse.leaseSeconds("lease_time (uint32): 0x3840\n") == 14400)
    let json = Data(#"{"dl_throughput": 412000000, "ul_throughput": 38500000, "responsiveness": 1450.5, "base_rtt": 18.2}"#.utf8)
    let result = NetworkParse.speedTest(json)
    #expect(result?.download == 412 && result?.upload == 38.5 && result?.responsivenessWord == "High")
    #expect(NetworkParse.speedTest(Data("{}".utf8)) == nil)
}

@Test("DNS query encoding and answer check")
func dnsQuery() {
    let query = DNSQuery.encode(name: "apple.com", id: 0x1234)
    #expect(query.count == 12 + 1 + 5 + 1 + 3 + 1 + 4)
    var answer = Data([0x12, 0x34, 0x81, 0x80, 0x00, 0x01, 0x00, 0x01, 0, 0, 0, 0])
    #expect(DNSQuery.isAnswer(answer, id: 0x1234))
    answer[3] = 0x83   // NXDOMAIN
    #expect(!DNSQuery.isAnswer(answer, id: 0x1234))
}

@Test("Route, DNS servers, private addresses, ISP hop")
func routeAndDNS() {
    let route = NetworkParse.defaultRoute("   route to: default\n    gateway: 192.168.15.1\n  interface: en0\n")
    #expect(route?.gateway == "192.168.15.1" && route?.interface == "en0")
    let dns = NetworkParse.dnsServers("  nameserver[0] : fe80::f654%en0\n  nameserver[1] : 192.168.15.1\n  nameserver[0] : 192.168.15.1\n")
    #expect(dns == ["fe80::f654%en0", "192.168.15.1"])
    #expect(NetworkParse.isPrivate("192.168.15.1") && NetworkParse.isPrivate("100.70.1.1") && !NetworkParse.isPrivate("201.1.232.100"))
    let hops: [(hop: Int, address: String?, ms: Double?)] = [(1, "192.168.15.1", 8), (2, nil, nil), (3, "201.1.232.100", 11.7)]
    #expect(NetworkParse.ispHop(hops)?.address == "201.1.232.100")
}

@Test("Device names, MACs, vendors, multicast")
func deviceCleanup() {
    #expect(NetworkParse.deviceName(fromService: "66176FE637F3@Daniel’s MacBook Pro") == "Daniel’s MacBook Pro")
    #expect(NetworkParse.deviceName(fromService: "57a335228170b9a4f330042731153e60b86f5eee") == nil)
    #expect(NetworkParse.deviceName(fromService: "SpZc-311057") == "SpZc-311057")
    #expect(NetworkParse.paddedMAC("6:67:61:8:2d:9") == "06:67:61:08:2d:09")
    #expect(NetworkParse.readableVendor("TELLESCOM INDUSTRIA") == "Tellescom Industria")
    #expect(NetworkParse.readableVendor("Apple, Inc.") == "Apple, Inc.")
    #expect(NetworkParse.isMulticastOrBroadcast("239.255.255.250") && NetworkParse.isMulticastOrBroadcast("192.168.15.255"))
    #expect(!NetworkParse.isMulticastOrBroadcast("192.168.15.9"))
}
