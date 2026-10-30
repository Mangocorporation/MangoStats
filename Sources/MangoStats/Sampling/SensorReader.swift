import Foundation
import IOKit
import MangoStatsKit
import MangoStatsSMC

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
        smc?.cpuTemperature(keys: keys)
    }

    private func fans() -> [FanReading] {
        guard let smc else { return [] }
        return smc.fans().compactMap { fan in
            smc.value("F\(fan.index)Ac").map { FanReading(rpm: max($0, 0), min: fan.min, max: fan.max) }
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
