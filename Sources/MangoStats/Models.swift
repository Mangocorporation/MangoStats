import Foundation
import Observation
import MangoStatsKit

/// Where settings live. Test, snapshot, and self-test runs set APP_STORE and
/// use a throwaway defaults domain, so they never touch the real settings.
enum Store {
    /// True when APP_STORE is set (tests, snapshots, self-test).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    static let testSuite = "com.mangocorp.mangostats.test"

    static let defaults: UserDefaults = {
        guard isOverridden, let suite = UserDefaults(suiteName: testSuite) else { return .standard }
        suite.removePersistentDomain(forName: testSuite)
        return suite
    }()
}

/// The Status window's pages. Snapshot mode walks through every case.
enum Page: String, CaseIterable, Identifiable {
    case status

    var id: String { rawValue }
    var title: String { "Status" }
}

/// App-wide state that the menu bar item, popover, and windows share.
@Observable
final class AppModel {
    var page: Page = .status

    /// Which stats show in the menu bar, in order (S-009).
    var menuBar: MenuBarLayout {
        didSet {
            Store.defaults.set(menuBar.encodedOrder, forKey: "menuBar.order")
            Store.defaults.set(menuBar.encodedEnabled, forKey: "menuBar.enabled")
        }
    }

    var menuBarStyle: MenuBarStyle {
        didSet { Store.defaults.set(menuBarStyle.rawValue, forKey: "menuBar.style") }
    }

    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: UserDefaults.standard.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { if !Store.isOverridden { UserDefaults.standard.set(settingsTab.rawValue, forKey: "settings.tab") } }
    }

    init() {
        let defaults = Store.defaults
        menuBar = MenuBarLayout(encodedOrder: defaults.string(forKey: "menuBar.order"),
                                encodedEnabled: defaults.string(forKey: "menuBar.enabled"))
        menuBarStyle = MenuBarStyle(rawValue: defaults.string(forKey: "menuBar.style") ?? "") ?? .iconAndValue
    }

    func setShown(_ stat: MenuBarStat, _ shown: Bool) {
        if shown { menuBar.enabled.insert(stat) } else { menuBar.enabled.remove(stat) }
    }
}
