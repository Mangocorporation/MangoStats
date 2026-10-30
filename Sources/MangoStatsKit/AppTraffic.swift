import Foundation

/// One app's network traffic right now (S-046).
public struct AppTraffic: Equatable, Sendable, Identifiable {
    public var name: String
    /// The outer .app, for apps; nil for background processes.
    public var bundlePath: String?
    /// Bytes per second.
    public var download: Double
    public var upload: Double
    /// Bytes since MangoStats started watching.
    public var sessionBytes: Int64

    public var id: String { bundlePath ?? name }
    public var rate: Double { download + upload }

    public init(name: String, bundlePath: String?, download: Double, upload: Double, sessionBytes: Int64) {
        self.name = name
        self.bundlePath = bundlePath
        self.download = download
        self.upload = upload
        self.sessionBytes = sessionBytes
    }
}

/// Turns per-process byte counters (from `nettop`) into per-app rates.
public struct TrafficMeter: Sendable {
    private var last: [Int32: (received: Int64, sent: Int64)] = [:]
    private var lastTime: Date?
    private var session: [String: Int64] = [:]

    public init() {}

    /// `counters` are cumulative per process; `paths` maps a pid to its executable path.
    public mutating func update(counters: [Int32: (received: Int64, sent: Int64)], paths: [Int32: String],
                                names: [Int32: String], time: Date) -> [AppTraffic] {
        defer {
            last = counters
            lastTime = time
        }
        guard let lastTime, time > lastTime else { return [] }
        let seconds = time.timeIntervalSince(lastTime)
        var apps: [String: AppTraffic] = [:]
        for (pid, now) in counters {
            guard let before = last[pid] else { continue }
            // A counter that went back means the pid was reused: skip this round.
            let down = now.received - before.received
            let up = now.sent - before.sent
            guard down >= 0, up >= 0, down + up > 0 else { continue }
            let path = paths[pid] ?? names[pid] ?? "pid \(pid)"
            let app = ProcessGrouping.outerApp(path)
            let name = app.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
                ?? names[pid] ?? URL(fileURLWithPath: path).lastPathComponent
            let key = app ?? name
            session[key, default: 0] += down + up
            var entry = apps[key] ?? AppTraffic(name: name, bundlePath: app, download: 0, upload: 0, sessionBytes: 0)
            entry.download += Double(down) / seconds
            entry.upload += Double(up) / seconds
            entry.sessionBytes = session[key] ?? 0
            apps[key] = entry
        }
        return apps.values.sorted { $0.rate != $1.rate ? $0.rate > $1.rate : $0.name < $1.name }
    }
}

/// The app behind heavy traffic, if one stands out (S-047).
public enum HeavyTraffic {
    /// An app above 1 MB/s with over 60 % of the traffic.
    public static func leader(_ apps: [AppTraffic]) -> AppTraffic? {
        let total = apps.reduce(0) { $0 + $1.rate }
        guard let top = apps.first, top.rate >= 1_000_000, total > 0, top.rate / total >= 0.6 else { return nil }
        return top
    }

    /// "Dropbox is uploading at 4.2 MB/s".
    public static func sentence(_ app: AppTraffic, locale: Locale = .current) -> String {
        let uploading = app.upload > app.download
        let speed = Format.speed(uploading ? app.upload : app.download, locale: locale)
        return L10n.f(uploading ? "%@ is uploading at %@ %@" : "%@ is downloading at %@ %@", app.name, speed.value, speed.unit)
    }
}

extension NetworkParse {
    /// `nettop -P -L 1 -J bytes_in,bytes_out -x` CSV -> pid: (received, sent), and pid: name.
    /// Names can contain dots ("com.apple.WebKit.Networking.1234"), so the pid is after the last one.
    public static func nettop(_ output: String) -> (counters: [Int32: (received: Int64, sent: Int64)], names: [Int32: String]) {
        var counters: [Int32: (received: Int64, sent: Int64)] = [:]
        var names: [Int32: String] = [:]
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count >= 3, let dot = fields[0].lastIndex(of: "."),
                  let pid = Int32(fields[0][fields[0].index(after: dot)...]),
                  let received = Int64(fields[1]), let sent = Int64(fields[2]) else { continue }
            counters[pid] = (received, sent)
            names[pid] = String(fields[0][..<dot])
        }
        return (counters, names)
    }
}
