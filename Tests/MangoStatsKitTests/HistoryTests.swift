import Foundation
import Testing
@testable import MangoStatsKit

private let t0 = Date(timeIntervalSince1970: 1_800_000_000) // a whole minute

@Test("Samples average into one row per minute")
func minuteAverage() {
    var aggregator = MinuteAggregator()
    #expect(aggregator.add(MinuteSample(time: t0, cpu: 0.2, memory: 0.5, gpu: nil, cpuTemperature: 40)) == nil)
    #expect(aggregator.add(MinuteSample(time: t0.addingTimeInterval(30), cpu: 0.4, memory: 0.7, gpu: 0.5,
                                        cpuTemperature: 50)) == nil)
    let minute = aggregator.add(MinuteSample(time: t0.addingTimeInterval(61), cpu: 1, memory: 1))
    #expect(minute?.time == t0)
    #expect(abs((minute?.cpu ?? 0) - 0.3) < 1e-9)
    #expect(abs((minute?.memory ?? 0) - 0.6) < 1e-9)
    // GPU was read once: its mean is that one value, not halved by the missing one.
    #expect(minute?.gpu == 0.5)
    #expect(minute?.cpuTemperature == 45)
    #expect(minute?.battery == nil)
}

@Test("Ranges downsample into buckets and skip empty ones")
func downsample() {
    let now = t0.addingTimeInterval(86_400)
    // One sample per minute for the last 2 hours, then a 3-hour gap, then 1 hour.
    var minutes: [MinuteSample] = []
    for m in 0..<60 { minutes.append(MinuteSample(time: now.addingTimeInterval(-Double(m + 1) * 60), cpu: 0.1, memory: 0.5)) }
    for m in 240..<360 { minutes.append(MinuteSample(time: now.addingTimeInterval(-Double(m) * 60), cpu: 0.3, memory: 0.5)) }
    minutes.append(MinuteSample(time: now.addingTimeInterval(-2 * 86_400), cpu: 0.9, memory: 0.9)) // outside a day
    #expect(HistoryRange.hour.downsample(minutes, now: now).count == 60)
    let day = HistoryRange.day.downsample(minutes, now: now)
    #expect(day.count <= 6 + 12 + 1)
    #expect(day.allSatisfy { $0.cpu < 0.9 })
    #expect(day.first!.time < day.last!.time)
    #expect(HistoryRange.month.duration / HistoryRange.month.bucket <= 180)
}

@Test("Retention cutoff")
func retention() {
    #expect(HistoryRetention.cutoff(days: 7, now: t0) == t0.addingTimeInterval(-7 * 86_400))
    #expect(HistoryRetention.choices.contains(HistoryRetention.defaultDays))
}
