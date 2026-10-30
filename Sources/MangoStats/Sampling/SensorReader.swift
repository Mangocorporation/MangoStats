import Foundation
import IOKit
import MangoStatsKit

/// GPU load, temperatures, power, and fans (S-015 to S-018). None of these
/// need admin rights. Stateful: keeps the SMC connection, the sensor key
/// list found at start, and the IOReport subscription for energy deltas.
nonisolated final class SensorReader: @unchecked Sendable {
    private let smc = SMC()
    private let cpuKeys: [String]
    private let gpuKeys: [String]
    private let energy = EnergyReader()

    init() {
        cpuKeys = smc?.keys { $0.hasPrefix("Tp") || $0.hasPrefix("Te") } ?? []
        gpuKeys = smc?.keys { $0.hasPrefix("Tg") } ?? []
    }

    func read() -> SensorReading {
        let power = energy?.read()
        return SensorReading(gpu: Self.gpuLoad(),
                             cpuTemperature: average(cpuKeys),
                             gpuTemperature: average(gpuKeys),
                             cpuWatts: power?.cpu,
                             gpuWatts: power?.gpu,
                             fans: fans())
    }

    /// Mean of the sensors that read a believable value; nil when none do.
    private func average(_ keys: [String]) -> Double? {
        let values = keys.compactMap { smc?.value($0) }.filter { $0 > 1 && $0 < 130 }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private func fans() -> [FanReading] {
        guard let smc, let count = smc.value("FNum"), count > 0 else { return [] }
        return (0..<Int(count)).compactMap { index in
            guard let rpm = smc.value("F\(index)Ac") else { return nil }
            return FanReading(rpm: max(rpm, 0), max: smc.value("F\(index)Mx") ?? 0)
        }
    }

    /// "Device Utilization %" of the first GPU in the IORegistry.
    private static func gpuLoad() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString,
                                                           kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
               let load = (stats["Device Utilization %"] as? NSNumber)?.doubleValue {
                return min(max(load / 100, 0), 1)
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }
}

// MARK: - SMC

/// Reads keys from the System Management Controller through AppleSMC.
nonisolated private final class SMC {
    /// SMCKeyData_t from the kernel: 80 bytes. The padding after keyInfo
    /// matters: Swift would otherwise pack `result` into its tail.
    private struct KeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
        var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
    }

    private struct Param {
        var key: UInt32 = 0
        var version: (UInt8, UInt8, UInt8, UInt8, UInt16) = (0, 0, 0, 0, 0)
        var limits: (UInt16, UInt16, UInt32, UInt32, UInt32) = (0, 0, 0, 0, 0)
        var info = KeyInfo()
        var result: UInt8 = 0
        var status: UInt8 = 0
        var command: UInt8 = 0
        var index: UInt32 = 0
        var bytes: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
    }

    private enum Command: UInt8 {
        case read = 5, keyAtIndex = 8, keyInfo = 9
    }

    private var connection: io_connect_t = 0
    private var infoCache: [UInt32: KeyInfo] = [:]

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard MemoryLayout<Param>.stride == 80,
              IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else { return nil }
    }

    deinit {
        IOServiceClose(connection)
    }

    /// Every key whose name passes `include`, found once by walking the key list.
    func keys(where include: (String) -> Bool) -> [String] {
        guard let count = value("#KEY") else { return [] }
        return (0..<UInt32(count)).compactMap { index in
            var input = Param()
            input.command = Command.keyAtIndex.rawValue
            input.index = index
            guard let output = call(&input) else { return nil }
            let name = Self.name(output.key)
            return include(name) ? name : nil
        }
    }

    /// A key's value as a number, for the types fans and sensors use.
    func value(_ key: String) -> Double? {
        let code = Self.code(key)
        let info: KeyInfo
        if let cached = infoCache[code] {
            info = cached
        } else {
            var input = Param()
            input.key = code
            input.command = Command.keyInfo.rawValue
            guard let output = call(&input) else { return nil }
            info = output.info
            infoCache[code] = info
        }
        var input = Param()
        input.key = code
        input.info.dataSize = info.dataSize
        input.command = Command.read.rawValue
        guard let output = call(&input) else { return nil }
        let bytes = withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(info.dataSize))) }
        switch Self.name(info.dataType) {
        case "flt " where bytes.count >= 4: return Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
        case "ui8 " where bytes.count >= 1: return Double(bytes[0])
        case "ui16" where bytes.count >= 2: return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32" where bytes.count >= 4: return Double(bytes.prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        case "fpe2" where bytes.count >= 2: return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        case "sp78" where bytes.count >= 2: return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
        default: return nil
        }
    }

    private func call(_ input: inout Param) -> Param? {
        var output = Param()
        var size = MemoryLayout<Param>.stride
        let result = IOConnectCallStructMethod(connection, 2, &input, MemoryLayout<Param>.stride, &output, &size)
        return result == kIOReturnSuccess && output.result == 0 ? output : nil
    }

    private static func code(_ key: String) -> UInt32 {
        key.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    private static func name(_ code: UInt32) -> String {
        String(decoding: [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }, as: UTF8.self)
    }
}

