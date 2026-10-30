import Darwin
import Foundation
import IOKit
import IOKit.ps
import MangoStatsKit

// System readers. Each is a plain function that reads once and returns a
// Sendable value, so the sampler can call them off the main thread.

nonisolated enum CPUReader {
    /// Tick counters per core (S-001).
    static func ticks() -> [CPUTicks] {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return [] }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }
        return (0..<Int(count)).map { core in
            let base = core * Int(CPU_STATE_MAX)
            func tick(_ state: Int32) -> UInt64 { UInt64(UInt32(bitPattern: info[base + Int(state)])) }
            return CPUTicks(user: tick(CPU_STATE_USER), system: tick(CPU_STATE_SYSTEM),
                            idle: tick(CPU_STATE_IDLE), nice: tick(CPU_STATE_NICE))
        }
    }
}

nonisolated enum MemoryReader {
    static func read() -> MemoryReading {
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        var used: Int64 = 0
        if result == KERN_SUCCESS {
            let page = Int64(sysconf(_SC_PAGESIZE))
            let app = Int64(stats.internal_page_count) - Int64(stats.purgeable_count)
            used = (app + Int64(stats.wire_count) + Int64(stats.compressor_page_count)) * page
        }
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &swap, &size, nil, 0)
        var level: Int32 = 1
        size = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        return MemoryReading(total: total, used: min(max(used, 0), total), swap: Int64(swap.xsu_used),
                             pressure: MemoryPressure(level: Int(level)))
    }
}

nonisolated enum DiskReader {
    static func read() -> DiskReading? {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return DiskReading(total: Int64(total), free: free)
    }
}

nonisolated enum NetworkReader {
    /// Received and sent bytes on every interface that is up, except loopback (S-006).
    /// Reads the 64-bit counters (NET_RT_IFLIST2), which don't wrap at 4 GB.
    static func counters() -> NetworkCounters {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return NetworkCounters(received: 0, sent: 0) }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return NetworkCounters(received: 0, sent: 0) }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        var offset = 0
        buffer.withUnsafeBytes { raw in
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.load(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= length {
                    let info = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    let flags = Int32(info.ifm_flags)
                    if flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 {
                        received += info.ifm_data.ifi_ibytes
                        sent += info.ifm_data.ifi_obytes
                    }
                }
                offset += Int(header.ifm_msglen)
            }
        }
        return NetworkCounters(received: received, sent: sent)
    }
}

nonisolated enum BatteryReader {
    /// nil on a Mac without a battery (S-007).
    static func read() -> BatteryReading? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = unmanaged?.takeRetainedValue() as? [String: Any] else { return nil }
        func int(_ key: String) -> Int? { (props[key] as? NSNumber)?.intValue }
        func bool(_ key: String) -> Bool { (props[key] as? NSNumber)?.boolValue ?? false }
        guard bool("BatteryInstalled") || int("CurrentCapacity") != nil else { return nil }
        // On Apple silicon CurrentCapacity and MaxCapacity are percent; the raw mAh values carry the health.
        let current = int("CurrentCapacity") ?? 0
        let max = int("MaxCapacity") ?? 100
        let percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
        let rawMax = int("AppleRawMaxCapacity") ?? int("NominalChargeCapacity") ?? max
        let design = int("DesignCapacity") ?? rawMax
        let charging = bool("IsCharging")
        let minutes = charging ? int("AvgTimeToFull") : int("AvgTimeToEmpty")
        let adapter = props["AdapterDetails"] as? [String: Any]
        return BatteryReading(percent: min(percent, 100),
                              health: Battery.health(maxCapacity: rawMax, designCapacity: design),
                              charging: charging, pluggedIn: bool("ExternalConnected"),
                              charged: bool("FullyCharged") || (bool("ExternalConnected") && !charging && percent >= 99),
                              adapterWatts: (adapter?["Watts"] as? NSNumber)?.intValue,
                              minutesLeft: minutes.flatMap { $0 > 0 && $0 < 65_535 ? $0 : nil })
    }
}

nonisolated extension SystemInfo {
    static func read() -> SystemInfo {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let chip = String(decoding: brand.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            .replacingOccurrences(of: "Apple ", with: "")
        var boot = timeval()
        size = MemoryLayout<timeval>.size
        sysctlbyname("kern.boottime", &boot, &size, nil, 0)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let patch = version.patchVersion > 0 ? ".\(version.patchVersion)" : ""
        return SystemInfo(chip: chip.isEmpty ? "Mac" : chip,
                          memory: Int64(ProcessInfo.processInfo.physicalMemory),
                          macOS: "macOS \(version.majorVersion).\(version.minorVersion)\(patch)",
                          boot: Date(timeIntervalSince1970: TimeInterval(boot.tv_sec)))
    }
}
