import AppKit
import MangoStatsKit
import Observation
import SwiftUI
import UserNotifications

/// Shows alerts as macOS notifications (S-031 to S-033) and handles clicks.
@Observable
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    enum Permission { case unknown, allowed, denied }

    static let shared = Notifier()

    private(set) var permission: Permission = .unknown
    /// Set by MenuBarLabel, so a click on an alert can open the Status window.
    @ObservationIgnored var openStatus: (() -> Void)?
    @ObservationIgnored weak var model: AppModel?

    /// Test and snapshot runs never post real notifications.
    private var allowed: Bool { !Store.isOverridden }

    override private init() {
        super.init()
        guard allowed else { return }
        UNUserNotificationCenter.current().delegate = self
        refresh()
    }

    func refresh() {
        guard allowed else { return }
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let next: Permission = switch settings.authorizationStatus {
            case .authorized, .provisional: .allowed
            case .denied: .denied
            default: .unknown
            }
            if next != permission { permission = next }
        }
    }

    /// Asked when people turn on "Show alerts", never at launch.
    func requestPermission() {
        guard allowed else { return }
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            refresh()
        }
    }

    func post(_ event: AlertEvent) {
        guard allowed else { return }
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default
        if let app = event.app { content.userInfo = ["app": app] }
        let request = UNNotificationRequest(identifier: "\(event.kind.rawValue)-\(Date.now.timeIntervalSince1970)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func sendTest() {
        post(AlertEvent(kind: .cpuHot, title: "MangoStats alerts are on",
                        body: "You'll see an alert like this when something needs attention."))
    }

    static func openNotificationSettings() {
        SystemSettings.open("com.apple.Notifications-Settings.extension?id=\(Bundle.main.bundleIdentifier ?? "")")
    }

    // Show alerts even while a MangoStats window is in front.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // A click opens the Status window; a busy-app alert filters the table to that app (S-033).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let app = response.notification.request.content.userInfo["app"] as? String
        await MainActor.run {
            if let app, let model {
                model.page = .status
                model.processQuery = app
            }
            NSApp.activate()
            openStatus?()
        }
    }
}
