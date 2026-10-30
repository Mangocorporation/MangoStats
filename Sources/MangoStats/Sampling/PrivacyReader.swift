import AppKit
import CoreAudio
import CoreMediaIO
import Foundation
import IOKit.pwr_mgt
import MangoStatsKit

/// Camera, microphone, and who keeps the Mac awake (S-019). Reads only
/// whether devices are running and power assertions: no camera or mic
/// permission is needed, and nothing is recorded.
nonisolated enum PrivacyReader {
    static func read() -> PrivacyReading {
        let (awake, screen) = assertionHolders()
        return PrivacyReading(cameraInUse: cameraInUse(), micInUse: micInUse(),
                              keepingAwake: awake, keepingScreenOn: screen)
    }

    /// Any camera running for any app (kCMIODevicePropertyDeviceIsRunningSomewhere).
    private static func cameraInUse() -> Bool {
        var address = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
                                                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &size) == 0,
              size > 0 else { return false }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, size, &used,
                                        &devices) == 0 else { return false }
        return devices.contains { device in
            var running = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard))
            var value: UInt32 = 0
            var valueSize: UInt32 = 0
            return CMIOObjectGetPropertyData(device, &running, 0, nil, UInt32(MemoryLayout<UInt32>.size), &valueSize,
                                             &value) == 0 && value != 0
        }
    }

    /// Any input device running for any app. Output devices don't count:
    /// playing music is not a privacy signal.
    private static func micInUse() -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr
        else { return false }
        var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size,
                                         &devices) == noErr else { return false }
        return devices.contains { device in
            var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                                                     mScope: kAudioObjectPropertyScopeInput,
                                                     mElement: kAudioObjectPropertyElementMain)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(device, &streams, 0, nil, &streamSize) == noErr, streamSize > 0
            else { return false }
            var running = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                                     mScope: kAudioObjectPropertyScopeGlobal,
                                                     mElement: kAudioObjectPropertyElementMain)
            var value: UInt32 = 0
            var valueSize = UInt32(MemoryLayout<UInt32>.size)
            return AudioObjectGetPropertyData(device, &running, 0, nil, &valueSize, &value) == noErr && value != 0
        }
    }

    /// Processes holding sleep assertions, by kind.
    private static func assertionHolders() -> (awake: [String], screen: [String]) {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess,
              let byProcess = unmanaged?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return ([], []) }
        let systemTypes: Set<String> = ["PreventUserIdleSystemSleep", "NoIdleSleepAssertion", "PreventSystemSleep"]
        let displayTypes: Set<String> = ["PreventUserIdleDisplaySleep", "NoDisplaySleepAssertion"]
        var awake: [String] = []
        var screen: [String] = []
        for (pid, assertions) in byProcess {
            for assertion in assertions {
                let name = assertion["Process Name"] as? String ?? processName(pid.int32Value)
                // powerd always holds "Prevent sleep while display is on"; it says nothing about apps.
                guard name != "powerd", let type = assertion["AssertType"] as? String,
                      (assertion["AssertLevel"] as? NSNumber)?.intValue ?? 255 > 0 else { continue }
                if systemTypes.contains(type) { awake.append(name) }
                if displayTypes.contains(type) { screen.append(name) }
            }
        }
        return (awake, screen)
    }

    private static func processName(_ pid: Int32) -> String {
        if let app = NSRunningApplication(processIdentifier: pid), let name = app.localizedName { return name }
        var buffer = [CChar](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
                          : "PID \(pid)"
    }
}
