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
    case status, network, history, about

    var id: String { rawValue }
    var title: String {
        switch self {
        case .status: "Overview"
        case .network: "Network"
        case .history: "History"
        case .about: "About"
        }
    }
}

/// App-wide state that the menu bar item, popover, and windows share.
@Observable
final class AppModel {
    /// Check for Updates (Sparkle). Test runs never start it.
    let updater = Updater()
    var page: Page = .status
    /// What the cards and tables show. The samplers replace it (S-001 and on).
    var status: StatusData = .initial
    /// What each stat shows in the menu bar, like "15%". Missing stats show "--".
    var menuValues: [MenuBarStat: String] = [:]
    /// Processes are read only while someone looks at them (S-023).
    /// Process table sort, kind, and search (S-012, S-013, S-038). Reset when the app starts.
    var processSort = ProcessSort(column: .cpu, descending: true)
    var processQuery = ""
    var processKind = ProcessKind.all
    var showAllProcesses = false
    /// Insights people dismissed, by kind and title, until they change (S-037).
    var dismissedInsights: Set<String> = []
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

    /// Seconds between samples: 1, 2, or 5 (S-021).
    var refreshInterval: Int {
        didSet { Store.defaults.set(refreshInterval, forKey: "sampler.interval") }
    }

    /// Days of history to keep: 7, 30, or 90 (S-030). Shorter prunes at once.
    var historyDays: Int {
        didSet {
            Store.defaults.set(historyDays, forKey: "history.days")
            HistoryStore.shared.prune(before: HistoryRetention.cutoff(days: historyDays, now: .now))
        }
    }

    /// Settings → Alerts (S-031, S-034).
    var alerts: AlertSettings {
        didSet { Store.defaults.set(alerts.encoded, forKey: "alerts") }
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
        alerts = AlertSettings.decode(defaults.data(forKey: "alerts"))
        let days = defaults.integer(forKey: "history.days")
        historyDays = HistoryRetention.choices.contains(days) ? days : HistoryRetention.defaultDays
        let interval = defaults.integer(forKey: "sampler.interval")
        refreshInterval = SampleSchedule.intervals.contains(interval) ? interval : 2
        menuBarStyle = MenuBarStyle(rawValue: defaults.string(forKey: "menuBar.style") ?? "") ?? .iconAndValue
    }

    /// Every insight, including heavy network traffic the Network tab found (S-047).
    var insights: [Insight] {
        var all = status.insights
        if let heavy = NetworkMonitor.shared.heavyApp {
            let words = HeavyTraffic.sentence(heavy)
            all.append(Insight(kind: .network, eyebrow: "Network is busy", title: words,
                               body: "It's using most of your bandwidth, so everything else on the network may feel slow.",
                               app: heavy.name))
        }
        return all
    }

    /// The insight card's content: the first issue not dismissed, or calm.
    var currentInsight: Insight {
        insights.first { !dismissedInsights.contains(Self.key($0)) } ?? .calm
    }

    /// "Health 84 · Good — 2 things worth a look".
    var healthLine: String {
        guard status.health != "--" else { return "Measuring…" }
        let open = insights.filter { !dismissedInsights.contains(Self.key($0)) }.count
        let worth = open == 0 ? "nothing needs a look" : open == 1 ? "1 thing worth a look" : "\(open) things worth a look"
        return "Health \(status.health) · \(status.healthWord) — \(worth)"
    }

    /// "Review Chrome": show that app at the top of the process list.
    func review(_ app: String) {
        page = .status
        processKind = .all
        processQuery = app
    }

    func dismiss(_ insight: Insight) {
        dismissedInsights.insert(Self.key(insight))
    }

    private static func key(_ insight: Insight) -> String { "\(insight.kind.rawValue)|\(insight.app ?? "")" }

    /// The stats the menu bar draws: on, and readable on this Mac.
    var shownStats: [MenuBarStat] { menuBar.visible.filter(isAvailable) }

    /// Whether this Mac can show a stat. Before the first reading, assume yes,
    /// so the menu bar doesn't flicker on launch.
    func isAvailable(_ stat: MenuBarStat) -> Bool {
        guard !menuValues.isEmpty else { return true }
        switch stat {
        case .gpu: return status.hasGPU
        case .temperature: return status.hasTemperature
        case .fan: return status.hasFan
        case .battery: return status.hasBattery
        default: return true
        }
    }

    func unavailableReason(_ stat: MenuBarStat) -> String {
        "Not available on this Mac"
    }

    func setShown(_ stat: MenuBarStat, _ shown: Bool) {
        if shown { menuBar.enabled.insert(stat) } else { menuBar.enabled.remove(stat) }
    }
}
