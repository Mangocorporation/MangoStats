import Foundation
import MangoStatsKit
import SQLite3

/// Recorded minutes in a local SQLite file (S-027). All work runs on one
/// serial queue; callers get results through async functions.
///   ~/Library/Application Support/MangoStats/history.sqlite
///   APP_STORE=<path> runs (tests, snapshots) use <path>-history.sqlite in /tmp.
nonisolated final class HistoryStore: @unchecked Sendable {
    static let shared = HistoryStore(url: HistoryStore.defaultURL)

    private let queue = DispatchQueue(label: "history", qos: .utility)
    private var db: OpaquePointer?

    static var defaultURL: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path + "-history.sqlite")
        }
        let dir = URL.applicationSupportDirectory.appending(path: "MangoStats", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "history.sqlite")
    }

    init(url: URL) {
        queue.sync {
            guard sqlite3_open(url.path, &db) == SQLITE_OK else { db = nil; return }
            exec("""
            PRAGMA journal_mode = WAL;
            CREATE TABLE IF NOT EXISTS minutes (
                time INTEGER PRIMARY KEY, cpu REAL NOT NULL, memory REAL NOT NULL, gpu REAL,
                cpu_temp REAL, gpu_temp REAL, download REAL NOT NULL, upload REAL NOT NULL,
                battery REAL, cpu_watts REAL, gpu_watts REAL);
            CREATE TABLE IF NOT EXISTS speed_tests (
                time INTEGER PRIMARY KEY, download REAL NOT NULL, upload REAL NOT NULL,
                responsiveness REAL, idle_latency REAL);
            CREATE TABLE IF NOT EXISTS outages (
                start INTEGER PRIMARY KEY, end INTEGER NOT NULL, what TEXT NOT NULL);
            """)
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func insert(_ minute: MinuteSample) {
        queue.async {
            let sql = """
            INSERT OR REPLACE INTO minutes (time, cpu, memory, gpu, cpu_temp, gpu_temp, download, upload,
                battery, cpu_watts, gpu_watts) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            guard let statement = self.prepare(sql) else { return }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, Int64(minute.time.timeIntervalSince1970))
            let values: [Double?] = [minute.cpu, minute.memory, minute.gpu, minute.cpuTemperature,
                                     minute.gpuTemperature, minute.download, minute.upload, minute.battery,
                                     minute.cpuWatts, minute.gpuWatts]
            for (index, value) in values.enumerated() {
                if let value { sqlite3_bind_double(statement, Int32(index + 2), value) }
                else { sqlite3_bind_null(statement, Int32(index + 2)) }
            }
            sqlite3_step(statement)
        }
    }

    /// Minutes from `start` on, oldest first.
    func minutes(since start: Date) async -> [MinuteSample] {
        await withCheckedContinuation { continuation in
            queue.async {
                let sql = """
                SELECT time, cpu, memory, gpu, cpu_temp, gpu_temp, download, upload, battery, cpu_watts, gpu_watts
                FROM minutes WHERE time >= ? ORDER BY time
                """
                guard let statement = self.prepare(sql) else { return continuation.resume(returning: []) }
                defer { sqlite3_finalize(statement) }
                sqlite3_bind_int64(statement, 1, Int64(start.timeIntervalSince1970))
                var rows: [MinuteSample] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                    func number(_ column: Int32) -> Double? {
                        sqlite3_column_type(statement, column) == SQLITE_NULL ? nil : sqlite3_column_double(statement, column)
                    }
                    rows.append(MinuteSample(
                        time: Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 0))),
                        cpu: number(1) ?? 0, memory: number(2) ?? 0, gpu: number(3), cpuTemperature: number(4),
                        gpuTemperature: number(5), download: number(6) ?? 0, upload: number(7) ?? 0,
                        battery: number(8), cpuWatts: number(9), gpuWatts: number(10)))
                }
                continuation.resume(returning: rows)
            }
        }
    }

    /// A speed test result (S-043).
    func addSpeedTest(_ result: NetworkParse.SpeedResult) {
        queue.async {
            let sql = "INSERT OR REPLACE INTO speed_tests (time, download, upload, responsiveness, idle_latency) VALUES (?, ?, ?, ?, ?)"
            guard let statement = self.prepare(sql) else { return }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, Int64(result.date.timeIntervalSince1970))
            sqlite3_bind_double(statement, 2, result.download)
            sqlite3_bind_double(statement, 3, result.upload)
            if let rpm = result.responsiveness { sqlite3_bind_double(statement, 4, rpm) } else { sqlite3_bind_null(statement, 4) }
            if let idle = result.idleLatency { sqlite3_bind_double(statement, 5, idle) } else { sqlite3_bind_null(statement, 5) }
            sqlite3_step(statement)
        }
    }

    /// Speed tests, newest first.
    func speedTests(limit: Int = 20) async -> [NetworkParse.SpeedResult] {
        await withCheckedContinuation { continuation in
            queue.async {
                let sql = "SELECT time, download, upload, responsiveness, idle_latency FROM speed_tests ORDER BY time DESC LIMIT ?"
                guard let statement = self.prepare(sql) else { return continuation.resume(returning: []) }
                defer { sqlite3_finalize(statement) }
                sqlite3_bind_int(statement, 1, Int32(limit))
                var rows: [NetworkParse.SpeedResult] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                    func number(_ column: Int32) -> Double? {
                        sqlite3_column_type(statement, column) == SQLITE_NULL ? nil : sqlite3_column_double(statement, column)
                    }
                    rows.append(NetworkParse.SpeedResult(
                        date: Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 0))),
                        download: number(1) ?? 0, upload: number(2) ?? 0, responsiveness: number(3), idleLatency: number(4)))
                }
                continuation.resume(returning: rows)
            }
        }
    }

    /// An outage that ended (S-042).
    func addOutage(start: Date, end: Date, what: String) {
        queue.async {
            guard let statement = self.prepare("INSERT OR REPLACE INTO outages (start, end, what) VALUES (?, ?, ?)") else { return }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, Int64(start.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 2, Int64(end.timeIntervalSince1970))
            sqlite3_bind_text(statement, 3, what, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(statement)
        }
    }

    /// Outages from `start` on, newest first.
    func outages(since start: Date) async -> [(start: Date, end: Date, what: String)] {
        await withCheckedContinuation { continuation in
            queue.async {
                guard let statement = self.prepare("SELECT start, end, what FROM outages WHERE start >= ? ORDER BY start DESC")
                else { return continuation.resume(returning: []) }
                defer { sqlite3_finalize(statement) }
                sqlite3_bind_int64(statement, 1, Int64(start.timeIntervalSince1970))
                var rows: [(start: Date, end: Date, what: String)] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                    rows.append((Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 0))),
                                 Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 1))),
                                 String(cString: sqlite3_column_text(statement, 2))))
                }
                continuation.resume(returning: rows)
            }
        }
    }

    /// Deletes minutes before `cutoff` (S-030).
    func prune(before cutoff: Date) {
        queue.async {
            self.exec("DELETE FROM speed_tests WHERE time < \(Int64(cutoff.timeIntervalSince1970)); DELETE FROM outages WHERE start < \(Int64(cutoff.timeIntervalSince1970));")
            guard let statement = self.prepare("DELETE FROM minutes WHERE time < ?") else { return }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, Int64(cutoff.timeIntervalSince1970))
            sqlite3_step(statement)
        }
    }

    func clear() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.exec("DELETE FROM minutes; DELETE FROM speed_tests; DELETE FROM outages; VACUUM;")
                continuation.resume()
            }
        }
    }

    /// Waits for earlier writes (self-test).
    func flush() async {
        await withCheckedContinuation { continuation in queue.async { continuation.resume() } }
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var statement: OpaquePointer?
        return sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK ? statement : nil
    }
}
