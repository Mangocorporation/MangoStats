import AppKit
import Darwin

/// Quit and Force Quit for a process row (S-014). Apps quit the polite way,
/// through NSRunningApplication, so they can ask to save; other processes
/// get SIGTERM, and Force Quit sends SIGKILL.
enum ProcessActions {
    @discardableResult
    static func quit(_ pid: Int32) -> Bool {
        if let app = NSRunningApplication(processIdentifier: pid), app.bundleIdentifier != nil {
            return app.terminate()
        }
        return kill(pid, SIGTERM) == 0
    }

    @discardableResult
    static func forceQuit(_ pid: Int32) -> Bool {
        if let app = NSRunningApplication(processIdentifier: pid), app.bundleIdentifier != nil {
            return app.forceTerminate()
        }
        return kill(pid, SIGKILL) == 0
    }
}
