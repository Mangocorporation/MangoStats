import Foundation
import Testing
@testable import MangoStatsKit

private let gib: Int64 = 1 << 30
private let en = Locale(identifier: "en_US")

@Test("Calm when nothing is worth a look")
func calmInsight() {
    #expect(Insight.all(Insight.Input(memoryFraction: 0.5, swap: 0, pressure: .normal), locale: en).isEmpty)
    #expect(Insight.calm.isCalm)
}

@Test("Tight memory names the app holding the most")
func memoryInsight() {
    let input = Insight.Input(memoryFraction: 0.86, swap: Int64(5.32 * Double(gib)), pressure: .normal,
                              topMemory: ("Google Chrome", Int64(19.4 * Double(gib))))
    let insight = Insight.all(input, locale: en).first
    #expect(insight?.eyebrow == "Memory is tight")
    #expect(insight?.title == "Google Chrome is holding 19.4 GB")
    #expect(insight?.body.hasPrefix("Memory is 86% full and macOS has moved 5.32 GB to swap.") == true)
    #expect(insight?.app == "Google Chrome")
}

@Test("Issues come most urgent first, and each is found")
func insightOrder() {
    let input = Insight.Input(memoryFraction: 0.9, swap: 0, pressure: .warning, diskFree: 20_000_000_000,
                              diskTotal: 500_000_000_000, cpuTemperature: 95, topCPU: ("Xcode", 120),
                              battery: (15, true))
    let kinds = Insight.all(input, locale: en).map(\.kind)
    #expect(kinds == [.memory, .hot, .busyApp, .disk, .battery])
}
