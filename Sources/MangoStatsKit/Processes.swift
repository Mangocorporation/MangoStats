import Foundation

/// One running process as read from the system.
public struct ProcessSample: Equatable, Sendable {
    public var pid: Int32
    public var path: String
    public var memory: Int64
    /// % of one core, like Activity Monitor (can pass 100 on many cores).
    public var cpu: Double
    /// Watts, nil when the process belongs to another user.
    public var power: Double?
    /// True when the process belongs to this user, so it can be quit (S-014).
    public var owned: Bool
    /// Disk bytes per second since the last read, and energy used since the process started (joules).
    public var diskRate: Double?
    public var energy: Double?

    public init(pid: Int32, path: String, memory: Int64, cpu: Double, power: Double?, owned: Bool = false,
                diskRate: Double? = nil, energy: Double? = nil) {
        self.diskRate = diskRate
        self.energy = energy
        self.pid = pid
        self.path = path
        self.memory = memory
        self.cpu = cpu
        self.power = power
        self.owned = owned
    }
}

/// Processes of one app (all its helpers) or one lone process (S-008).
public struct ProcessGroup: Equatable, Sendable {
    public var name: String
    /// The outermost .app, for the icon; nil for a lone process.
    public var bundlePath: String?
    /// The main process: the one with the shortest path.
    public var pid: Int32
    public var memory: Int64
    public var cpu: Double
    public var power: Double?
    public var count: Int
    /// The main process belongs to this user.
    public var owned: Bool = false
    public var diskRate: Double?
    public var energy: Double?
}

public enum ProcessGrouping {
    /// "/Applications/Google Chrome.app/Contents/Frameworks/…/Helper.app/…" -> "/Applications/Google Chrome.app".
    public static func outerApp(_ path: String) -> String? {
        guard let range = path.range(of: ".app/") ?? (path.hasSuffix(".app") ? path.range(of: ".app") : nil) else {
            return nil
        }
        return String(path[..<range.upperBound]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .withLeadingSlash
    }

    public static func name(of path: String) -> String {
        if let app = outerApp(path) {
            return URL(fileURLWithPath: app).deletingPathExtension().lastPathComponent
        }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    /// Groups samples by app, sorted by memory, largest first. Ties keep a stable order by PID.
    public static func group(_ samples: [ProcessSample]) -> [ProcessGroup] {
        var groups: [String: ProcessGroup] = [:]
        var mainPathLength: [String: Int] = [:]
        for sample in samples {
            let app = outerApp(sample.path)
            let key = app ?? "pid:\(sample.pid)"
            if var group = groups[key] {
                group.memory += sample.memory
                group.cpu += sample.cpu
                if let power = sample.power { group.power = (group.power ?? 0) + power }
                if let disk = sample.diskRate { group.diskRate = (group.diskRate ?? 0) + disk }
                if let energy = sample.energy { group.energy = (group.energy ?? 0) + energy }
                group.count += 1
                if sample.path.count < mainPathLength[key, default: .max] {
                    group.pid = sample.pid
                    group.owned = sample.owned
                    mainPathLength[key] = sample.path.count
                }
                groups[key] = group
            } else {
                groups[key] = ProcessGroup(name: name(of: sample.path), bundlePath: app, pid: sample.pid,
                                           memory: sample.memory, cpu: sample.cpu, power: sample.power, count: 1,
                                           owned: sample.owned, diskRate: sample.diskRate, energy: sample.energy)
                mainPathLength[key] = sample.path.count
            }
        }
        return groups.values.sorted { $0.memory != $1.memory ? $0.memory > $1.memory : $0.pid < $1.pid }
    }

    /// Sorts by memory, but treats values within about 5 % as equal and keeps
    /// their previous order, so rows don't swap places on every sample (S-008).
    public static func stableOrder(_ groups: [ProcessGroup], previous: [Int32]) -> [ProcessGroup] {
        let rank = Dictionary(previous.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        func bucket(_ memory: Int64) -> Int { memory > 0 ? Int(log(Double(memory)) / log(1.05)) : 0 }
        return groups.sorted { a, b in
            let (ba, bb) = (bucket(a.memory), bucket(b.memory))
            if ba != bb { return ba > bb }
            let (ra, rb) = (rank[a.pid] ?? .max, rank[b.pid] ?? .max)
            if ra != rb { return ra < rb }
            return a.pid < b.pid
        }
    }

    /// Parses `ps -axo pid=,rss=,%cpu=,comm=` lines (rss in KB).
    public static func parsePS(_ output: String) -> [ProcessSample] {
        output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4, let pid = Int32(parts[0]), let rss = Int64(parts[1]),
                  let cpu = Double(parts[2].replacingOccurrences(of: ",", with: ".")) else { return nil }
            return ProcessSample(pid: pid, path: String(parts[3]), memory: rss * 1024, cpu: cpu, power: nil)
        }
    }
}

private extension String {
    var withLeadingSlash: String { hasPrefix("/") ? self : "/" + self }
}
