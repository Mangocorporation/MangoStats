import SwiftUI

/// Circle button with a progress ring, for the battery card (design/KIT.md, Ring button).
struct RingButtonStyle: ButtonStyle {
    var progress: Double = 1

    func makeBody(configuration: Configuration) -> some View {
        RingBody(configuration: configuration, progress: progress)
    }

    private struct RingBody: View {
        let configuration: Configuration
        let progress: Double
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.kitForcedState) private var forced

        var body: some View {
            let pressed = configuration.isPressed || forced == .pressed
            let hover = hovering || forced == .hover
            configuration.label
                .labelStyle(.iconOnly)
                .font(.system(size: Metric.iconSize))
                .foregroundStyle(Ink.secondary)
                .frame(width: Metric.ringSize, height: Metric.ringSize)
                .background(Circle().fill(pressed ? Ink.controlPressed : hover ? Ink.controlHover : .clear))
                .overlay(Circle().stroke(Ink.track, lineWidth: Metric.ringStroke).padding(Metric.ringStroke / 2))
                .overlay(
                    Circle().trim(from: 0, to: progress)
                        .stroke(Ink.battery, style: StrokeStyle(lineWidth: Metric.ringStroke, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(Metric.ringStroke / 2)
                )
                .contentShape(Circle())
                .opacity(isEnabled && forced != .disabled ? 1 : 0.5)
                .onHover { hovering = $0 }
                .animation(Motion.hover, value: hover)
        }
    }
}

/// Capsule segment for the fan modes (design/KIT.md, Segment button).
struct SegmentButtonStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        SegmentBody(configuration: configuration, selected: selected)
    }

    private struct SegmentBody: View {
        let configuration: Configuration
        let selected: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.kitForcedState) private var forced

        var body: some View {
            let pressed = configuration.isPressed || forced == .pressed
            let hover = hovering || forced == .hover
            let enabled = isEnabled && forced != .disabled
            configuration.label
                .kitType(.segment)
                .foregroundStyle(selected ? Ink.text : Ink.secondary)
                .padding(.horizontal, Metric.segmentPadding)
                .frame(height: Metric.segmentHeight)
                .background(Capsule().fill(fill(pressed: pressed, hover: hover && enabled)))
                .contentShape(Capsule())
                .opacity(enabled || selected ? 1 : 0.5)
                .onHover { hovering = $0 }
                .animation(Motion.hover, value: hover)
        }

        private func fill(pressed: Bool, hover: Bool) -> Color {
            if selected { return Ink.selectedSegment }
            if pressed { return Ink.controlPressed }
            return hover ? Ink.controlHover : Ink.controlFill
        }
    }
}

/// Icon-only button: the row's "more" button, the table's search, the popover footer.
struct KitIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        IconBody(configuration: configuration)
    }

    private struct IconBody: View {
        let configuration: Configuration
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.kitForcedState) private var forced

        var body: some View {
            let pressed = configuration.isPressed || forced == .pressed
            let hover = hovering || forced == .hover
            configuration.label
                .labelStyle(.iconOnly)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hover ? Ink.text : Ink.secondary)
                .frame(width: Metric.segmentHeight, height: Metric.segmentHeight)
                .background(RoundedRectangle(cornerRadius: Metric.pillRadius, style: .continuous)
                    .fill(pressed ? Ink.controlPressed : hover ? Ink.controlHover : .clear))
                .contentShape(Rectangle())
                .opacity(isEnabled && forced != .disabled ? 1 : 0.4)
                .onHover { hovering = $0 }
                .animation(Motion.hover, value: hover)
        }
    }
}
