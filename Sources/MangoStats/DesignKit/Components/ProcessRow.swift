import AppKit
import SwiftUI
import MangoStatsKit

/// One process in the Status window table.
struct ProcessRow: View {
    let process: ProcessRowData
    var menu: () -> AnyView = { AnyView(EmptyView()) }
    @State private var hovering = false
    @Environment(\.kitForcedState) private var forced

    var body: some View {
        let hover = hovering || forced == .hover
        HStack(spacing: 0) {
            Capsule()
                .fill(process.hot ? Ink.hot : .clear)
                .frame(width: Metric.hotMarker.width, height: Metric.hotMarker.height)
            AppIcon(path: process.bundlePath)
                .padding(.leading, Metric.iconGap * 2)
            Text(process.name)
                .kitType(.row)
                .foregroundStyle(Ink.text)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(process.name)
                .padding(.leading, Metric.iconGap + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                Text(process.memory).frame(width: Metric.colMemory, alignment: .trailing)
                    .foregroundStyle(Ink.label)
                Spacer().frame(width: Metric.colMemoryGap)
                MiniBar(value: process.cpu / 100, hot: process.hot)
                Text(process.cpuText).frame(width: Metric.colCPU, alignment: .trailing)
                    .foregroundStyle(process.hot ? Ink.hot : Ink.label)
                Text(process.power).frame(width: Metric.colPower, alignment: .trailing)
                    .foregroundStyle(process.hot ? Ink.hot : Ink.label)
                Text(String(process.id)).frame(width: Metric.colPID, alignment: .trailing)
                    .foregroundStyle(Ink.tertiary)
            }
            .kitType(.rowNumber)
            Menu {
                menu()
            } label: {
                KitIcon.more.view(size: 12, color: hover ? Ink.text : Ink.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(KitIconButtonStyle())
            .menuIndicator(.hidden)
            .help("More actions for \(process.name)")
            .frame(width: Metric.colMore)
        }
        .frame(height: Metric.rowHeight)
        .background(hover ? Ink.rowHover : .clear)
        .contentShape(Rectangle())
        .contextMenu { menu() }
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hover)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(process.name), \(process.memory), \(process.cpuText) percent CPU")
    }
}

/// One process in the popover: name, memory, % CPU, more.
struct PopoverProcessRow: View {
    let process: ProcessRowData
    var menu: () -> AnyView = { AnyView(EmptyView()) }

    var body: some View {
        HStack(spacing: Metric.cardPadding) {
            Text(process.name)
                .kitType(.row)
                .foregroundStyle(Ink.text)
                .lineLimit(1)
                .help(process.name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(process.memory)
                .foregroundStyle(Ink.label)
                .frame(width: Metric.popColMemory, alignment: .trailing)
            Text(process.cpuText)
                .foregroundStyle(process.hot ? Ink.hot : Ink.label)
                .fontWeight(process.hot ? .semibold : .regular)
                .frame(width: Metric.colCPU, alignment: .trailing)
            Menu { menu() } label: { KitIcon.more.view(size: 12) }
                .menuStyle(.button)
                .buttonStyle(KitIconButtonStyle())
                .menuIndicator(.hidden)
                .help("More actions for \(process.name)")
        }
        .kitType(.rowNumber)
        .frame(height: Metric.popRowHeight)
        .accessibilityElement(children: .combine)
    }
}

/// Column titles above the popover's process rows.
struct PopoverProcessHeader: View {
    var body: some View {
        HStack(spacing: Metric.cardPadding) {
            Text("Top Processes").frame(maxWidth: .infinity, alignment: .leading)
            Text("Memory").frame(width: Metric.popColMemory, alignment: .trailing)
            Text("% CPU").fixedSize().frame(width: Metric.colCPU, alignment: .trailing)
            Spacer().frame(width: Metric.segmentHeight)
        }
        .kitType(.popHeader)
        .foregroundStyle(Ink.label)
    }
}

/// The process's app icon, or a generic one.
struct AppIcon: View {
    let path: String?

    var body: some View {
        Image(nsImage: path.map { NSWorkspace.shared.icon(forFile: $0) }
              ?? NSWorkspace.shared.icon(for: .unixExecutable))
            .resizable()
            .frame(width: Metric.appIcon, height: Metric.appIcon)
            .accessibilityHidden(true)
    }
}
