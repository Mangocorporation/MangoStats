import SwiftUI
import MangoStatsKit

/// The Status window's process table: every process, sortable by any
/// column (S-012) and searchable by name or PID (S-013).
struct ProcessTableView: View {
    @Environment(AppModel.self) private var model
    let data: StatusData
    @State private var searching = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        let filtered = ProcessTable.filter(data.processes, query: model.processQuery)
        let rows = ProcessTable.sort(filtered, by: model.processSort)
        VStack(spacing: 0) {
            header(shown: rows.count)
                .padding(.trailing, Metric.iconGap)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if data.processes.isEmpty {
                        message("Reading processes…")
                    } else if rows.isEmpty {
                        message("No processes match \u{201C}\(model.processQuery)\u{201D}")
                    }
                    ForEach(rows, id: \.self) { process in
                        ProcessRow(process: process) { AnyView(ProcessMenu(process: process)) }
                            .padding(.trailing, Metric.iconGap)
                    }
                }
            }
        }
        .padding(.leading, Metric.tableInset)
        .padding(.top, Metric.iconGap)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Ink.cardFill, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
            .strokeBorder(Ink.cardStroke, lineWidth: Metric.cardStroke))
        .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
    }

    private func header(shown: Int) -> some View {
        let total = data.processCount
        let title = model.processQuery.isEmpty ? "Name (\(total))" : "Name (\(shown) of \(total))"
        return HStack(spacing: 0) {
            HStack {
                sortButton(title, .name)
                Spacer(minLength: Metric.iconGap)
                if searching || !model.processQuery.isEmpty {
                    @Bindable var model = model
                    KitSearchField(text: $model.processQuery, prompt: "Name or PID", focused: $searchFocused,
                                   onClear: closeSearch)
                        .accessibilityLabel("Search processes")
                }
            }
            .padding(.leading, Metric.hotMarker.width + Metric.iconGap)
            .frame(maxWidth: .infinity, alignment: .leading)
            sortButton("Mem", .memory).frame(width: Metric.colMemory, alignment: .trailing)
            Spacer().frame(width: Metric.colMemoryGap + Metric.miniBar.width)
            sortButton("% CPU", .cpu).fixedSize().frame(width: Metric.colCPU, alignment: .trailing)
            sortButton("Pwr", .power).frame(width: Metric.colPower, alignment: .trailing)
                .help("Power in watts. -- for processes of other users.")
            sortButton("PID", .pid).frame(width: Metric.colPID, alignment: .trailing)
            Button("Search Processes", systemImage: KitIcon.search.symbol) {
                searching ? closeSearch() : openSearch()
            }
            .buttonStyle(KitIconButtonStyle())
            .keyboardShortcut("f")
            .help("Filter processes by name or PID (⌘F)")
            .frame(width: Metric.colMore)
        }
        .frame(height: Metric.tableHeaderHeight)
    }

    private func sortButton(_ title: String, _ column: ProcessColumn) -> some View {
        let active = model.processSort.column == column
        return Button(title) { model.processSort.select(column) }
            .buttonStyle(ColumnHeaderButtonStyle(active: active, descending: model.processSort.descending))
            .help("Sort by \(title == "Mem" ? "memory" : title == "Pwr" ? "power" : title.hasPrefix("Name") ? "name" : title)")
            .accessibilityValue(active ? (model.processSort.descending ? "sorted descending" : "sorted ascending") : "")
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .kitType(.footer)
            .foregroundStyle(Ink.secondary)
            .frame(maxWidth: .infinity, minHeight: Metric.rowHeight, alignment: .leading)
            .padding(.leading, Metric.hotMarker.width + Metric.iconGap)
    }

    private func openSearch() {
        searching = true
        searchFocused = true
    }

    private func closeSearch() {
        model.processQuery = ""
        searching = false
        searchFocused = false
    }
}
