import ServiceManagement

/// Open at login through SMAppService (S-020). The status is read live, so
/// a change in System Settings > General > Login Items shows up here too.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ on: Bool) throws {
        // Test and snapshot runs never touch the real login items.
        guard !Store.isOverridden else { return }
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}
