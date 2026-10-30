import Foundation
import Network
import MangoStatsKit

/// Reads the system every `interval` seconds and fills `AppModel.status`
/// and the menu bar values (S-001 to S-008).
@MainActor
final class Sampler {
    private weak var model: AppModel?
    private var task: Task<Void, Never>?
    private let processReader = ProcessReader()
    private let sensorReader = SensorReader()
    private var builder = StatusBuilder(system: SystemInfo.read())
    private var network = NetworkContext()
    private var lastProcessRead: Date?
    /// Free space goes through CacheDelete, which validates every volume:
    /// it was 56 % of the app's CPU at a 2 s refresh. It barely changes, so
    /// it is read every 30 s (S-023).
    private var disk: (reading: DiskReading?, time: Date)?
    private static let diskInterval: TimeInterval = 30

    private let pathMonitor = NWPathMonitor()
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
                self?.network.interface = name
                self?.network.online = online
            }
        }
        pathMonitor.start(queue: .global(qos: .utility))
        latencyTask = Task { [weak self] in
            while !Task.isCancelled {
                let ms = await LatencyProbe.measure()
                self?.network.latency = ms
                try? await Task.sleep(for: .seconds(30))
            }
        }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sample()
                // Read each time, so a new interval applies without losing history (S-021).
                let seconds = self?.model?.refreshInterval ?? 2
                try? await Task.sleep(for: .seconds(seconds))
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
        // Processes cost the most to read: at most every 2 s, and only while someone looks (S-021, S-023).
        let wantProcesses = model.detailVisible && SampleSchedule.readProcesses(now: .now, last: lastProcessRead)
        if wantProcesses { lastProcessRead = .now }
        let reader = processReader
        let sensors = sensorReader
        let readDisk = disk.map { Date.now.timeIntervalSince($0.time) >= Self.diskInterval } ?? true
        let lastDisk = disk?.reading
        let reading = await Task.detached(priority: .utility) {
            Reading(ticks: CPUReader.ticks(), memory: MemoryReader.read(), disk: readDisk ? DiskReader.read() : lastDisk,
                    network: NetworkReader.counters(), battery: BatteryReader.read(),
                    processes: wantProcesses ? reader.read() : nil, sensors: sensors.read(),
                    privacy: PrivacyReader.read(), time: .now)
        }.value
        if readDisk { disk = (reading.disk, reading.time) }
        let update = builder.update(reading, network: network, previous: model.status)
        // Fan control (S-025): send the wanted mode, then show what is applied.
        FanControl.shared.tick()
        var status = update.status
        if let fan = reading.sensors.fans.first {
            status.fanNote = FanPolicy.note(FanControl.shared.applied, min: fan.min, max: fan.max)
        }
        model.status = status
        model.menuValues = update.menuValues
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
