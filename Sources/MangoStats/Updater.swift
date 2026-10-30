import Foundation
import Observation
import Sparkle

/// Check for Updates, through Sparkle. The feed is site/appcast.xml on the
/// website (SUFeedURL in Info.plist). Every zip in it is signed with our EdDSA
/// key (SUPublicEDKey) and must carry our Developer ID signature, or Sparkle
/// refuses to install it. tools/release.sh writes the feed (docs/RELEASE.md).
@Observable
final class Updater: NSObject, SPUStandardUserDriverDelegate {
    /// Test runs never start it: no network, no update alerts.
    let enabled = !Store.isOverridden
    /// False while a check or an install is under way.
    private(set) var canCheck = false
    /// A newer version that a background check found and the person has not
    /// looked at yet. The popover offers it and its Settings button shows a dot.
    private(set) var available: String?

    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: enabled, updaterDelegate: nil, userDriverDelegate: self)
        guard enabled else { return }
        canCheck = controller.updater.canCheckForUpdates
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheck = updater.canCheckForUpdates }
        }
    }

    /// Settings › General: check once a day in the background. Sparkle keeps it.
    var checksAutomatically: Bool {
        get {
            access(keyPath: \.checksAutomatically)
            return controller.updater.automaticallyChecksForUpdates
        }
        set {
            withMutation(keyPath: \.checksAutomatically) {
                controller.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    var lastCheck: Date? { controller.updater.lastUpdateCheckDate }

    /// Check for Updates…: Sparkle shows the result, even "You're up to date".
    func check() {
        guard enabled else { return }
        controller.checkForUpdates(nil)
    }

    // MARK: Gentle reminders
    // A menu bar app has no Dock icon to bounce. A background check shows its
    // alert behind other windows, so the popover's Settings button gets a dot until the person
    // looks at the update.

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                               forUpdate update: SUAppcastItem,
                                                               state: SPUUserUpdateState) {
        let version = update.displayVersionString
        let userInitiated = state.userInitiated
        MainActor.assumeIsolated {
            if !userInitiated { available = version }
        }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        MainActor.assumeIsolated { available = nil }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated { available = nil }
    }
}
