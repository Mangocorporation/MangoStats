import SwiftUI

/// Settings > Appearance: the accent color of the whole app (design/KIT.md). MangoStats
/// is always dark; the accent colors buttons, highlights, the memory bar, and links.
struct AppearanceSettings: View {
    @Bindable private var store = ThemeStore.shared

    var body: some View {
        Section {
            AccentPreview()
                .padding(.vertical, Space.xs)
            LabeledContent("Accent color") {
                VStack(alignment: .trailing, spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        ForEach(Theme.all) { theme in
                            AccentSwatch(theme: theme, selected: store.themeID == theme.id) {
                                store.themeID = theme.id
                            }
                        }
                    }
                    Text(store.theme.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("MangoStats always uses its dark look. The accent colors buttons, highlights, and the busiest process.")
                .foregroundStyle(.secondary)
        }
    }
}

/// The insight card and a process row in the chosen accent, drawn with the
/// design kit, so people see exactly what the setting changes.
private struct AccentPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Metric.cardGap - 4) {
            KitCard(height: nil, fitsContent: true, tinted: true, padding: Metric.cardPadding - 6) {
                Eyebrow(text: "Memory is tight", icon: .warning, color: Ink.accent)
                HStack(alignment: .center) {
                    Text("Google Chrome is holding 19,4 GB")
                        .kitType(.rowName)
                        .foregroundStyle(Ink.text)
                    Spacer()
                    Text("Review Chrome")
                        .kitType(.button)
                        .foregroundStyle(Ink.onAccent)
                        .padding(.horizontal, Metric.buttonPadding - 6)
                        .frame(height: Metric.buttonHeight - 10)
                        .background(Ink.accent, in: RoundedRectangle(cornerRadius: Metric.buttonRadius - 2, style: .continuous))
                }
                .padding(.top, Metric.iconGap)
                KitProgressBar(value: 0.86, height: Metric.cpuBar.height)
                    .padding(.top, Metric.cardGap - 4)
            }
        }
        .padding(Metric.cardGap - 4)
        .background(Ink.windowBackground, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the accent color")
    }
}

/// One color dot, like the accent row in System Settings.
private struct AccentSwatch: View {
    let theme: Theme
    let selected: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            Circle()
                .fill(fill)
                .frame(width: 16, height: 16)
                .overlay {
                    if selected {
                        Circle().fill(theme.onAccent).frame(width: 6, height: 6) // grid: ok
                    }
                }
                .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(theme.name)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fill: AnyShapeStyle {
        if let tint = theme.tint {
            AnyShapeStyle(tint)
        } else {
            AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                                          center: .center))
        }
    }
}
