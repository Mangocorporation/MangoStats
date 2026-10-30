import Foundation
import Testing
@testable import MangoStatsKit

@Test("CPU usage from tick deltas")
func cpuFraction() {
    let before = [CPUTicks(user: 100, system: 50, idle: 850, nice: 0), CPUTicks(user: 0, system: 0, idle: 1000, nice: 0)]
    let after = [CPUTicks(user: 160, system: 90, idle: 950, nice: 0), CPUTicks(user: 0, system: 0, idle: 1200, nice: 0)]
    // core 1: 100 busy of 200, core 2: 0 of 200 -> 25 %
    #expect(CPUUsage.fraction(previous: before, current: after) == 0.25)
    #expect(CPUUsage.fraction(previous: [], current: after) == 0)
    #expect(CPUUsage.fraction(previous: after, current: before) == 0)
}

@Test("Load labels", arguments: [(0.1, "idle"), (0.2, "normal"), (0.6, "normal"), (0.61, "busy")])
func loadLabel(_ value: Double, _ expected: String) {
    #expect(CPUUsage.label(value) == expected)
}

@Test("History keeps the last 60 samples")
func history() {
    var history = History()
    for value in 0..<70 { history.append(Double(value)) }
    #expect(history.values.count == 60)
    #expect(history.values.first == 10)
    #expect(history.values.last == 69)
}

@Test("Memory pressure levels")
func pressure() {
    #expect(MemoryPressure(level: 1) == .normal)
    #expect(MemoryPressure(level: 2).title == "Warning")
    #expect(MemoryPressure(level: 4).title == "Critical")
    #expect(MemoryPressure(level: 0) == .normal)
}

@Test("Latency labels")
func latency() {
    #expect(Latency.label(milliseconds: 20) == "Low Lag")
    #expect(Latency.label(milliseconds: 100) == "Medium Lag")
    #expect(Latency.label(milliseconds: 300) == "High Lag")
    #expect(Latency.label(milliseconds: nil) == "Offline")
}

@Test("Byte values follow the locale")
func bytes() {
    let gib: Int64 = 1 << 30
    #expect(Format.bytes(gib * 2025 / 100, digits: 2, locale: Locale(identifier: "pt_BR")) == "20,25 GB")
    #expect(Format.bytes(gib * 2025 / 100, digits: 2, locale: Locale(identifier: "en_US")) == "20.25 GB")
    #expect(Format.bytes(887 << 20, locale: Locale(identifier: "en_US")) == "887 MB")
    #expect(Format.bytes(99_000_000_000, binary: false, digits: 0, locale: Locale(identifier: "en_US")) == "99 GB")
}

@Test("Speeds under 1 KB/s show <1")
func speed() {
    #expect(Format.speed(500).value == "<1")
    #expect(Format.speed(4_200, locale: Locale(identifier: "en_US")) == ("4", "KB/s"))
    #expect(Format.speed(1_260_000, locale: Locale(identifier: "en_US")) == ("1.3", "MB/s"))
}

@Test("Uptime reads like the reference")
func uptime() {
    #expect(Format.uptime(51 * 86_400 + 10 * 3_600 + 120) == "up 51 days, 10 hrs")
    #expect(Format.uptime(3 * 3_600 + 5 * 60) == "up 3 hrs, 5 mins")
    #expect(Format.uptime(60) == "up 1 min")
}

@Test("Network rate ignores counter resets")
func rate() {
    #expect(Rate.perSecond(previous: 1_000, current: 5_000, seconds: 2) == 2_000)
    #expect(Rate.perSecond(previous: 5_000, current: 1_000, seconds: 2) == 0)
}

@Test("Battery health is capped at 100")
func batteryHealth() {
    #expect(Battery.health(maxCapacity: 4_500, designCapacity: 5_000) == 90)
    #expect(Battery.health(maxCapacity: 5_200, designCapacity: 5_000) == 100)
    #expect(Battery.health(maxCapacity: 1, designCapacity: 0) == 0)
}

private func input(pressure: MemoryPressure = .normal, free: Double = 0.5, swap: Int64 = 0,
                   temperature: Double? = nil, cpu: Double = 0.1) -> Health.Input {
    Health.Input(pressure: pressure, diskFreeFraction: free, diskFreeBytes: 99_000_000_000, swapBytes: swap,
                 cpuTemperature: temperature, sustainedCPU: cpu)
}

@Test("Health rules")
func health() {
    #expect(Health(input()).score == 100)
    #expect(Health(input()).word == "Good")
    #expect(Health(input(pressure: .warning)).score == 85)
    #expect(Health(input(pressure: .critical)).score == 70)
    #expect(Health(input(free: 0.05)).score == 80)
    #expect(Health(input(temperature: 95)).score == 85)
    #expect(Health(input(cpu: 0.9)).score == 90)
    // The reference: 20 % free and 6.6 GB swap -> 84 Good, "Disk space low · 99 GB Free".
    let reference = Health(input(free: 0.2, swap: 7 << 30), locale: Locale(identifier: "en_US"))
    #expect(reference.score == 84)
    #expect(reference.reasons.first == "Disk space low · 99 GB free")
    #expect(Health(input(pressure: .critical, free: 0.05, temperature: 99, cpu: 0.95)).word == "Poor")
}

