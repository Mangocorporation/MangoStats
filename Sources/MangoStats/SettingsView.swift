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

/// Launch at login (S-020) and refresh interval (S-021) arrive here.
struct GeneralSettings: View {
    var body: some View {
        Section("Startup") {
            LabeledContent("Open at login", value: "Coming soon")
        }
    }
}

/// Settings > Menu Bar: which stats show, in what order (S-009, finished in its story).
struct MenuBarSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Section("Show in Menu Bar") {
            ForEach(model.menuBar.order) { stat in
                Toggle(isOn: Binding(get: { model.menuBar.enabled.contains(stat) },
                                     set: { model.setShown(stat, $0) })) {
                    Label(stat.title, systemImage: stat.symbol)
                }
                .accessibilityLabel("Show \(stat.title) in menu bar")
            }
            .onMove { model.menuBar.move(fromOffsets: $0, toOffset: $1) }
        }
        Section {
            Picker("Menu bar style", selection: $model.menuBarStyle) {
                ForEach(MenuBarStyle.allCases) { Text($0.title).tag($0) }
            }
        }
    }
}
