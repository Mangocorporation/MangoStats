# MangoStats

A native macOS menu bar app in SwiftUI that shows live system stats (see
docs/BRIEF.md). No database: only settings, in UserDefaults. No server.
Shape: a `MenuBarExtra` (window style) with the popover, a Status window
(`Window` id "status", opened from the popover), and Settings.

## Layout

- `Sources/MangoStats/` the app. `App.swift` has the scenes; `Models.swift` has `AppModel` and `Store` (the settings domain).
- `Sources/MangoStatsKit/` rules and data logic with no SwiftUI. Tests in `Tests/MangoStatsKitTests/`.
- `Package.swift` a Swift package. There is no Xcode project.
- `build.sh` builds, signs, and installs `~/Applications/MangoStats.app`.
- `Icon/AppIcon.icon` the app icon, an Icon Composer file (JSON plus SVG layers). `build.sh` compiles it with `tools/make_icon.sh`; `tools/icon_review.sh` renders every look into one PNG.
- `docs/` the brief, stories, glossary, and reference screenshots (`local/reference/`).

## Build and check

- Build and install: `./build.sh`. Add `--open` to restart the app with the new build. The build shows warnings; fix them.
- Unit tests: `swift test --scratch-path ~/Library/Developer/MangoStats/test-build`.
- Self-test (the app's real functions with throwaway settings): `tools/selftest.sh`. Exit 0 when every check passes. Add a check for every story with logic in `SelfTest.swift`.
- After every UI change, take snapshots with sample data and look at them: `tools/snap.sh`.
  It writes `/tmp/MangoStats-shots/popover-*.png` (the menu bar popover in a stand-in panel), `status-*.png`, and `settings-<tab>-*.png`, light and dark, then quits. `APP_SNAPSHOT_PAGES=popover,settings tools/snap.sh` limits the pages.
- Snapshots and the self-test refuse to run without `APP_STORE`; with it, settings go to the throwaway `com.mangocorp.mangostats.test` domain. Never change the real settings in tests.
- Then check the grid: `tools/grid-lint.sh` and `swift tools/check-layout.swift /tmp/MangoStats-shots/*-layout.json`. Both print PASS.
- A change is done when the build has no errors, the grid checks pass, and you looked at the light and dark snapshots.

## Design rules

- Use Apple's controls and system styles. Only the accent color is custom: `UI/Theme.swift` (`ThemeStore.defaultID`). People change it, and light or dark mode, in Settings > Appearance.
- Views use `.tint`, `Palette.accent`, `Palette.accentText` (accent-colored text), and `Palette.onAccent` (text on an accent fill). Never hard-code colors, radii, or durations in views.
- Compare accents: add `APP_ACCENT=<id>` to the snapshot command.
- Spacing comes from `Space` in `UI/Grid.swift`, on a 4 pt grid. Mark custom pages and cards with `.gridArea` and `.gridProbe`.
- Windows open calm: `.noInitialFocus()` on every window and sheet (no focus ring or selected text on open), `.fitsContent()` on sheets and Settings tabs (no scroll bar with nothing to scroll). System scroll bars. Both in `UI/WindowBehavior.swift`.
- Settings: one tab per topic in `SettingsView.swift`, one grouped Form per tab. Add a case to `SettingsTab` for a new tab.
- Window chrome (title bar, toolbar, sidebar, menus, sheets) stays system. Buttons use system styles, like `.borderedProminent`.
- Colors: `.primary`, `.secondary`, `.tint`, and system colors. Never fixed grays or white for text.
- Every action has a menu bar item and a keyboard shortcut.
- `Label` for icon and text pairs. SF Symbols for icons.
- `ContentUnavailableView` for empty states.
- Liquid Glass belongs to floating controls only, never to content.

## Skills

The bama plugin has a skill for each step: `mac-design` (design rules),
`design-system` (accent and tokens), `layout-grid`, `ux-design`,
`swift-swiftui`, `os-integrations`, `performance`, `build-and-verify`,
`test-mac-app`, `app-icon`, `user-stories`, and `improve-loop`. Use them.

## Git

- Commit after each working change, with a message that says what the user can now do.
