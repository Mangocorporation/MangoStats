import Foundation
import Testing
@testable import MangoStatsKit

private let gib: Int64 = 1 << 30
private let start = Date(timeIntervalSince1970: 1_000_000)
private let system = SystemInfo(chip: "M5", memory: 24 * gib, macOS: "macOS 26.6.2",
                                boot: start.addingTimeInterval(-(51 * 86_400 + 10 * 3_600)))

/// A reading `seconds` after start, with CPU ticks that make `busy` percent load since the last one.
private func reading(at seconds: Double, busyTicks: UInt64 = 0, idleTicks: UInt64 = 0,
                     received: UInt64 = 0, sent: UInt64 = 0,
                     battery: BatteryReading? = nil, processes: [ProcessSample]? = nil,
                     sensors: SensorReading = SensorReading()) -> Reading {
    Reading(ticks: [CPUTicks(user: busyTicks, system: 0, idle: idleTicks, nice: 0)],
            memory: MemoryReading(total: 24 * gib, used: 18 * gib, swap: 0, pressure: .normal),
            disk: DiskReading(total: 500_000_000_000, free: 100_000_000_000),
            network: NetworkCounters(received: received, sent: sent),
            battery: battery, processes: processes, sensors: sensors, time: start.addingTimeInterval(seconds))
}

@Test("First reading shows -- for CPU, then a value")
func firstReading() {
    var builder = StatusBuilder(system: system)
    let first = builder.update(reading(at: 0), network: NetworkContext(), previous: .placeholder)
    #expect(first.status.cpu == "--")
    #expect(first.menuValues[.cpu] == "--")
    #expect(first.status.memory == "75")
    #expect(first.menuValues[.memory] == "75%")
    #expect(first.status.uptime == "up 51 days, 10 hrs")
    #expect(first.status.chip == "M5")

    let second = builder.update(reading(at: 2, busyTicks: 15, idleTicks: 85), network: NetworkContext(),
                                previous: first.status)
    #expect(second.status.cpu == "15")
    #expect(second.status.cpuFooter == "idle")
    #expect(second.menuValues[.cpu] == "15%")
    #expect(second.status.cpuHistory == [0.15])
}

@Test("Disk and health use decimal GB like Finder")
func diskAndHealth() {
    var builder = StatusBuilder(system: system)
    let update = builder.update(reading(at: 0), network: NetworkContext(), previous: .placeholder)
    #expect(update.status.diskFree == "100")
    #expect(update.status.diskFreeUnit == "GB")
    #expect(update.status.diskUsed == 0.8)
    #expect(update.status.health == "90")
    #expect(update.status.healthWord == "Good")
    #expect(update.status.healthReason.hasPrefix("Disk space low"))
}

@Test("Network speed from counters, and a counter reset reads 0, not a huge number")
func networkSpeed() {
    var builder = StatusBuilder(system: system)
    let wifi = NetworkContext(interface: "Wi-Fi", online: true, latency: 20)
    var status = builder.update(reading(at: 0, received: 10_000), network: wifi, previous: .placeholder).status
    status = builder.update(reading(at: 2, received: 18_000, sent: 500), network: wifi, previous: status).status
    #expect(status.network == "4")
    #expect(status.networkUnit == "KB/s")
    #expect(status.networkUpload == "Upload <1 KB/s")
    #expect(status.networkUploadShort == "↑ <1 KB/s")
    #expect(status.networkInterface == "Wi-Fi")
    #expect(status.networkLatency == "Low Lag")
    status = builder.update(reading(at: 4, received: 100), network: wifi, previous: status).status
    #expect(status.network == "<1")
}

@Test("Offline shows -- and Offline")
func offline() {
    var builder = StatusBuilder(system: system)
    let off = NetworkContext(interface: "Wi-Fi", online: false, latency: nil)
    var status = builder.update(reading(at: 0), network: off, previous: .placeholder).status
    status = builder.update(reading(at: 2), network: off, previous: status).status
    #expect(status.network == "--")
    #expect(status.networkInterface == "Offline")
    #expect(status.networkLatency == "Offline")
}

