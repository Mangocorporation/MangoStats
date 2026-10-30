import Darwin
import Foundation
import MangoStatsKit

/// Reads every process (S-008). `/bin/ps` runs as root, so it sees other
/// users' processes (WindowServer, mds) that `proc_pid_rusage` refuses.
/// For our own processes, rusage deltas replace ps's averaged CPU with the
/// real share since the last read and add power.
nonisolated final class ProcessReader: @unchecked Sendable {
    private struct Usage {
        var cpuNanos: UInt64
        var energy: UInt64
    }

    private var last: [Int32: Usage] = [:]
    private var lastTime: UInt64 = 0
    private let timebase: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom)
    }()

    func read() -> [ProcessSample] {
        var samples = ProcessGrouping.parsePS(runPS())
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = lastTime == 0 ? 0 : Double(now - lastTime)
        var next: [Int32: Usage] = [:]
        for index in samples.indices {
            let pid = samples[index].pid
            var info = rusage_info_v6()
            let ok = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V6, $0) == 0
                }
            }
            guard ok else { continue }
            // rusage times are in Mach absolute units; convert to nanoseconds.
            let usage = Usage(cpuNanos: UInt64(Double(info.ri_user_time + info.ri_system_time) * timebase),
                              energy: info.ri_energy_nj)
            next[pid] = usage
            samples[index].memory = Int64(info.ri_phys_footprint)
            if elapsed > 0, let old = last[pid], usage.cpuNanos >= old.cpuNanos, usage.energy >= old.energy {
                samples[index].cpu = Double(usage.cpuNanos - old.cpuNanos) / elapsed * 100
                // Energy is in nanojoules (ri_energy_nj; billed energy barely moves): nJ per ns is watts.
                samples[index].power = Double(usage.energy - old.energy) / elapsed
            }
        }
        last = next
        lastTime = now
        return samples
    }

    private func runPS() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,rss=,%cpu=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
