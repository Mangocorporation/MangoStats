import Foundation
import Testing
@testable import MangoStatsKit

@Test("Cool is 60 % of the range, Max is the top, Auto has no target")
func fanTargets() {
    #expect(FanPolicy.target(.auto, min: 2_317, max: 6_550) == nil)
    #expect(FanPolicy.target(.cool, min: 2_317, max: 6_550) == 4_857)
    #expect(FanPolicy.target(.max, min: 2_317, max: 6_550) == 6_550)
    #expect(FanPolicy.target(.cool, min: 0, max: 0) == nil)
}

@Test("No ping for 15 s, or none at all, means Auto")
func fanTimeout() {
    let now = Date(timeIntervalSince1970: 1_000)
    #expect(FanPolicy.effective(requested: .max, lastPing: nil, now: now, cpuTemperature: 50, boosted: false).mode == .auto)
    #expect(FanPolicy.effective(requested: .max, lastPing: now.addingTimeInterval(-16), now: now,
                                cpuTemperature: 50, boosted: false).mode == .auto)
    #expect(FanPolicy.effective(requested: .max, lastPing: now.addingTimeInterval(-2), now: now,
                                cpuTemperature: 50, boosted: false).mode == .max)
}

@Test("A hot CPU raises Cool to Max until it cools below 80 °C")
func fanHotOverride() {
    let now = Date(timeIntervalSince1970: 1_000)
    let ping = now.addingTimeInterval(-1)
    func step(_ temperature: Double, _ boosted: Bool) -> (FanMode, Bool) {
        let result = FanPolicy.effective(requested: .cool, lastPing: ping, now: now, cpuTemperature: temperature,
                                         boosted: boosted)
        return (result.mode, result.boosted)
    }
    #expect(step(70, false) == (.cool, false))
    #expect(step(91, false) == (.max, true))
    #expect(step(85, true) == (.max, true))
    #expect(step(79, true) == (.cool, false))
}

@Test("Fan notes")
func fanNotes() {
    let en = Locale(identifier: "en_US")
    #expect(FanPolicy.note(.auto, min: 2_317, max: 6_550, locale: en) == "Managed by macOS")
    #expect(FanPolicy.note(.cool, min: 2_317, max: 6_550, locale: en) == "Cool · 4,857 RPM target")
    #expect(FanPolicy.note(.max, min: 2_317, max: 6_550, locale: en) == "Max · 6,550 RPM target")
}
