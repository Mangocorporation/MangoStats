# MangoStats architecture

## Targets

```text
MangoStatsKit   pure logic and plain values, no SwiftUI, no I/O. Tested in Tests/MangoStatsKitTests.
   ^
MangoStats      the app: scenes, views, design kit, system readers, sampler.
```

Dependencies point one way: the app imports the Kit, never the other way.

## Data flow

```text
Readers (app, nonisolated)  ->  Reading (Kit)  ->  StatusBuilder (Kit)  ->  StatusUpdate
  CPUReader, MemoryReader,                         keeps histories and       status: StatusData
  DiskReader, NetworkReader,                       previous counters         menuValues: [MenuBarStat: String]
  BatteryReader, ProcessReader                                                     |
                                                                                   v
Sampler (app, @MainActor): every 2 s, reads off the main thread,     AppModel.status / .menuValues
  runs the builder, writes the model. Owns NWPathMonitor and the      -> MenuBarLabel, PopoverView,
  latency probe (NetworkContext).                                         StatusView
```

- **Seam:** `StatusBuilder.update(_:network:previous:)`. Two adapters: the Sampler with real readings,
  and the unit tests with made-up readings (no battery, offline, counter reset).
- Processes are read only while the popover or Status window is open (`AppModel.detailVisible`).
- Snapshot runs skip the sampler and show `StatusData.sample` (app target), unless `APP_LIVE=1`.

## App folders

- `Sampling/` system readers, process reader (ps + proc_pid_rusage), sampler.
- `DesignKit/` tokens, icons, parts, gallery (design/KIT.md).
- `PopoverView.swift`, `StatusView.swift`, `SettingsView.swift` the three surfaces.
- `Models.swift` `AppModel` (menu bar layout, status, open surfaces) and `Store` (settings domain).
