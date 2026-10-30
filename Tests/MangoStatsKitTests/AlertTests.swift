import Foundation
import Testing
@testable import MangoStatsKit

private let t0 = Date(timeIntervalSince1970: 2_000_000_000)
private var on: AlertSettings {
    var settings = AlertSettings()
    settings.showAlerts = true
    settings.enabled = Set(AlertKind.allCases)
    return settings
}

private func run(_ engine: inout AlertEngine, _ seconds: [Double], settings: AlertSettings = on,
                 _ make: (Date) -> AlertInput) -> [(Double, AlertEvent)] {
    seconds.flatMap { s in engine.evaluate(make(t0.addingTimeInterval(s)), settings: settings).map { (s, $0) } }
}

@Test("Nothing fires while alerts are off")
func alertsOff() {
    var engine = AlertEngine()
    #expect(engine.evaluate(AlertInput(time: t0, pressure: .critical), settings: AlertSettings()).isEmpty)
    #expect(AlertSettings().showAlerts == false)
}

@Test("Memory pressure fires at once, once per episode")
func memoryEpisode() {
    var engine = AlertEngine()
    let fired = run(&engine, [0, 2, 4]) { AlertInput(time: $0, pressure: .critical, topMemory: "Google Chrome") }
    #expect(fired.count == 1)
    #expect(fired[0].1.title == "Memory pressure is critical")
    #expect(fired[0].1.body.hasSuffix("Most memory: Google Chrome."))
    // Warning is inside the margin: no new episode.
    #expect(run(&engine, [10, 12]) { AlertInput(time: $0, pressure: $0 == t0.addingTimeInterval(10) ? .warning : .critical) }.isEmpty)
}

@Test("A hot CPU fires after a minute, then waits for the cooldown")
func hotCPUAlert() {
    var engine = AlertEngine()
    let hot = run(&engine, Array(stride(from: 0.0, through: 70, by: 2))) {
        AlertInput(time: $0, cpuTemperature: 93, topCPU: ("Xcode", 300))
    }
    #expect(hot.count == 1)
    #expect(hot[0].0 >= 60)
    #expect(hot[0].1.title == "CPU is hot: 93°C")
    #expect(hot[0].1.body == "Above 90°C for a minute. Top CPU: Xcode.")
    // Cools below 80 °C (clears), hot again 10 minutes later: still inside the 30-minute cooldown.
    _ = run(&engine, [100]) { AlertInput(time: $0, cpuTemperature: 70) }
    #expect(run(&engine, Array(stride(from: 600.0, through: 700, by: 2))) { AlertInput(time: $0, cpuTemperature: 95) }.isEmpty)
    // After the cooldown it fires again.
    #expect(run(&engine, Array(stride(from: 2_000.0, through: 2_100, by: 2))) { AlertInput(time: $0, cpuTemperature: 95) }.count == 1)
}

@Test("85 °C after an alert stays in the same episode")
func hysteresis() {
    var engine = AlertEngine()
    _ = run(&engine, Array(stride(from: 0.0, through: 62, by: 2))) { AlertInput(time: $0, cpuTemperature: 93) }
    // 85 °C is between 80 and 90: no clear, so returning to 93 later doesn't count as a new episode.
    _ = run(&engine, [100]) { AlertInput(time: $0, cpuTemperature: 85) }
    #expect(run(&engine, Array(stride(from: 2_000.0, through: 2_100, by: 2))) { AlertInput(time: $0, cpuTemperature: 93) }.isEmpty)
}

@Test("CPU busy needs 5 minutes and reports the average")
func cpuBusy() {
    var engine = AlertEngine()
    let fired = run(&engine, Array(stride(from: 0.0, through: 310, by: 2))) { AlertInput(time: $0, cpu: 0.95) }
    #expect(fired.count == 1)
    #expect(fired[0].0 >= 300)
    #expect(fired[0].1.body == "Average 95 %.")
}

@Test("Disk and battery")
func diskBattery() {
    var engine = AlertEngine()
    let disk = engine.evaluate(AlertInput(time: t0, diskFree: 8_000_000_000), settings: on)
    #expect(disk.map(\.title) == ["Disk space low: 8 GB free"])
    let plugged = engine.evaluate(AlertInput(time: t0, battery: (15, false, nil)), settings: on)
    #expect(plugged.isEmpty)
    let low = engine.evaluate(AlertInput(time: t0, battery: (18, true, 35)), settings: on)
    #expect(low.first?.title == "Battery at 18 %")
    #expect(low.first?.body == "About 35 min left. Connect power to keep working.")
}

@Test("A busy app fires after 5 minutes; a different app restarts the timer")
func busyApp() {
    var engine = AlertEngine()
    _ = run(&engine, Array(stride(from: 0.0, through: 200, by: 2))) { AlertInput(time: $0, topCPU: ("Chrome", 180)) }
    let switched = run(&engine, Array(stride(from: 202.0, through: 400, by: 2))) { AlertInput(time: $0, topCPU: ("Xcode", 150)) }
    #expect(switched.isEmpty)
    let fired = run(&engine, Array(stride(from: 402.0, through: 520, by: 2))) { AlertInput(time: $0, topCPU: ("Xcode", 150)) }
    #expect(fired.count == 1)
    #expect(fired[0].1.title == "Xcode is using 150 % CPU")
    #expect(fired[0].1.app == "Xcode")
}

@Test("Thresholds and settings round-trip; bad values fall back")
func settingsRoundTrip() {
    var settings = on
    settings.thresholds[.cpuHot] = 95
    settings.thresholds[.diskLow] = 7   // not a choice
    let loaded = AlertSettings.decode(settings.encoded)
    #expect(loaded == settings)
    #expect(loaded.threshold(.cpuHot) == 95)
    #expect(loaded.threshold(.diskLow) == 10)
    #expect(AlertSettings.decode(Data("junk".utf8)) == AlertSettings())
    var engine = AlertEngine()
    #expect(engine.evaluate(AlertInput(time: t0, cpuTemperature: 93), settings: loaded).isEmpty)
}