@Test("Processes group by app and sort by memory")
func grouping() {
    let samples = [
        ProcessSample(pid: 10, path: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
                      memory: 1_000, cpu: 5, power: 1),
        ProcessSample(pid: 11, path: "/Applications/Google Chrome.app/Contents/Frameworks/X.framework/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper",
                      memory: 3_000, cpu: 10, power: nil),
        ProcessSample(pid: 2, path: "/usr/sbin/mds", memory: 2_000, cpu: 0, power: nil),
        ProcessSample(pid: 3, path: "/usr/sbin/mds", memory: 2_000, cpu: 0, power: nil),
    ]
    let groups = ProcessGrouping.group(samples)
    #expect(groups.count == 3)
    #expect(groups[0].name == "Google Chrome")
    #expect(groups[0].pid == 10)
    #expect(groups[0].memory == 4_000)
    #expect(groups[0].cpu == 15)
    #expect(groups[0].bundlePath == "/Applications/Google Chrome.app")
    #expect(groups[1].pid == 2)
    #expect(groups[2].pid == 3)
}

@Test("ps output parses")
func parsePS() {
    let output = "  589 1153024  47,7 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer\n  1 2048 0.0 /sbin/launchd\nbad line\n"
    let samples = ProcessGrouping.parsePS(output)
    #expect(samples.count == 2)
    #expect(samples[0].pid == 589)
    #expect(samples[0].memory == 1_153_024 * 1024)
    #expect(samples[0].cpu == 47.7)
    #expect(ProcessGrouping.name(of: samples[0].path) == "WindowServer")
}

@Test("Rows keep their order when memory barely changes")
func stableOrder() {
    func group(_ pid: Int32, _ memory: Int64) -> ProcessGroup {
        ProcessGroup(name: "\(pid)", bundlePath: nil, pid: pid, memory: memory, cpu: 0, power: nil, count: 1)
    }
    // 1 was first; now 2 is 1 % larger: 1 stays first.
    let close = ProcessGrouping.stableOrder([group(2, 1_010_000_000), group(1, 1_000_000_000)], previous: [1, 2])
    #expect(close.map(\.pid) == [1, 2])
    // 2 is now twice as large: it moves up.
    let far = ProcessGrouping.stableOrder([group(2, 2_000_000_000), group(1, 1_000_000_000)], previous: [1, 2])
    #expect(far.map(\.pid) == [2, 1])
}

private func row(_ pid: Int32, _ name: String, memory: Int64, cpu: Double, watts: Double?) -> ProcessRowData {
    ProcessRowData(id: pid, name: name, memory: "", cpu: cpu, cpuText: "", power: "", memoryBytes: memory, watts: watts)
}

@Test("Clicking a header sorts by it; clicking again flips")
func sortSelect() {
    var sort = ProcessSort.default
    sort.select(.cpu)
    #expect(sort == ProcessSort(column: .cpu, descending: true))
    sort.select(.cpu)
    #expect(sort.descending == false)
    sort.select(.name)
    #expect(sort == ProcessSort(column: .name, descending: false))
}

@Test("Sort by every column, both ways")
func sortColumns() {
    let rows = [row(3, "safari", memory: 100, cpu: 5, watts: nil),
                row(1, "Code", memory: 300, cpu: 1, watts: 0.5),
                row(2, "Finder", memory: 200, cpu: 9, watts: 2)]
    func ids(_ column: ProcessColumn, _ descending: Bool) -> [Int32] {
        ProcessTable.sort(rows, by: ProcessSort(column: column, descending: descending)).map(\.id)
    }
    #expect(ids(.name, false) == [1, 2, 3])
    #expect(ids(.name, true) == [3, 2, 1])
    #expect(ids(.memory, false) == [3, 2, 1])
    #expect(ids(.cpu, true) == [2, 3, 1])
    #expect(ids(.power, true) == [2, 1, 3])
    #expect(ids(.pid, false) == [1, 2, 3])
    // The default keeps the sampler's stable order untouched.
    #expect(ProcessTable.sort(rows, by: .default).map(\.id) == [3, 1, 2])
}

@Test("Search matches names in any case, or an exact PID")
func search() {
    let rows = [row(589, "WindowServer", memory: 0, cpu: 0, watts: nil),
                row(1589, "Safari", memory: 0, cpu: 0, watts: nil)]
    #expect(ProcessTable.filter(rows, query: "window").map(\.id) == [589])
    #expect(ProcessTable.filter(rows, query: "589").map(\.id) == [589])
    #expect(ProcessTable.filter(rows, query: "  ").count == 2)
    #expect(ProcessTable.filter(rows, query: "zzz").isEmpty)
}

@Test("Apps and background processes")
func processKinds() {
    let app = ProcessRowData(id: 1, name: "Safari", memory: "", cpu: 0, cpuText: "", power: "", bundlePath: "/Applications/Safari.app")
    let daemon = ProcessRowData(id: 2, name: "mds", memory: "", cpu: 0, cpuText: "", power: "")
    #expect(ProcessKind.apps.includes(app) && !ProcessKind.apps.includes(daemon))
    #expect(ProcessKind.background.includes(daemon) && !ProcessKind.background.includes(app))
    #expect(ProcessKind.all.includes(app) && ProcessKind.all.includes(daemon))
}
