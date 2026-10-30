import Combine
import ServiceManagement
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
            case .alerts: AlertSettingsView()
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
    case general, menuBar, alerts, appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .menuBar: "Menu Bar"
        case .alerts: "Alerts"
        case .appearance: "Appearance"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .menuBar: "menubar.rectangle"
        case .alerts: "bell.badge"
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
        FanControlSection()
        HistorySection()
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

/// Settings → Alerts: the master switch, permission, and one row per rule (S-031, S-034).
struct AlertSettingsView: View {
    @Environment(AppModel.self) private var model
    private var notifier = Notifier.shared
    private let timer = Timer.publish(every: 2, tolerance: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var model = model
        Section {
            Toggle("Show alerts", isOn: Binding(get: { model.alerts.showAlerts }, set: { on in
                model.alerts.showAlerts = on
                if on { notifier.requestPermission() }
            }))
            if model.alerts.showAlerts && notifier.permission == .denied {
                HStack {
                    Text("Notifications are off for MangoStats.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Notification Settings…") { Notifier.openNotificationSettings() }
                }
            } else if model.alerts.showAlerts {
                HStack {
                    Spacer()
                    Button("Send Test Alert") { notifier.sendTest() }
                }
            }
        }
        Section {
            ForEach(AlertKind.allCases) { kind in
                AlertRuleRow(kind: kind)
            }
        } footer: {
            Text("Each alert shows once, then waits until the problem clears. At most every 30 minutes.")
                .foregroundStyle(.secondary)
        }
        .disabled(!model.alerts.showAlerts)
        // People allow notifications in System Settings; check again while this tab is open.
        .onReceive(timer) { _ in notifier.refresh() }
    }
}

private struct AlertRuleRow: View {
    @Environment(AppModel.self) private var model
    let kind: AlertKind

    var body: some View {
        let on = model.alerts.enabled.contains(kind)
        HStack {
            Text(kind.title)
            Spacer()
            if !kind.choices.isEmpty {
                Picker(kind.title, selection: Binding(get: { model.alerts.threshold(kind) },
                                                      set: { model.alerts.thresholds[kind] = $0 })) {
                    ForEach(kind.choices, id: \.self) { Text(kind.label($0)).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .disabled(!on)
            }
            Toggle(kind.title, isOn: Binding(get: { on }, set: { enabled in
                if enabled { model.alerts.enabled.insert(kind) } else { model.alerts.enabled.remove(kind) }
            }))
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }
}

/// History: how long it's kept, and Clear History… (S-030).
struct HistorySection: View {
    @Environment(AppModel.self) private var model
    @State private var confirmClear = false

    var body: some View {
        @Bindable var model = model
        Section {
            Picker("Keep history for", selection: $model.historyDays) {
                ForEach(HistoryRetention.choices, id: \.self) { Text("\($0) days").tag($0) }
            }
            HStack {
                Spacer()
                Button("Clear History…") { confirmClear = true }
            }
        } header: {
            Text("History")
        } footer: {
            Text("Stored only on this Mac, about 1 MB per week.").foregroundStyle(.secondary)
        }
        .confirmationDialog("Clear History?", isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) { Task { await HistoryStore.shared.clear() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All recorded stats will be deleted. This can't be undone.")
        }
    }
}

/// Fan control: install, approve, or remove the helper (S-024).
struct FanControlSection: View {
    private var fan = FanControl.shared
    private let timer = Timer.publish(every: 2, tolerance: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Section("Fan control") {
            Text(message).foregroundStyle(.secondary)
            if let error = fan.error {
                Text(error).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                switch fan.state {
                case .off: Button("Allow Fan Control…") { fan.enable() }
                case .needsApproval: Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                case .on: Button("Turn Off Fan Control") { fan.disable() }
                }
            }
        }
        // The user approves in System Settings; nothing calls back, so check while the tab is open.
        .onReceive(timer) { _ in fan.refresh() }
    }

    private var message: String {
        switch fan.state {
        case .off: "Fan control is off. Cool and Max need a helper that runs as root."
        case .needsApproval: "Allow MangoStats in System Settings > General > Login Items."
        case .on: "The helper can set the fan. It returns to Auto when MangoStats quits."
        }
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
