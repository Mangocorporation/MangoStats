import SwiftUI
import MangoStatsKit

/// The Settings window (Command-Comma). One tab per topic, at most about
/// six. Each tab is a grouped Form that sizes to its content, so the
/// window grows to fit and shows no scroll bar it does not need.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.settingsTab) {
            ForEach(SettingsTab.allCases) { tab in
                page(tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
        .noInitialFocus()
    }

    @ViewBuilder
    private func page(_ tab: SettingsTab) -> some View {
        Form {
            switch tab {
            case .general: GeneralSettings()
            case .menuBar: MenuBarSettings()
            case .appearance: AppearanceSettings()
            }
        }
        .formStyle(.grouped)
        .fitsContent()
        .frame(width: 520)
    }
}

/// The Settings tabs. Snapshot mode walks through every case.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, menuBar, appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .menuBar: "Menu Bar"
        case .appearance: "Appearance"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .menuBar: "menubar.rectangle"
        case .appearance: "paintpalette"
        }
    }
}

/// Settings > General: open at login (S-020) and refresh interval (S-021).
struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @State private var openAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        @Bindable var model = model
        Section("Startup") {
            Toggle("Open at login", isOn: Binding(get: { openAtLogin }, set: { setOpenAtLogin($0) }))
            if let loginError {
                Text(loginError).foregroundStyle(.red)
            } else if LoginItem.needsApproval {
                Text("Allow MangoStats in System Settings > General > Login Items.")
                    .foregroundStyle(.secondary)
            }
        }
        Section {
            Picker("Refresh every", selection: $model.refreshInterval) {
                ForEach(SampleSchedule.intervals, id: \.self) { seconds in
                    Text(seconds == 1 ? "1 second" : "\(seconds) seconds").tag(seconds)
                }
            }
        } footer: {
            Text("The process list refreshes at most every 2 seconds, to save energy.")
                .foregroundStyle(.secondary)
        }
        // The toggle follows changes made in System Settings.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            openAtLogin = LoginItem.isEnabled
        }
    }

    private func setOpenAtLogin(_ on: Bool) {
        do {
            try LoginItem.set(on)
            loginError = nil
        } catch {
            loginError = "Unable to change the login item: \(error.localizedDescription)"
        }
        openAtLogin = LoginItem.isEnabled
    }
}

/// Settings > Menu Bar: which stats show, in what order (S-009).
/// Changes apply at once; there is no Save button.
struct MenuBarSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Section("Preview") {
            HStack {
                Spacer()
                if model.shownStats.isEmpty {
                    KitIcon.chart.image
                } else {
                    MenuBarStatsRow(stats: model.shownStats, values: model.menuValues, style: model.menuBarStyle)
                        .foregroundStyle(.primary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(MenuBarImage.spoken(stats: model.shownStats, values: model.menuValues))
        }
        Section {
            ForEach(model.menuBar.order) { stat in
                StatToggle(stat: stat)
                    .contextMenu {
                        Button("Move Up") { move(stat, by: -1) }
                            .disabled(model.menuBar.order.first == stat)
                        Button("Move Down") { move(stat, by: 1) }
                            .disabled(model.menuBar.order.last == stat)
                    }
            }
            .onMove { model.menuBar.move(fromOffsets: $0, toOffset: $1) }
        } header: {
            Text("Show in Menu Bar")
        } footer: {
            Text(model.shownStats.isEmpty
                 ? "The menu bar shows the MangoStats icon when no stats are on."
                 : "Drag stats to change their order, or Control-click one to move it.")
                .foregroundStyle(.secondary)
        }
        Section {
            Picker("Menu bar style", selection: $model.menuBarStyle) {
                ForEach(MenuBarStyle.allCases) { Text($0.title).tag($0) }
            }
        }
    }

    private func move(_ stat: MenuBarStat, by step: Int) {
        guard let index = model.menuBar.order.firstIndex(of: stat) else { return }
        let target = index + step
        guard model.menuBar.order.indices.contains(target) else { return }
        model.menuBar.move(fromOffsets: IndexSet(integer: index), toOffset: step > 0 ? target + 1 : target)
    }
}

/// One stat's switch. Stats this Mac can't show yet are listed but off.
private struct StatToggle: View {
    @Environment(AppModel.self) private var model
    let stat: MenuBarStat

    var body: some View {
        let available = model.isAvailable(stat)
        Toggle(isOn: Binding(get: { available && model.menuBar.enabled.contains(stat) },
                             set: { model.setShown(stat, $0) })) {
            Label {
                Text(stat.title)
                if !available {
                    Text(model.unavailableReason(stat))
                }
            } icon: {
                stat.icon.image.frame(width: Space.xl)
            }
        }
        .disabled(!available)
        .accessibilityLabel("Show \(stat.title) in menu bar")
    }
}
