import Foundation
import Network
import MangoStatsKit

/// One read of the system, made off the main thread.
nonisolated private struct Reading: Sendable {
    var ticks: [CPUTicks]
    var memory: MemoryReading
    var disk: DiskReading?
    var network: (received: UInt64, sent: UInt64)
    var battery: BatteryReading?
    var processes: [ProcessSample]?
    var time: Date
}

/// Reads the system every `interval` seconds and fills `AppModel.status`
/// and the menu bar values (S-001 to S-008).
@MainActor
final class Sampler {
    static let interval: Duration = .seconds(2)

    private weak var model: AppModel?
    private var task: Task<Void, Never>?
    private let processReader = ProcessReader()
    private let system = SystemInfo.read()
    private var lastTicks: [CPUTicks] = []
    private var lastNetwork: (received: UInt64, sent: UInt64, time: Date)?
    private var cpuHistory = History()
    private var memoryHistory = History()
    private var networkHistory = History()
    private var cpuMinute = History(capacity: 30)

    private let pathMonitor = NWPathMonitor()
    private var interface = "Network"
    private var online = true
    private var latency: Double?
    private var latencyTask: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        guard task == nil else { return }
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let name = path.usesInterfaceType(.wifi) ? "Wi-Fi"
                : path.usesInterfaceType(.wiredEthernet) ? "Ethernet"
                : path.usesInterfaceType(.cellular) ? "Cellular" : "Network"
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.interface = name
                self?.online = online
            }
        }
        pathMonitor.start(queue: .global(qos: .utility))
        latencyTask = Task { [weak self] in
            while !Task.isCancelled {
                let ms = await LatencyProbe.measure()
                self?.latency = ms
                try? await Task.sleep(for: .seconds(30))
            }
        }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sample()
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    func stop() {
        task?.cancel()
        latencyTask?.cancel()
        pathMonitor.cancel()
        task = nil
    }

    private func sample() async {
        guard let model else { return }
        let wantProcesses = model.detailVisible
        let reader = processReader
        let reading = await Task.detached(priority: .utility) {
            Reading(ticks: CPUReader.ticks(), memory: MemoryReader.read(), disk: DiskReader.read(),
                    network: NetworkReader.counters(), battery: BatteryReader.read(),
                    processes: wantProcesses ? reader.read() : nil, time: .now)
        }.value
        apply(reading, to: model)
    }

    private func apply(_ reading: Reading, to model: AppModel) {
        // CPU
        let first = lastTicks.isEmpty
        let cpu = CPUUsage.fraction(previous: lastTicks, current: reading.ticks)
        lastTicks = reading.ticks
        if !first {
            cpuHistory.append(cpu)
            cpuMinute.append(cpu)
        }
        // Memory
        let memory = reading.memory
        let memoryFraction = memory.total > 0 ? Double(memory.used) / Double(memory.total) : 0
        memoryHistory.append(memoryFraction)
        // Network
        var download = 0.0
        var upload = 0.0
        if let last = lastNetwork {
            let seconds = reading.time.timeIntervalSince(last.time)
            download = Rate.perSecond(previous: last.received, current: reading.network.received, seconds: seconds)
            upload = Rate.perSecond(previous: last.sent, current: reading.network.sent, seconds: seconds)
            networkHistory.append(download)
        }
        lastNetwork = (reading.network.received, reading.network.sent, reading.time)

        var status = model.status
        let percent = { (value: Double) in Format.number(value * 100, digits: 0) }

        status.chip = system.chip
        status.ram = Format.bytes(system.memory, digits: 0)
        status.macOS = system.macOS
        status.uptime = Format.uptime(reading.time.timeIntervalSince(system.boot))

        status.cpu = first ? "--" : percent(cpu)
        status.cpuFooter = first ? "--" : CPUUsage.label(cpu)
        status.cpuHistory = cpuHistory.values.suffix(Metric.barCount)

        status.memory = percent(memoryFraction)
        status.memoryPressure = memory.pressure.title
        status.memoryPressureLevel = memory.pressure
        status.memoryFooter = "\(Format.bytes(memory.used, digits: 2)) · \(Format.bytes(memory.swap, digits: 2)) swap"
        status.memoryUsedOfTotal = "\(Format.bytes(memory.used, digits: 2)) / \(Format.bytes(memory.total, digits: 0))"
        status.memoryHistory = memoryHistory.values

        if let disk = reading.disk, disk.total > 0 {
            let used = disk.total - disk.free
            status.diskFree = Format.bytes(disk.free, binary: false, digits: 0).components(separatedBy: " ").first ?? "--"
            status.diskFreeUnit = Format.bytes(disk.free, binary: false, digits: 0).components(separatedBy: " ").last ?? "GB"
            status.diskTotal = Format.bytes(disk.total, binary: false, digits: 0)
            status.diskUsed = Double(used) / Double(disk.total)
            status.diskFooter = "\(Format.bytes(used, binary: false, digits: 0)) used · \(percent(status.diskUsed))%"
        }

        if lastNetwork != nil, networkHistory.values.count > 0 || !online {
            let speed = Format.speed(download)
            status.network = online ? speed.value : "--"
            status.networkUnit = speed.unit
            let up = Format.speed(upload)
            status.networkUpload = online ? "Upload \(up.value) \(up.unit)" : "Upload --"
        }
        status.networkInterface = online ? interface : "Offline"
        status.networkLatency = online ? (latency == nil ? "" : Latency.label(milliseconds: latency)) : "Offline"
        status.networkHistory = networkHistory.values

        if let battery = reading.battery {
            status.hasBattery = true
            status.battery = "\(battery.percent)"
            status.batteryLevel = Double(battery.percent) / 100
            status.batteryHealth = "\(battery.health)% Health"
            status.batteryWatts = battery.pluggedIn ? battery.adapterWatts.map { "\($0)W" } : nil
            if battery.charged {
                status.batteryState = "Charged"
            } else if battery.charging {
                status.batteryState = battery.minutesLeft.map { "Charging · \(Format.duration(minutes: $0)) to full" } ?? "Charging"
            } else if battery.pluggedIn {
                status.batteryState = "Not Charging"
            } else {
                status.batteryState = battery.minutesLeft.map { "On Battery · \(Format.duration(minutes: $0)) left" } ?? "On Battery"
            }
        } else {
            status.hasBattery = false
            status.battery = "--"
            status.batteryState = "No battery"
            status.batteryHealth = "--"
        }

        if let samples = reading.processes {
            let groups = ProcessGrouping.stableOrder(ProcessGrouping.group(samples), previous: status.processes.map(\.id))
            status.processCount = groups.count
            status.processes = groups.map { group in
                ProcessRowData(id: group.pid, name: group.name, memory: Format.bytes(group.memory),
                               cpu: group.cpu, cpuText: Format.number(group.cpu, digits: 1),
                               power: group.power.map { Format.number($0, digits: 1) } ?? "--",
                               bundlePath: group.bundlePath)
            }
            if let drain = groups.max(by: { $0.cpu < $1.cpu }), drain.cpu > 1 {
                status.batteryDrain = "Top drain now \(drain.name)"
            }
        }

        if let disk = reading.disk {
            let health = Health(Health.Input(pressure: memory.pressure,
                                             diskFreeFraction: disk.total > 0 ? Double(disk.free) / Double(disk.total) : 1,
                                             diskFreeBytes: disk.free, swapBytes: memory.swap,
                                             cpuTemperature: nil,
                                             sustainedCPU: cpuMinute.values.reduce(0, +) / Double(max(cpuMinute.values.count, 1))))
            status.health = "\(health.score)"
            status.healthWord = health.word
            status.healthReason = health.reasons.first ?? "All good"
            status.healthReasons = health.reasons
        }

        model.status = status
        // Only stats that can be read: the others never show in the menu bar.
        model.menuValues = [
            .cpu: status.cpu == "--" ? "--" : "\(status.cpu)%",
            .memory: "\(status.memory)%",
            .disk: "\(status.diskFree) \(status.diskFreeUnit)",
            .network: status.network == "--" ? "--" : "\(status.network) \(status.networkUnit)",
            .battery: status.hasBattery ? "\(status.battery)%" : "--",
        ]
    }
}

/// Times a TCP connect to 1.1.1.1:443; nil when it fails (S-006).
nonisolated enum LatencyProbe {
    static func measure() async -> Double? {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(host: "1.1.1.1", port: 443, using: .tcp)
            let start = DispatchTime.now()
            let once = Once()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
                    if once.fire() { continuation.resume(returning: ms) }
                    connection.cancel()
                case .failed, .waiting:
                    if once.fire() { continuation.resume(returning: nil) }
                    connection.cancel()
                default: break
                }
            }
            connection.start(queue: .global(qos: .utility))
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                if once.fire() { continuation.resume(returning: nil) }
                connection.cancel()
            }
        }
    }

    /// Lets exactly one caller through.
    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var fired = false

        func fire() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if fired { return false }
            fired = true
            return true
        }
    }
}
