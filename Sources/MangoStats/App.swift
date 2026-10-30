import AppKit
import SwiftUI

// MangoStats
//   MangoStats                      the app: a menu bar item, the Status window, and Settings
//   APP_STORE=<file> MangoStats     test run: settings go to a throwaway defaults domain
//   APP_SNAPSHOT=<dir> MangoStats   save a PNG of the popover, every Status page, and every Settings tab in light and dark mode, then quit
//   MangoStats --selftest           run the self-test and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> MangoStats      run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 MangoStats           draw the grid and the layout probes over the window

@main
struct MangoStatsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    /// Snapshot and self-test runs open the Status window, which starts them.
    private static var automated: Bool {
        SelfTest.requested || !(ProcessInfo.processInfo.environment["APP_SNAPSHOT"] ?? "").isEmpty
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(model)
                .themed()
        } label: {
            MenuBarLabel()
                .environment(model)
        }
        .menuBarExtraStyle(.window)

        Window("MangoStats", id: "status") {
            StatusView()
                .environment(model)
                .themed()
                .overlay { if GridOverlay.enabled { GridOverlay() } }
                .frame(minWidth: 960, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 760)
        .defaultLaunchBehavior(Self.automated ? .presented : .suppressed)

        Settings {
            SettingsView()
                .environment(model)
                .themed()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu bar app: no Dock icon, no app menu (LSUIElement in Info.plist).
        NSApp.setActivationPolicy(.accessory)
    }

    /// Closing the Status window keeps the menu bar item running.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}