@Test("Battery states")
func batteryStates() {
    var builder = StatusBuilder(system: system)
    func state(_ battery: BatteryReading?) -> StatusUpdate {
        builder.update(reading(at: 0, battery: battery), network: NetworkContext(), previous: .placeholder)
    }
    let charged = state(BatteryReading(percent: 100, health: 99, charging: false, pluggedIn: true, charged: true,
                                       adapterWatts: 65, minutesLeft: nil))
    #expect(charged.status.batteryState == "Charged")
    #expect(charged.status.batteryWatts == "65W")
    #expect(charged.status.batteryHealth == "99% Health")
    #expect(charged.menuValues[.battery] == "100%")

    let charging = state(BatteryReading(percent: 40, health: 99, charging: true, pluggedIn: true, charged: false,
                                        adapterWatts: 96, minutesLeft: 45))
    #expect(charging.status.batteryState == "Charging · 45 min to full")

    let onBattery = state(BatteryReading(percent: 60, health: 90, charging: false, pluggedIn: false, charged: false,
                                         adapterWatts: nil, minutesLeft: 200))
    #expect(onBattery.status.batteryState == "On Battery · 3 h 20 min left")
    #expect(onBattery.status.batteryWatts == nil)

    let desktop = state(nil)
    #expect(desktop.status.hasBattery == false)
    #expect(desktop.status.batteryState == "No battery")
    #expect(desktop.menuValues[.battery] == "--")
}

@Test("Processes become rows grouped by app; without a reading the rows stay")
func processRows() {
    var builder = StatusBuilder(system: system)
    let samples = [
        ProcessSample(pid: 10, path: "/Applications/Safari.app/Contents/MacOS/Safari", memory: gib, cpu: 30, power: 2,
                      owned: true),
        ProcessSample(pid: 589, path: "/System/Library/WindowServer", memory: gib / 2, cpu: 5, power: nil),
    ]
    let update = builder.update(reading(at: 0, processes: samples), network: NetworkContext(), previous: .placeholder)
    #expect(update.status.processCount == 2)
    #expect(update.status.processes.map(\.name) == ["Safari", "WindowServer"])
    #expect(update.status.processes[0].hot)
    #expect(update.status.processes[0].bundlePath == "/Applications/Safari.app")
    #expect(update.status.processes[1].power == "--")
    #expect(update.status.processes[0].ownedByUser)
    #expect(!update.status.processes[1].ownedByUser)
    #expect(update.status.batteryDrain == "Top drain now Safari")

    let closed = builder.update(reading(at: 2), network: NetworkContext(), previous: update.status)
    #expect(closed.status.processes.count == 2)
}

@Test("Sensors fill GPU, temperatures, watts, and fan")
func sensors() {
    var builder = StatusBuilder(system: system)
    let sensors = SensorReading(gpu: 0.53, cpuTemperature: 45.4, gpuTemperature: 41.6, cpuWatts: 0.92,
                                gpuWatts: 12.3, fans: [FanReading(rpm: 1_310, max: 6_550)])
    var update = builder.update(reading(at: 0, sensors: sensors), network: NetworkContext(), previous: .placeholder)
    update = builder.update(reading(at: 2, busyTicks: 5, idleTicks: 95, sensors: sensors), network: NetworkContext(),
                            previous: update.status)
    let status = update.status
    #expect(status.gpu == "53")
    #expect(status.gpuHistory == [0.53, 0.53])
    #expect(status.cpuTemp == "45°C")
    #expect(status.gpuTemp == "42°C")
    #expect(status.cpuFooter == "idle · \(Format.watts(0.92))")
    #expect(status.gpuFooter == "normal · 12W")
    #expect(status.fanRPM == "1310")
    #expect(status.fanSpeed == "Speed 20%")
    #expect(update.menuValues[.gpu] == "53%")
    #expect(update.menuValues[.temperature] == "45°C")
    #expect(update.menuValues[.fan] == "1310 RPM")
    #expect(status.hasGPU && status.hasTemperature && status.hasFan)
}

@Test("Without sensors: pills hidden, no fan, menu shows --")
func noSensors() {
    var builder = StatusBuilder(system: system)
    let update = builder.update(reading(at: 0), network: NetworkContext(), previous: .placeholder)
    #expect(update.status.cpuTemp == nil)
    #expect(update.status.gpu == "--")
    #expect(update.status.fanSpeed == "No fan")
    #expect(update.status.fanNote == "This Mac has no fan")
    #expect(!update.status.hasGPU && !update.status.hasTemperature && !update.status.hasFan)
    #expect(update.menuValues[.fan] == "--")
}

