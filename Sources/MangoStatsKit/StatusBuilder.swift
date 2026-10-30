import Foundation

/// Network facts the sampler learns outside the readings.
public struct NetworkContext: Sendable {
    public var interface: String
    public var online: Bool
    /// Milliseconds to connect, nil before the first probe or when it failed.
    public var latency: Double?

    public init(interface: String = "Network", online: Bool = true, latency: Double? = nil) {
        self.interface = interface
        self.online = online
        self.latency = latency
    }
}

public struct StatusUpdate: Sendable {
    public var status: StatusData
    public var menuValues: [MenuBarStat: String]
    /// The raw values of this reading for history (S-027); nil on the first reading (no CPU yet).
    public var point: MinuteSample?
}

/// Turns readings into what the screens show (S-001 to S-008). Keeps the
/// histories and the previous counters between readings. Plain value, so
/// tests feed it made-up readings.
public struct StatusBuilder: Sendable {
    /// Bars in the CPU card (design/KIT.md, Bar history).
    public static let cpuBars = 10

    private let system: SystemInfo
    private var lastTicks: [CPUTicks] = []
    private var lastNetwork: (received: UInt64, sent: UInt64, time: Date)?
    private var cpuHistory = History()
    private var memoryHistory = History()
    private var networkHistory = History()
    private var gpuHistory = History()
    private var batteryHistory = History()
    private var diskReadHistory = History()
    private var diskWriteHistory = History()
    private var lastDisk: (read: Int64, written: Int64, time: Date)?
    private var fanHistory = History()
    private var cpuMinute = History(capacity: 30)

    public init(system: SystemInfo) {
        self.system = system
    }

