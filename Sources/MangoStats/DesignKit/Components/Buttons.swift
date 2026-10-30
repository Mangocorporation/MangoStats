import SwiftUI
import MangoStatsKit

/// Filled accent button: "Review Chrome" (design/KIT.md, Buttons).
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.kitForcedState) private var forced

        var body: some View {
            let pressed = configuration.isPressed || forced == .pressed
            configuration.label
                .kitType(.button)
                .foregroundStyle(Ink.onAccent)
                .padding(.horizontal, Metric.buttonPadding)
                .frame(height: Metric.buttonHeight)
                .background(RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                    .fill(Ink.accent.opacity(pressed ? 0.8 : (hovering || forced == .hover) ? 0.92 : 1)))
                .contentShape(Rectangle())
                .opacity(isEnabled && forced != .disabled ? 1 : 0.45)
                .onHover { hovering = $0 }
        }
    }
}

/// Outlined button: "Dismiss", "See what's using space".
struct SecondaryButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, compact: compact)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        let compact: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.kitForcedState) private var forced

        var body: some View {
            let pressed = configuration.isPressed || forced == .pressed
            let hover = hovering || forced == .hover
            let shape = RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
            configuration.label
                .kitType(compact ? .segment : .button)
                .foregroundStyle(Ink.text)
                .padding(.horizontal, compact ? Metric.segmentPadding : Metric.buttonPadding)
                .frame(height: compact ? Metric.segmentHeight : Metric.buttonHeight)
                .background(shape.fill(pressed ? Ink.controlPressed : hover ? Ink.controlHover : .clear))
                .overlay(shape.strokeBorder(Ink.cardStroke, lineWidth: Metric.cardStroke))
                .contentShape(shape)
                .opacity(isEnabled && forced != .disabled ? 1 : 0.45)
                .onHover { hovering = $0 }
        }
    }
}

/// Square icon button: the header's Settings button, a row's "…".
struct KitIconButtonStyle: ButtonStyle {
    var size: CGFloat = Metric.smallIconButton
    var outlined = false

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, size: size, outlined: outlined)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        let size: CGFloat
        let outlined: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.kitForcedState) private var forced

        var body: some View {
            let pressed = configuration.isPressed || forced == .pressed
            let hover = hovering || forced == .hover
            let shape = RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
            configuration.label
                .labelStyle(.iconOnly)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hover ? Ink.text : Ink.secondary)
                .frame(width: size, height: size)
                .background(shape.fill(pressed ? Ink.controlPressed : hover ? Ink.controlHover : .clear))
                .overlay(shape.strokeBorder(outlined ? Ink.cardStroke : .clear, lineWidth: Metric.cardStroke))
                .contentShape(shape)
                .opacity(isEnabled && forced != .disabled ? 1 : 0.4)
                .onHover { hovering = $0 }
        }
    }
}

/// A chip in a segmented control or a range picker (design/KIT.md, Segmented control).
struct SegmentButtonStyle: ButtonStyle {
    var selected = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, selected: selected, compact: compact)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        let selected: Bool
        let compact: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.kitForcedState) private var forced

        var body: some View {
            let pressed = configuration.isPressed || forced == .pressed
            let hover = (hovering || forced == .hover) && !selected
            let enabled = isEnabled && forced != .disabled
            configuration.label
                .kitType(.segment)
                .foregroundStyle(selected ? Ink.text : Ink.secondary)
                .padding(.horizontal, compact ? Metric.compactSegmentPadding : Metric.segmentPadding)
                .frame(height: compact ? Metric.compactSegmentHeight : Metric.segmentHeight - Metric.segmentInset * 2)
                .background(RoundedRectangle(cornerRadius: Metric.segmentRadius - Metric.segmentInset, style: .continuous)
                    .fill(selected ? Ink.selectedSegment : pressed ? Ink.controlPressed : hover ? Ink.controlHover : .clear))
                .contentShape(Rectangle())
                .opacity(enabled || selected ? 1 : 0.45)
                .onHover { hovering = $0 }
        }
    }
}

/// Chips in a bordered track: "All | Apps | Background", "CPU | Memory".
struct KitSegmented<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var help: (Option) -> String = { _ in "" }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button(L10n.t(title(option))) { selection = option }
                    .buttonStyle(SegmentButtonStyle(selected: option == selection))
                    .help(help(option))
                    .accessibilityAddTraits(option == selection ? .isSelected : [])
            }
        }
        .padding(Metric.segmentInset)
        .background(RoundedRectangle(cornerRadius: Metric.segmentRadius, style: .continuous).fill(Ink.windowBackground))
        .overlay(RoundedRectangle(cornerRadius: Metric.segmentRadius, style: .continuous)
            .strokeBorder(Ink.cardStroke, lineWidth: Metric.cardStroke))
    }
}

/// A text link in the accent color: "Show all 541".
struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .kitType(.footer)
            .underline()
            .foregroundStyle(Ink.accent.opacity(configuration.isPressed ? 0.7 : 1))
            .contentShape(Rectangle())
    }
}
