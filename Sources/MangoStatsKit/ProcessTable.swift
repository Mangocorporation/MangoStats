import Foundation

/// A sortable column of the process table (S-012).
public enum ProcessColumn: String, CaseIterable, Sendable {
    case name, memory, cpu, power, pid
}

/// Which column the table sorts by, and in which direction.
public struct ProcessSort: Equatable, Sendable {
    public var column: ProcessColumn
    public var descending: Bool

    /// Memory, largest first: the order the sampler keeps stable between reads.
    public static let `default` = ProcessSort(column: .memory, descending: true)

    public init(column: ProcessColumn, descending: Bool) {
        self.column = column
        self.descending = descending
    }

    /// Clicking a header: the same column flips; a new one starts largest first (names A–Z).
    public mutating func select(_ column: ProcessColumn) {
        if column == self.column {
            descending.toggle()
        } else {
            self.column = column
            descending = column != .name
        }
    }
}

/// Which processes the table lists (S-038).
public enum ProcessKind: String, CaseIterable, Sendable {
    case all, apps, background

    public var title: String {
        switch self {
        case .all: "All"
        case .apps: "Apps"
        case .background: "Background"
        }
    }

    public func includes(_ row: ProcessRowData) -> Bool {
        switch self {
        case .all: true
        case .apps: row.isApp
        case .background: !row.isApp
        }
    }
}

public enum ProcessTable {
    /// Rows that match `query` by name (any case) or exactly by PID (S-013).
    public static func filter(_ rows: [ProcessRowData], query: String) -> [ProcessRowData] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return rows }
        if let pid = Int32(text) {
            return rows.filter { $0.id == pid || $0.name.localizedCaseInsensitiveContains(text) }
        }
        return rows.filter { $0.name.localizedCaseInsensitiveContains(text) }
    }

    /// Sorted rows. The default sort keeps the incoming (stable) order.
    public static func sort(_ rows: [ProcessRowData], by sort: ProcessSort) -> [ProcessRowData] {
        guard sort != .default else { return rows }
        let ascending: [ProcessRowData]
        switch sort.column {
        case .name:
            ascending = rows.sorted {
                let order = $0.name.localizedStandardCompare($1.name)
                return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
            }
        case .memory: ascending = rows.sorted { ($0.memoryBytes, $0.id) < ($1.memoryBytes, $1.id) }
        case .cpu: ascending = rows.sorted { ($0.cpu, $0.id) < ($1.cpu, $1.id) }
        case .power: ascending = rows.sorted { ($0.watts ?? -1, $0.id) < ($1.watts ?? -1, $1.id) }
        case .pid: ascending = rows.sorted { $0.id < $1.id }
        }
        return sort.descending ? ascending.reversed() : ascending
    }
}
