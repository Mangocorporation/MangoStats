# Architecture review, 2026-10-30 (after M1)

Survey: 3,642 lines in Sources. Largest files StatusView.swift (295), PopoverView.swift (272),
Sampler.swift (253). No duplicated private types, no fix log yet. Targets: MangoStatsKit
(pure logic, tested) ← MangoStats (SwiftUI app, readers, design kit).

## Status building moves out of the Sampler  [Strong]

Files: Sources/MangoStats/Sampling/Sampler.swift (253 lines, `apply` is ~120 of them), StatusData.swift
Signal: pure logic inside a `@MainActor` store, which tests cannot compile alone.
Problem: turning readings into what the cards show (percent, history, speeds, battery state words,
process grouping, health score, menu bar strings) lives in `Sampler.apply`, a `@MainActor` method
that also owns timers and I/O. The Kit tests cover the pieces (Format, Health) but not how they are
put together: a wrong unit or a swapped footer is only caught by the self-test on a live Mac.
M2 (power, PID columns) and M3 (GPU, temperatures, watts, fan) all add fields here.
Proposal: a plain value type in the Kit that takes readings and returns screen values.

```swift
public struct StatusBuilder: Sendable {
    public init(system: SystemInfo)
    /// Folds one reading into the histories and returns what the screens show.
    public mutating func update(_ reading: Reading, network: NetworkContext,
                                previous: StatusData) -> StatusUpdate
}
public struct StatusUpdate: Sendable { public var status: StatusData; public var menuValues: [MenuBarStat: String] }
```

The readings (`Reading`, `MemoryReading`, `DiskReading`, `BatteryReading`, `SystemInfo`) and the
screen values (`StatusData`, `ProcessRowData`) move to the Kit as plain structs. The Sampler keeps
only scheduling, I/O, and the network monitor.
Benefits: locality (every "how is X shown" rule in one Kit file), unit tests with made-up readings
(no battery, offline, counter reset, first sample), Sampler drops to ~110 lines.
Proof of same behavior: the self-test (14 checks, live values), sample snapshots byte-compared before
and after (they don't use the sampler), plus new builder tests.
Plan: 1) move the plain types to the Kit; 2) add StatusBuilder with tests and switch the Sampler to it.

## One card view per stat for both surfaces  [Worth exploring]

Files: StatusView.swift (CPUCard, GPUCard, …), PopoverView.swift (PopCPUCard, PopGPUCard, …)
Signal: the same card is written twice, once per `CardStyle`.
Problem: a change to a card (S-016 adds a temperature pill to CPU and GPU) must be made in two files.
Proposal: `StatCard(stat:, data:, style:)` with a switch per stat; layout differences read from `style`.
Why not now: the two layouts still differ (fan, battery, health), and M2 may change the window cards.
Revisit after S-016.

## Considered, not recommended
- A protocol seam for the readers: only one adapter (the real system); the builder seam above covers tests.
- Splitting AppModel: 90 lines, 2 s update rate, no fast-changing state.

## Top recommendation
Status building moves out of the Sampler (Strong). Done in this check-in.
