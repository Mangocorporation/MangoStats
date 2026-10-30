import AppKit
import IOKit.pwr_mgt
import SwiftUI
import MangoStatsKit

/// Screenshot mode for agents.
///   APP_STORE=/tmp/test.store APP_SNAPSHOT=/tmp/shots ~/Applications/MangoStats.app/Contents/MacOS/MangoStats
/// writes popover-light.png and popover-dark.png (the menu bar popover in a
/// stand-in window), <page>-light.png and <page>-dark.png for every Status page, and
/// settings-<tab>-light.png and settings-<tab>-dark.png for every Settings tab, then quits.
/// Each PNG gets a <page>-<mode>-layout.json with the grid probes (tools/check-layout.swift).
/// APP_SNAPSHOT_PAGES=popover,status limits the pages. Add "settings" to include Settings.
/// Add APP_ACCENT=<id> to see the pages in another accent.
enum Snapshot {
    static func runIfRequested(model: AppModel, openSettings: OpenSettingsAction) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["APP_SNAPSHOT"], !dir.isEmpty else { return }
        // Snapshots never run against the real database.
        guard Store.isOverridden else {
            print("SNAPSHOT refused: set APP_STORE to a path in /tmp")
            NSApp.terminate(nil)
            return
        }
        let only = env["APP_SNAPSHOT_PAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        Task {
            // A sleeping display gives screencapture nothing. Declaring user
            // activity wakes it; the assertion keeps it on until the run quits.
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            var awake: IOPMAssertionID = 0
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn), "Snapshots" as CFString, &awake)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(1.5))
            let main = NSApp.windows.first { $0.canBecomeMain && !$0.isSheet }
            if only == nil || only?.contains("popover") == true {
                // MenuBarExtra windows open only on a click, so draw the same view in a stand-in panel.
                let panel = NSPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
                panel.contentView = NSHostingView(rootView: PopoverView().environment(model).themed())
                panel.backgroundColor = .windowBackgroundColor
                panel.setContentSize(panel.contentView?.fittingSize ?? .zero)
                panel.center()
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    panel.orderFrontRegardless()
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/popover-\(mode).png", window: panel)
                }
                panel.close()
            }
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                for page in Page.allCases where only?.contains(page.rawValue) ?? true {
                    model.page = page
                    // The Network tab measures live: give it a few rounds of pings and the slow checks.
                    try? await Task.sleep(for: .seconds(page == .network ? 8 : 0.8))
                    capture(to: "\(dir)/\(page.rawValue)-\(mode).png", window: main)
                }
            }
            // Process table states (S-012, S-013), dark only: the window is always dark.
            if only == nil || only?.contains("table") == true {
                NSApp.appearance = NSAppearance(named: .darkAqua)
                model.processSort = ProcessSort(column: .cpu, descending: true)
                try? await Task.sleep(for: .seconds(0.8))
                capture(to: "\(dir)/status-sorted-dark.png", window: main)
                model.processSort = .default
                model.processQuery = "chrome"
                try? await Task.sleep(for: .seconds(0.8))
                capture(to: "\(dir)/status-search-dark.png", window: main)
                model.processQuery = "zzz"
                try? await Task.sleep(for: .seconds(0.8))
                capture(to: "\(dir)/status-nomatch-dark.png", window: main)
                model.processQuery = ""
            }
            if only == nil || only?.contains("settings") == true {
                NSApp.activate(); openSettings()
                try? await Task.sleep(for: .seconds(1))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    for tab in SettingsTab.allCases {
                        model.settingsTab = tab
                        try? await Task.sleep(for: .seconds(0.8))
                        let settings = NSApp.windows.first { $0.isVisible && ($0.identifier?.rawValue ?? "").localizedCaseInsensitiveContains("settings") } ?? NSApp.windows.first { $0.isVisible && $0 !== main && $0.canBecomeMain }
                        capture(to: "\(dir)/settings-\(tab.rawValue)-\(mode).png", window: settings)
                    }
                }
            }
            print("SNAPSHOT done \(dir)")
            // An open sheet refuses terminate, and the run would wait forever.
            for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
            NSApp.terminate(nil)
        }
    }

    /// Captures the real window with screencapture, so glass, sidebars, and
    /// materials look exactly as on screen. That needs Screen Recording
    /// permission for the app that started this one (your terminal, or Claude).
    /// Without it, falls back to drawing the view hierarchy, which leaves
    /// sidebars and glass blank.
    private static func capture(to path: String, window: NSWindow? = nil) {
        // Another app can hide this one while snapshots run (computer use hides
        // apps it does not control). Hidden windows cannot be captured.
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        guard let window = window ?? NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) else {
            print("SNAPSHOT no window")
            return
        }
        // Active, like a window someone is using: real accent colors and focus rings.
        NSApp.activate()
        if window.canBecomeKey { window.makeKeyAndOrderFront(nil) } else { window.orderFrontRegardless() }
        let size = window.contentView?.bounds.size ?? .zero
        GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"), window: size)
        try? FileManager.default.removeItem(atPath: path)
        // The first capture of a run sometimes misses the window. Try three times.
        for _ in 1...3 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            try? shot.run()
            shot.waitUntilExit()
            if FileManager.default.fileExists(atPath: path) {
                print("SNAPSHOT \(path)")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path) (fallback: no Screen Recording permission, sidebars and glass are blank)")
        }
    }
}
