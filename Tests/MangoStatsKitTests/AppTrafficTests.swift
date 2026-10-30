import Foundation
import Testing
@testable import MangoStatsKit

@Test("nettop CSV parses, names with dots keep them")
func nettopParse() {
    let output = ",bytes_in,bytes_out,\napsd.558,3422210,1200325,\ncom.apple.WebKit.Networking.4321,500,20,\nbad line\n"
    let parsed = NetworkParse.nettop(output)
    #expect(parsed.counters.count == 2)
    #expect(parsed.counters[558]?.received == 3_422_210)
    #expect(parsed.names[4321] == "com.apple.WebKit.Networking")
}

@Test("Per-app rates group helpers and keep a session total")
func trafficRates() {
    var meter = TrafficMeter()
    let t0 = Date(timeIntervalSince1970: 1_000)
    let chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    let helper = "/Applications/Google Chrome.app/Contents/Frameworks/x/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper"
    let paths: [Int32: String] = [1: chrome, 2: helper, 3: "/usr/sbin/mDNSResponder"]
    let names: [Int32: String] = [1: "Google Chrome", 2: "Google Chrome H", 3: "mDNSResponder"]
    #expect(meter.update(counters: [1: (0, 0), 2: (0, 0), 3: (0, 0)], paths: paths, names: names, time: t0).isEmpty)
    let apps = meter.update(counters: [1: (2_000_000, 0), 2: (2_000_000, 400_000), 3: (1_000, 0)],
                            paths: paths, names: names, time: t0.addingTimeInterval(2))
    #expect(apps.first?.name == "Google Chrome")
    #expect(apps.first?.download == 2_000_000)
    #expect(apps.first?.upload == 200_000)
    #expect(apps.first?.sessionBytes == 4_400_000)
    #expect(apps.last?.name == "mDNSResponder")
    // A reused pid (counter went back) is skipped.
    let reset = meter.update(counters: [1: (10, 0), 2: (2_000_000, 400_000), 3: (1_000, 0)],
                             paths: paths, names: names, time: t0.addingTimeInterval(4))
    #expect(reset.isEmpty)
}

@Test("Heavy traffic needs 1 MB/s and 60 % of the total")
func heavyTraffic() {
    let big = AppTraffic(name: "Dropbox", bundlePath: nil, download: 0, upload: 4_200_000, sessionBytes: 0)
    let small = AppTraffic(name: "Safari", bundlePath: nil, download: 300_000, upload: 0, sessionBytes: 0)
    #expect(HeavyTraffic.leader([big, small])?.name == "Dropbox")
    #expect(HeavyTraffic.sentence(big, locale: Locale(identifier: "en_US")) == "Dropbox is uploading at 4.2 MB/s")
    #expect(HeavyTraffic.leader([small]) == nil)
    let even = AppTraffic(name: "Music", bundlePath: nil, download: 3_000_000, upload: 0, sessionBytes: 0)
    #expect(HeavyTraffic.leader([big, even]) == nil)
}
