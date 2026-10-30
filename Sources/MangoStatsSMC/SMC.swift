import Foundation
import IOKit

/// Reads and writes keys of the System Management Controller through
/// AppleSMC. Reading works for any user; writing (fan control) needs root.
public final class SMC: @unchecked Sendable {
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
        case read = 5, write = 6, keyAtIndex = 8, keyInfo = 9
    }

    private var connection: io_connect_t = 0
    private var infoCache: [UInt32: KeyInfo] = [:]

    public init?() {
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
    public func keys(where include: (String) -> Bool) -> [String] {
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
    public func value(_ key: String) -> Double? {
        let code = Self.code(key)
        guard let info = info(code) else { return nil }
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

    /// Writes raw bytes to a key. Needs root: as a normal user AppleSMC
    /// answers kIOReturnNotPrivileged.
    @discardableResult
    public func write(_ key: String, bytes: [UInt8]) -> Bool {
        let code = Self.code(key)
        guard let info = info(code), bytes.count <= Int(info.dataSize) else { return false }
        var input = Param()
        input.key = code
        input.info.dataSize = info.dataSize
        input.command = Command.write.rawValue
        withUnsafeMutableBytes(of: &input.bytes) { raw in
            for (index, byte) in bytes.enumerated() { raw[index] = byte }
        }
        return call(&input) != nil
    }

    private func info(_ code: UInt32) -> KeyInfo? {
        if let cached = infoCache[code] { return cached }
        var input = Param()
        input.key = code
        input.command = Command.keyInfo.rawValue
        guard let output = call(&input) else { return nil }
        infoCache[code] = output.info
        return output.info
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

/// One fan's limits and its manual-mode keys (F<n>md, F<n>Tg on Apple silicon).
public struct Fan: Sendable {
    public let index: Int
    public let min: Double
    public let max: Double
}

extension SMC {
    public func fans() -> [Fan] {
        guard let count = value("FNum"), count > 0 else { return [] }
        return (0..<Int(count)).compactMap { index in
            guard let max = value("F\(index)Mx") else { return nil }
            return Fan(index: index, min: value("F\(index)Mn") ?? 0, max: max)
        }
    }

    /// Manual mode with a target, or back to macOS with `rpm == nil`. Root only.
    @discardableResult
    public func setFan(_ fan: Fan, rpm: Double?) -> Bool {
        guard let rpm else { return write("F\(fan.index)md", bytes: [0]) }
        let target = Float(Swift.min(Swift.max(rpm, fan.min), fan.max))
        let bytes = withUnsafeBytes(of: target) { Array($0) }
        return write("F\(fan.index)md", bytes: [1]) && write("F\(fan.index)Tg", bytes: bytes)
    }

    /// Mean of the CPU sensors (Tp*, Te*) that read a believable value.
    public func cpuTemperature(keys: [String]) -> Double? {
        let values = keys.compactMap { value($0) }.filter { $0 > 1 && $0 < 130 }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