// MARK: - Energy (IOReport)

@_silgen_name("IOReportCopyChannelsInGroup")
nonisolated private func IOReportCopyChannelsInGroup(_ group: CFString?, _ subgroup: CFString?, _ a: UInt64, _ b: UInt64,
                                         _ c: UInt64) -> Unmanaged<CFMutableDictionary>?
@_silgen_name("IOReportCreateSubscription")
nonisolated private func IOReportCreateSubscription(_ a: UnsafeRawPointer?, _ channels: CFMutableDictionary,
                                        _ subscribed: UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>,
                                        _ b: UInt64, _ c: CFTypeRef?) -> OpaquePointer?
@_silgen_name("IOReportCreateSamples")
nonisolated private func IOReportCreateSamples(_ subscription: OpaquePointer, _ channels: CFMutableDictionary,
                                   _ a: CFTypeRef?) -> Unmanaged<CFDictionary>?
@_silgen_name("IOReportCreateSamplesDelta")
nonisolated private func IOReportCreateSamplesDelta(_ old: CFDictionary, _ new: CFDictionary, _ a: CFTypeRef?) -> Unmanaged<CFDictionary>?
@_silgen_name("IOReportChannelGetChannelName")
nonisolated private func IOReportChannelGetChannelName(_ channel: CFDictionary) -> Unmanaged<CFString>?
@_silgen_name("IOReportChannelGetUnitLabel")
nonisolated private func IOReportChannelGetUnitLabel(_ channel: CFDictionary) -> Unmanaged<CFString>?
@_silgen_name("IOReportSimpleGetIntegerValue")
nonisolated private func IOReportSimpleGetIntegerValue(_ channel: CFDictionary, _ index: Int32) -> Int64

/// CPU and GPU power from the "Energy Model" IOReport group, the source
/// `powermetrics` uses. Energy between two reads divided by the time.
nonisolated private final class EnergyReader {
    private let subscription: OpaquePointer
    private let channels: CFMutableDictionary
    private var last: (sample: CFDictionary, time: Date)?

    init?() {
        guard let group = IOReportCopyChannelsInGroup("Energy Model" as CFString, nil, 0, 0, 0)?.takeRetainedValue()
        else { return nil }
        var subscribed: Unmanaged<CFMutableDictionary>?
        guard let subscription = IOReportCreateSubscription(nil, group, &subscribed, 0, nil),
              let channels = subscribed?.takeRetainedValue() else { return nil }
        self.subscription = subscription
        self.channels = channels
    }

    /// Watts since the previous call; nil on the first.
    func read() -> (cpu: Double?, gpu: Double?)? {
        guard let sample = IOReportCreateSamples(subscription, channels, nil)?.takeRetainedValue() else { return nil }
        let now = Date.now
        defer { last = (sample, now) }
        guard let last, let delta = IOReportCreateSamplesDelta(last.sample, sample, nil)?.takeRetainedValue() as NSDictionary?,
              let items = delta["IOReportChannels"] as? [NSDictionary] else { return nil }
        let seconds = now.timeIntervalSince(last.time)
        guard seconds > 0 else { return nil }
        var cpu: Double?
        var gpu: Double?
        for item in items {
            let channel = item as CFDictionary
            guard let name = IOReportChannelGetChannelName(channel)?.takeUnretainedValue() as String?,
                  name == "CPU Energy" || name == "GPU Energy" else { continue }
            let unit = IOReportChannelGetUnitLabel(channel)?.takeUnretainedValue() as String? ?? "mJ"
            let joules = Double(IOReportSimpleGetIntegerValue(channel, 0)) * Self.joules(per: unit)
            if name == "CPU Energy" { cpu = joules / seconds } else { gpu = joules / seconds }
        }
        return (cpu, gpu)
    }

    /// The channels use different units: "CPU Energy" in mJ, "GPU Energy" in nJ.
    private static func joules(per unit: String) -> Double {
        switch unit.trimmingCharacters(in: .whitespaces) {
        case "nJ": 1e-9
        case "uJ", "µJ": 1e-6
        case "mJ": 1e-3
        default: 1
        }
    }
}