    /// Folds one reading into the histories and returns what the screens show.
    /// `previous` keeps values a reading may lack (processes while nobody looks).
    public mutating func update(_ reading: Reading, network: NetworkContext, previous: StatusData) -> StatusUpdate {
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

        var status = previous
        let percent = { (value: Double) in Format.number(value * 100, digits: 0) }

        status.chip = system.chip
        status.ram = Format.bytes(system.memory, digits: 0)
        status.macOS = system.macOS
        status.uptime = Format.uptime(reading.time.timeIntervalSince(system.boot))

        status.cpu = first ? "--" : percent(cpu)
        let sensors = reading.sensors
        status.cpuFooter = first ? "--" : Self.footer(CPUUsage.label(cpu), watts: sensors.cpuWatts)
        status.cpuTemp = sensors.cpuTemperature.map(Format.celsius)
        status.hasTemperature = sensors.cpuTemperature != nil

        // GPU (S-015)
        if let gpu = sensors.gpu {
            gpuHistory.append(gpu)
            status.hasGPU = true
            status.gpu = percent(gpu)
            status.gpuFooter = Self.footer(CPUUsage.label(gpu), watts: sensors.gpuWatts)
            status.gpuHistory = gpuHistory.values
        }
        status.gpuTemp = sensors.gpuTemperature.map(Format.celsius)

        // Fan (S-018): the first fan; Macs without one say so.
        if let fan = sensors.fans.first {
            fanHistory.append(fan.speed)
            status.fanHistory = fanHistory.values
            status.hasFan = true
            status.fanRPM = Format.number(fan.rpm, digits: 0)
            status.fanSpeed = L10n.f("Speed %@%%", percent(fan.speed))
            status.fanNote = L10n.t("Managed by macOS")
        } else {
            status.hasFan = false
            status.fanRPM = "--"
            status.fanSpeed = L10n.t("No fan")
            status.fanNote = L10n.t("This Mac has no fan")
        }
        status.cpuHistory = cpuHistory.values.suffix(Self.cpuBars)

        status.memory = percent(memoryFraction)
        status.memoryPressure = memory.pressure.title
        status.memoryPressureLevel = memory.pressure
        status.memoryFooter = L10n.f("%@ · %@ swap", Format.bytes(memory.used, digits: 2), Format.bytes(memory.swap, digits: 2))
        status.memoryUsedOfTotal = "\(Format.bytes(memory.used, digits: 2)) / \(Format.bytes(memory.total, digits: 0))"
        status.memoryHistory = memoryHistory.values

        if let disk = reading.disk, disk.total > 0 {
            let used = disk.total - disk.free
            status.diskFree = Format.bytes(disk.free, binary: false, digits: 0).components(separatedBy: " ").first ?? "--"
            status.diskFreeUnit = Format.bytes(disk.free, binary: false, digits: 0).components(separatedBy: " ").last ?? "GB"
            status.diskTotal = Format.bytes(disk.total, binary: false, digits: 0)
            status.diskUsed = Double(used) / Double(disk.total)
            status.diskFooter = L10n.f("%@ used · %@%%", Format.bytes(used, binary: false, digits: 0), percent(status.diskUsed))
        }

        if lastNetwork != nil, networkHistory.values.count > 0 || !network.online {
            let speed = Format.speed(download)
            status.network = network.online ? speed.value : "--"
            status.networkUnit = speed.unit
            let up = Format.speed(upload)
            status.networkUpload = network.online ? L10n.f("Upload %@ %@", up.value, up.unit) : L10n.t("Upload --")
            status.networkUploadShort = network.online ? "↑ \(up.value) \(up.unit)" : "↑ --"
        }
        status.networkInterface = network.online ? L10n.t(network.interface) : L10n.t("Offline")
        status.networkLatency = network.online ? (network.latency == nil ? "" : Latency.label(milliseconds: network.latency)) : L10n.t("Offline")
        status.networkHistory = networkHistory.values

        if let battery = reading.battery {
            batteryHistory.append(Double(battery.percent) / 100)
            status.batteryHistory = batteryHistory.values
            status.hasBattery = true
            status.battery = "\(battery.percent)"
            status.batteryLevel = Double(battery.percent) / 100
            status.batteryHealth = L10n.f("%ld%% Health", battery.health)
            status.batteryWatts = battery.pluggedIn ? battery.adapterWatts.map { "\($0)W" } : nil
            if battery.charged {
                status.batteryState = L10n.t("Charged")
            } else if battery.charging {
                status.batteryState = battery.minutesLeft.map { L10n.f("Charging · %@ to full", Format.duration(minutes: $0)) } ?? L10n.t("Charging")
            } else if battery.pluggedIn {
                status.batteryState = L10n.t("Not Charging")
            } else {
                status.batteryState = battery.minutesLeft.map { L10n.f("On Battery · %@ left", Format.duration(minutes: $0)) } ?? L10n.t("On Battery")
            }
        } else {
            status.hasBattery = false
            status.battery = "--"
            status.batteryState = L10n.t("No battery")
            status.batteryHealth = "--"
        }

        if let samples = reading.processes {
            let groups = ProcessGrouping.stableOrder(ProcessGrouping.group(samples), previous: status.processes.map(\.id))
            status.processCount = groups.count
            status.processes = groups.map { group in
                ProcessRowData(id: group.pid, name: group.name, memory: Format.bytes(group.memory),
                               cpu: group.cpu, cpuText: Format.number(group.cpu, digits: 1),
                               power: group.power.map { Format.number($0, digits: 1) } ?? "--",
                               bundlePath: group.bundlePath, memoryBytes: group.memory, watts: group.power,
                               ownedByUser: group.owned, diskRate: group.diskRate,
                               energyWh: group.energy.map { $0 / 3600 })
            }
            if let drain = groups.max(by: { $0.cpu < $1.cpu }), drain.cpu > 1 {
                status.batteryDrain = L10n.f("Top drain now %@", drain.name)
            }
        }

        if let disk = reading.disk {
            let health = Health(Health.Input(pressure: memory.pressure,
                                             diskFreeFraction: disk.total > 0 ? Double(disk.free) / Double(disk.total) : 1,
                                             diskFreeBytes: disk.free, swapBytes: memory.swap,
                                             cpuTemperature: reading.sensors.cpuTemperature,
                                             sustainedCPU: cpuMinute.values.reduce(0, +) / Double(max(cpuMinute.values.count, 1))))
            status.health = "\(health.score)"
            status.healthWord = health.word
            status.healthReason = health.reasons.first ?? L10n.t("All good")
            status.healthReasons = health.reasons
        }

        // Overview lines and the insight card (S-037)
        status.memoryFraction = memoryFraction
        status.memoryUsedLine = L10n.f("%@ used of %@", Format.bytes(memory.used, digits: 2), Format.bytes(memory.total, digits: 0))
        status.memoryDetailLine = L10n.f("%@ swap · pressure %@", Format.bytes(memory.swap, digits: 2), memory.pressure.title.lowercased())
        if let disk = reading.disk, disk.total > 0 {
            status.storageTitle = L10n.f("%@ free", Format.bytes(disk.free, binary: false, digits: 0))
            let used = Format.bytes(disk.total - disk.free, binary: false, digits: 0).components(separatedBy: " ").first ?? ""
            status.storageLine = L10n.f("%@ of %@ used on %@.", used, Format.bytes(disk.total, binary: false, digits: 0), system.volumeName)
        }
        if lastNetwork != nil {
            let down = Format.speed(download)
            let up = Format.speed(upload)
            let lag = network.latency.map { " · " + Latency.label(milliseconds: $0).lowercased() } ?? ""
            status.networkLine = network.online ? "↓ \(down.value) \(down.unit) · ↑ \(up.value) \(up.unit)\(lag)" : L10n.t("Offline")
        }
        if let battery = reading.battery {
            let time = battery.minutesLeft.map {
                battery.charging ? L10n.f("%@ to full", Format.duration(minutes: $0)) : L10n.f("%@ left", Format.duration(minutes: $0))
            } ?? (battery.charged ? L10n.t("Charged") : battery.pluggedIn ? L10n.t("On power") : L10n.t("On battery"))
            let drain = status.processes.max { $0.cpu < $1.cpu }.map { " · " + L10n.f("%@ drains most", $0.name) } ?? ""
            status.batteryLine = time + drain
        } else {
            status.batteryLine = L10n.t("No battery")
        }
        let topMemory = status.processes.max { $0.memoryBytes < $1.memoryBytes }
        let topCPU = status.processes.max { $0.cpu < $1.cpu }
        status.insights = Insight.all(Insight.Input(
            memoryFraction: memoryFraction, swap: memory.swap, pressure: memory.pressure,
            diskFree: reading.disk?.free, diskTotal: reading.disk?.total, cpuTemperature: sensors.cpuTemperature,
            topMemory: topMemory.map { ($0.name, $0.memoryBytes) }, topCPU: topCPU.map { ($0.name, $0.cpu) },
            battery: reading.battery.map { ($0.percent, !$0.pluggedIn) }))

        // Battery details (S-048)
        if let battery = reading.battery {
            if let cycles = battery.cycleCount {
                status.batteryCycles = battery.designCycles.map { L10n.f("%ld of %@", cycles, Format.number(Double($0), digits: 0)) } ?? "\(cycles)"
            }
            if let max = battery.maxCapacity, let design = battery.designCapacity {
                status.batteryCapacity = L10n.f("%@ of %@ mAh", Format.number(Double(max), digits: 0), Format.number(Double(design), digits: 0))
            }
            if let volts = battery.voltage, let amps = battery.amperage {
                let watts = abs(volts * amps)
                status.batteryPower = amps > 0.05 ? L10n.f("Charging at %@", Format.watts(watts))
                    : amps < -0.05 ? L10n.f("Using %@", Format.watts(watts)) : L10n.t("Idle")
            }
            status.batteryTemperature = battery.temperature.map { "\(Format.number($0, digits: 1)) °C" } ?? "–"
            status.batteryServiceRecommended = battery.health < 80
            status.batteryCondition = battery.health >= 80 ? L10n.t("Normal") : L10n.t("Service recommended")
            if let name = battery.adapterName, battery.pluggedIn {
                status.batteryAdapter = battery.adapterWatts.map { "\(name) · \($0) W" } ?? name
            } else {
                status.batteryAdapter = battery.pluggedIn ? L10n.t("Connected") : L10n.t("Not connected")
            }
        }

        // Disk activity (S-050)
        if let disk = reading.disk, let read = disk.readBytes, let written = disk.writtenBytes {
            if let last = lastDisk {
                let seconds = reading.time.timeIntervalSince(last.time)
                let readRate = Rate.perSecond(previous: UInt64(max(last.read, 0)), current: UInt64(max(read, 0)), seconds: seconds)
                let writeRate = Rate.perSecond(previous: UInt64(max(last.written, 0)), current: UInt64(max(written, 0)), seconds: seconds)
                diskReadHistory.append(readRate)
                diskWriteHistory.append(writeRate)
                let r = Format.speed(readRate)
                let w = Format.speed(writeRate)
                status.diskRead = "\(r.value) \(r.unit)"
                status.diskWrite = "\(w.value) \(w.unit)"
                status.diskReadHistory = diskReadHistory.values
                status.diskWriteHistory = diskWriteHistory.values
            }
            lastDisk = (read, written, reading.time)
        }

        // Camera, mic, and sleep (S-019)
        let privacy = reading.privacy
        switch (privacy.cameraInUse, privacy.micInUse) {
        case (true, true): status.privacyText = L10n.t("Camera and mic in use")
        case (true, false): status.privacyText = L10n.t("Camera in use")
        case (false, true): status.privacyText = L10n.t("Mic in use")
        case (false, false): status.privacyText = L10n.t("Not in use")
        }
        status.privacyActive = privacy.cameraInUse || privacy.micInUse
        status.awakeText = privacy.keepingAwake.isEmpty ? L10n.t("Can sleep") : L10n.t("Awake")
        status.awakeHelp = Self.holders(privacy.keepingAwake, screen: false)
        status.screenText = privacy.keepingScreenOn.isEmpty ? L10n.t("Screen can sleep") : L10n.t("Screen on")
        status.screenHelp = Self.holders(privacy.keepingScreenOn, screen: true)

        // Only stats that can be read: the others never show in the menu bar.
        let menuValues: [MenuBarStat: String] = [
            .cpu: status.cpu == "--" ? "--" : "\(status.cpu)%",
            .memory: "\(status.memory)%",
            .disk: "\(status.diskFree) \(status.diskFreeUnit)",
            .network: status.network == "--" ? "--" : "\(status.network) \(status.networkUnit)",
            .battery: status.hasBattery ? "\(status.battery)%" : "--",
            .gpu: status.hasGPU ? "\(status.gpu)%" : "--",
            .temperature: status.cpuTemp ?? "--",
            .fan: status.hasFan ? "\(status.fanRPM) RPM" : "--",
        ]
        let point = first ? nil : MinuteSample(
            time: reading.time, cpu: cpu, memory: memoryFraction, gpu: sensors.gpu,
            cpuTemperature: sensors.cpuTemperature, gpuTemperature: sensors.gpuTemperature,
            download: download, upload: upload, battery: reading.battery.map { Double($0.percent) / 100 },
            cpuWatts: sensors.cpuWatts, gpuWatts: sensors.gpuWatts)
        return StatusUpdate(status: status, menuValues: menuValues, point: point)
    }

    /// "Keeping the Mac awake: Safari, Zoom" / "Nothing keeps the Mac awake".
    static func holders(_ names: [String], screen: Bool) -> String {
        let unique = Array(Set(names)).sorted()
        if unique.isEmpty { return L10n.t(screen ? "Nothing keeps the screen on" : "Nothing keeps the Mac awake") }
        return L10n.f(screen ? "Keeping the screen on: %@" : "Keeping the Mac awake: %@", unique.joined(separator: ", "))
    }

    /// "idle · 0.9W", or just "idle" without a power reading.
    static func footer(_ label: String, watts: Double?) -> String {
        watts.map { "\(label) · \(Format.watts($0))" } ?? label
    }
}