@Test("A hot CPU lowers health")
func hotCPU() {
    var builder = StatusBuilder(system: system)
    let update = builder.update(reading(at: 0, sensors: SensorReading(cpuTemperature: 96)),
                                network: NetworkContext(), previous: .placeholder)
    #expect(update.status.healthReasons.contains("CPU hot"))
}

@Test("Camera, mic, and sleep words")
func privacyRow() {
    var builder = StatusBuilder(system: system)
    func update(_ privacy: PrivacyReading) -> StatusData {
        var r = reading(at: 0)
        r.privacy = privacy
        return builder.update(r, network: NetworkContext(), previous: .placeholder).status
    }
    let idle = update(PrivacyReading())
    #expect(idle.privacyText == "Not in use")
    #expect(!idle.privacyActive)
    #expect(idle.awakeText == "Can sleep")
    #expect(idle.screenText == "Screen can sleep")
    #expect(update(PrivacyReading(cameraInUse: true)).privacyText == "Camera in use")
    #expect(update(PrivacyReading(micInUse: true)).privacyText == "Mic in use")
    let busy = update(PrivacyReading(cameraInUse: true, micInUse: true, keepingAwake: ["Zoom", "Safari", "Zoom"],
                                     keepingScreenOn: ["Zoom"]))
    #expect(busy.privacyText == "Camera and mic in use")
    #expect(busy.privacyActive)
    #expect(busy.awakeText == "Awake")
    #expect(busy.awakeHelp == "Keeping the Mac awake: Safari, Zoom")
    #expect(busy.screenText == "Screen on")
}

@Test("Processes are read at most every 2 seconds")
func processSchedule() {
    let now = Date(timeIntervalSince1970: 100)
    #expect(SampleSchedule.readProcesses(now: now, last: nil))
    #expect(!SampleSchedule.readProcesses(now: now, last: now.addingTimeInterval(-1)))
    #expect(SampleSchedule.readProcesses(now: now, last: now.addingTimeInterval(-2)))
}

@Test("Each reading after the first gives a history point")
func historyPoint() {
    var builder = StatusBuilder(system: system)
    let first = builder.update(reading(at: 0), network: NetworkContext(), previous: .placeholder)
    #expect(first.point == nil)
    let second = builder.update(reading(at: 2, busyTicks: 25, idleTicks: 75, received: 4_000,
                                        sensors: SensorReading(gpu: 0.4, cpuTemperature: 50)),
                                network: NetworkContext(), previous: first.status)
    #expect(second.point?.cpu == 0.25)
    #expect(second.point?.memory == 0.75)
    #expect(second.point?.gpu == 0.4)
    #expect(second.point?.download == 2_000)
    #expect(second.point?.battery == nil)
}

@Test("Battery details and disk activity")
func batteryAndDisk() {
    var builder = StatusBuilder(system: system)
    let battery = BatteryReading(percent: 81, health: 100, charging: true, pluggedIn: true, charged: false,
                                 adapterWatts: 65, minutesLeft: 60, cycleCount: 55, designCycles: 1000,
                                 maxCapacity: 6305, designCapacity: 6249, voltage: 12.856, amperage: 2.691,
                                 temperature: 30.51, adapterName: "67W USB-C Power Adapter")
    var first = reading(at: 0, battery: battery)
    first.disk = DiskReading(total: 500_000_000_000, free: 100_000_000_000, readBytes: 1_000_000, writtenBytes: 500_000)
    let a = builder.update(first, network: NetworkContext(), previous: .placeholder).status
    #expect(a.batteryCycles.hasPrefix("55 of 1"))
    #expect(a.batteryCapacity.contains("mAh"))
    #expect(a.batteryPower.hasPrefix("Charging at 35"))
    #expect(a.batteryAdapter == "67W USB-C Power Adapter · 65 W")
    #expect(a.batteryCondition == "Normal")
    #expect(a.diskRead == "--")
    var second = reading(at: 2, battery: battery)
    second.disk = DiskReading(total: 500_000_000_000, free: 100_000_000_000, readBytes: 9_000_000, writtenBytes: 500_000)
    let b = builder.update(second, network: NetworkContext(), previous: a).status
    #expect(b.diskReadHistory == [4_000_000])
    #expect(b.diskWrite == "<1 KB/s")
}
