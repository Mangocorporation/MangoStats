import AppKit
import SwiftUI
import MangoStatsKit

/// The first letter of a process on a tile: filled for apps, outlined and
/// monospaced for background processes (design/KIT.md, Avatar).
struct ProcessAvatar: View {
    let process: ProcessRowData

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metric.avatarRadius, style: .continuous)
        let letter = String(process.name.first ?? "?")
        Text(process.isApp ? letter.uppercased() : letter)
            .font(process.isApp ? .system(size: 13, weight: .semibold) : .system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(process.isApp ? Ink.text : Ink.secondary)
            .frame(width: Metric.avatar, height: Metric.avatar)
            .background(shape.fill(process.isApp ? Ink.pillFill : .clear))
            .overlay(shape.strokeBorder(process.isApp ? .clear : Ink.cardStroke, lineWidth: Metric.cardStroke))
            .accessibilityHidden(true)
    }
}

/// Column layout shared by the table header and rows.
enum ProcessColumns {
    static func cpu<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().frame(width: Metric.cpuBar.width + Metric.colCPUValue + Metric.cardGap, alignment: .leading)
    }
}

/// One process in the Overview table (design/KIT.md, Process row).
struct ProcessRow: View {
    let process: ProcessRowData
    /// The share of the busiest process, so the bars compare to each other.
    var cpuScale: Double = 100
    /// The top row by the current sort gets the accent (the reference's amber bar and memory).
    var highlightCPU = false
    var highlightMemory = false
    var menu: () -> AnyView = { AnyView(EmptyView()) }
    @State private var hovering = false
    @Environment(\.kitForcedState) private var forced

    var body: some View {
        let hover = hovering || forced == .hover
        HStack(spacing: 0) {
            HStack(spacing: Metric.cardGap - 4) {
                ProcessAvatar(process: process)
                VStack(alignment: .leading, spacing: 1) {
                    Text(process.name)
                        .kitType(.rowName)
                        .foregroundStyle(Ink.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(process.isApp ? "App" : "Background")
                        .kitType(.rowKind)
                        .foregroundStyle(Ink.secondary)
                }
                .help(process.name)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ProcessColumns.cpu {
                HStack(spacing: Metric.cardGap) {
                    KitProgressBar(value: process.cpu / max(cpuScale, 1),
                                   fill: highlightCPU || process.hot ? Ink.accent : Ink.secondary.opacity(0.6),
                                   height: Metric.cpuBar.height)
                        .frame(width: Metric.cpuBar.width)
                    Text(process.cpuText)
                        .frame(width: Metric.colCPUValue, alignment: .trailing)
                        .foregroundStyle(Ink.text)
                }
            }
            Text(process.memory)
                .frame(width: Metric.colMemory, alignment: .trailing)
                .foregroundStyle(highlightMemory ? Ink.accent : Ink.text)
                .fontWeight(highlightMemory ? .semibold : .regular)
            Text(process.power)
                .frame(width: Metric.colEnergy, alignment: .trailing)
                .foregroundStyle(Ink.secondary)
            Text(String(process.id))
                .frame(width: Metric.colPID, alignment: .trailing)
                .foregroundStyle(Ink.secondary)
            Menu { menu() } label: {
                KitIcon.more.view(size: 13, color: hover ? Ink.text : Ink.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(KitIconButtonStyle())
            .menuIndicator(.hidden)
            .help("More actions for \(process.name)")
            .frame(width: Metric.colMore)
        }
        .kitType(.rowNumber)
        .padding(.horizontal, Metric.tableInset)
        .frame(height: Metric.rowHeight)
        .background(hover ? Ink.rowHover : .clear)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.divider).frame(height: Metric.cardStroke) }
        .contentShape(Rectangle())
        .contextMenu { menu() }
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(process.name), \(process.isApp ? "app" : "background"), \(process.cpuText) percent CPU, \(process.memory)")
    }
}

/// One process in the popover: avatar, name, memory, % CPU, more.
struct PopoverProcessRow: View {
    let process: ProcessRowData
    var menu: () -> AnyView = { AnyView(EmptyView()) }

    var body: some View {
        HStack(spacing: Metric.cardGap - 6) {
            ProcessAvatar(process: process)
                .scaleEffect(0.75)
                .frame(width: Metric.avatar * 0.75, height: Metric.avatar * 0.75)
            Text(process.name)
                .kitType(.popRow)
                .foregroundStyle(Ink.text)
                .lineLimit(1)
                .help(process.name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(process.memory)
                .foregroundStyle(Ink.body)
                .frame(width: Metric.popColMemory, alignment: .trailing)
            Text(process.cpuText)
                .foregroundStyle(process.hot ? Ink.hot : Ink.body)
                .fontWeight(process.hot ? .semibold : .regular)
                .frame(width: Metric.colCPU, alignment: .trailing)
            Menu { menu() } label: { KitIcon.more.view(size: 12) }
                .menuStyle(.button)
                .buttonStyle(KitIconButtonStyle(size: Metric.compactSegmentHeight))
                .menuIndicator(.hidden)
                .help("More actions for \(process.name)")
        }
        .kitType(.popNumber)
        .frame(height: Metric.popRowHeight)
        .accessibilityElement(children: .combine)
    }
}
