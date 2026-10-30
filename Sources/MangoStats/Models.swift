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
    /// What the cards and tables show. The samplers replace it (S-001 and on).
    var status: StatusData = .initial
    /// What each stat shows in the menu bar, like "15%". Missing stats show "--".
    var menuValues: [MenuBarStat: String] = [:]
    /// Processes are read only while someone looks at them (S-023).
    /// Process table sort and search (S-012, S-013). Reset when the app starts.
    var processSort = ProcessSort.default
    var processQuery = ""
    var popoverOpen = false
    var windowOpen = false
    var detailVisible: Bool { popoverOpen || windowOpen }
    @ObservationIgnored private var sampler: Sampler?

    /// Starts reading the system. Snapshot runs keep the sample values, unless APP_LIVE=1.
    func startSampling() {
        let env = ProcessInfo.processInfo.environment
        let live = env["APP_LIVE"] == "1" || (env["APP_SNAPSHOT"] == nil && env["APP_SAMPLE"] != "1")
        guard sampler == nil, live else { return }
        sampler = Sampler(model: self)
        sampler?.start()
    }

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

    /// The stats the menu bar draws: on, and readable on this Mac.
    var shownStats: [MenuBarStat] { menuBar.visible.filter(isAvailable) }

    /// GPU, temperature, and fan readings arrive with M3 (S-015 to S-018).
    func isAvailable(_ stat: MenuBarStat) -> Bool {
        switch stat {
        case .gpu, .temperature, .fan: false
        case .battery: status.hasBattery
        default: true
        }
    }

    func unavailableReason(_ stat: MenuBarStat) -> String {
        stat == .battery ? "Not available on this Mac" : "Coming in a later version"
    }

    func setShown(_ stat: MenuBarStat, _ shown: Bool) {
        if shown { menuBar.enabled.insert(stat) } else { menuBar.enabled.remove(stat) }
    }
}
