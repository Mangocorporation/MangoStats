import SwiftUI
import MangoStatsKit

/// The Overview's Processes card: All / Apps / Background, CPU / Memory,
/// a filter, the top 13, and Show all (S-011 to S-014, S-038).
struct ProcessTableView: View {
    @Environment(AppModel.self) private var model
    let data: StatusData
    @FocusState private var filterFocused: Bool
    /// The process waiting for Force Quit confirmation.
    @State private var forceQuitTarget: ProcessRowData?

    var body: some View {
        @Bindable var model = model
        let kind = data.processes.filter(model.processKind.includes)
        let filtered = ProcessTable.filter(kind, query: model.processQuery)
        let sorted = ProcessTable.sort(filtered, by: model.processSort)
        let filtering = !model.processQuery.isEmpty
        let rows = model.showAllProcesses || filtering ? sorted : Array(sorted.prefix(Metric.topProcesses))
        let scale = max(sorted.map(\.cpu).max() ?? 100, 100)
        let topMemory = data.processes.max { $0.memoryBytes < $1.memoryBytes }?.id
        VStack(spacing: 0) {
            toolbar(running: data.processCount)
            columnHeader
            if data.processes.isEmpty {
                message("Reading processes…")
            } else if rows.isEmpty {
                message("No processes match \u{201C}\(model.processQuery)\u{201D}")
            }
            LazyVStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, process in
                    ProcessRow(process: process, cpuScale: scale,
                               highlightCPU: index == 0 && model.processSort.column == .cpu,
                               highlightMemory: process.id == topMemory && process.memoryBytes > 4 << 30) {
                        AnyView(ProcessMenu(process: process) { forceQuitTarget = process })
                    }
                }
            }
            footer(shown: rows.count, total: sorted.count, filtering: filtering)
        }
        .background(Ink.cardFill, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
            .strokeBorder(Ink.cardStroke, lineWidth: Metric.cardStroke))
        .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        .confirmationDialog("Force Quit \(forceQuitTarget?.name ?? "")?",
                            isPresented: Binding(get: { forceQuitTarget != nil }, set: { if !$0 { forceQuitTarget = nil } }),
                            presenting: forceQuitTarget) { process in
            Button("Force Quit", role: .destructive) { ProcessActions.forceQuit(process.id) }
            Button("Cancel", role: .cancel) {}
        } message: { process in
            Text("Unsaved changes in \(process.name) will be lost.")
        }
    }

    private func toolbar(running: Int) -> some View {
        @Bindable var model = model
        return HStack(spacing: Metric.cardGap - 4) {
            HStack(alignment: .firstTextBaseline, spacing: Metric.cardGap - 6) {
                Text("Processes").kitType(.sectionTitle).foregroundStyle(Ink.text)
                Text("\(running) running").kitType(.mono).foregroundStyle(Ink.secondary)
            }
            Spacer()
            KitSegmented(options: ProcessKind.allCases, selection: $model.processKind, title: \.title,
                         help: { "Show \($0 == .all ? "every process" : $0.title.lowercased())" })
            KitSegmented(options: [ProcessColumn.cpu, .memory],
                         selection: Binding(get: { model.processSort.column == .memory ? .memory : .cpu },
                                            set: { model.processSort = ProcessSort(column: $0, descending: true) }),
                         title: { $0 == .cpu ? "CPU" : "Memory" },
                         help: { "Sort by \($0 == .cpu ? "CPU" : "memory")" })
            KitSearchField(text: $model.processQuery, prompt: "Filter", focused: $filterFocused) {
                model.processQuery = ""
                filterFocused = false
            }
            .accessibilityLabel("Filter processes by name or PID")
            // ⌘F focuses the filter.
            Button("Filter Processes") { filterFocused = true }
                .keyboardShortcut("f")
                .hidden()
                .frame(width: 0, height: 0)
        }
        .padding(.horizontal, Metric.tableInset)
        .padding(.vertical, Metric.cardGap)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.divider).frame(height: Metric.cardStroke) }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            sortButton("Name", .name)
                .frame(maxWidth: .infinity, alignment: .leading)
            ProcessColumns.cpu { sortButton("CPU", .cpu) }
            sortButton("Memory", .memory).frame(width: Metric.colMemory, alignment: .trailing)
            sortButton("Energy", .power).frame(width: Metric.colEnergy, alignment: .trailing)
                .help("Power in watts. – for processes of other users.")
            sortButton("PID", .pid).frame(width: Metric.colPID, alignment: .trailing)
            Spacer().frame(width: Metric.colMore)
        }
        .padding(.horizontal, Metric.tableInset)
        .frame(height: Metric.tableHeaderHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.divider).frame(height: Metric.cardStroke) }
    }

    private func sortButton(_ title: String, _ column: ProcessColumn) -> some View {
        let active = model.processSort.column == column
        return Button(title) { model.processSort.select(column) }
            .buttonStyle(ColumnHeaderButtonStyle(active: active, descending: model.processSort.descending))
            .help("Sort by \(title.lowercased())")
            .accessibilityValue(active ? (model.processSort.descending ? "sorted descending" : "sorted ascending") : "")
    }

    private func footer(shown: Int, total: Int, filtering: Bool) -> some View {
        @Bindable var model = model
        let by = model.processSort.column == .memory ? "memory" : model.processSort.column == .cpu ? "CPU" : model.processSort.column.rawValue
        return HStack {
            Text(filtering ? "\(shown) matching" : model.showAllProcesses ? "Showing all \(total)" : "Showing top \(shown) by \(by)")
                .kitType(.footer)
                .foregroundStyle(Ink.secondary)
            Spacer()
            if !filtering && total > Metric.topProcesses {
                Button(model.showAllProcesses ? "Show top \(Metric.topProcesses)" : "Show all \(total)") {
                    model.showAllProcesses.toggle()
                }
                .buttonStyle(LinkButtonStyle())
            }
        }
        .padding(.horizontal, Metric.tableInset)
        .frame(height: Metric.tableHeaderHeight + 8)
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .kitType(.footer)
            .foregroundStyle(Ink.secondary)
            .frame(maxWidth: .infinity, minHeight: Metric.rowHeight, alignment: .leading)
            .padding(.leading, Metric.tableInset)
    }
}

/// The row menu for a process (S-008, S-014). Without `forceQuit` (the
/// popover), it has no Quit commands.
struct ProcessMenu: View {
    let process: ProcessRowData
    var forceQuit: (() -> Void)?

    var body: some View {
        if let forceQuit {
            Button("Quit \(process.name)") { ProcessActions.quit(process.id) }
                .disabled(!process.ownedByUser)
            Button("Force Quit \(process.name)…", action: forceQuit)
                .disabled(!process.ownedByUser)
            if !process.ownedByUser {
                Text("Owned by another user")
            }
            Divider()
        }
        Button("Show in Activity Monitor") {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
        }
        Button("Copy PID") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(String(process.id), forType: .string)
        }
    }
}
