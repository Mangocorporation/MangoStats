# MangoStats architecture

## Targets

```text
MangoStatsKit     pure logic and plain values, no SwiftUI, no I/O (incl. FanPolicy). Tested.
   ^
MangoStatsSMC     SMC read/write and the fan helper's XPC protocol.
   ^          ^
MangoStats    MangoStatsHelper   app / root launch daemon that sets the fan (bundled by build.sh,
                                 registered with SMAppService.daemon, LaunchDaemons/*.plist)
```

Fan control: the app sends the wanted mode every sample over XPC; the helper applies FanPolicy
(targets, 15 s timeout, hot override) and returns to Auto on start, SIGTERM, and dropped connections.
The helper accepts only callers with identifier com.mangocorp.mangostats signed by its own team.

Dependencies point one way: the app imports the Kit, never the other way.

## Data flow

```text
Readers (app, nonisolated)  ->  Reading (Kit)  ->  StatusBuilder (Kit)  ->  StatusUpdate
  CPUReader, MemoryReader,                         keeps histories and       status: StatusData
  DiskReader, NetworkReader,                       previous counters         menuValues: [MenuBarStat: String]
  BatteryReader, ProcessReader,
  SensorReader (GPU, SMC, IOReport)                                                    |
                                                                                   v
Sampler (app, @MainActor): every 2 s, reads off the main thread,     AppModel.status / .menuValues
  runs the builder, writes the model. Owns NWPathMonitor and the      -> MenuBarLabel, PopoverView,
  latency probe (NetworkContext).                                         StatusView
```

- **Seam:** `StatusBuilder.update(_:network:previous:)`. Two adapters: the Sampler with real readings,
  and the unit tests with made-up readings (no battery, offline, counter reset).
- Processes are read only while the popover or Status window is open (`AppModel.detailVisible`).
- History (M7): `StatusUpdate.point` -> `MinuteAggregator` (Kit) in the Sampler -> `HistoryStore`
  (SQLite, own serial queue, `history.sqlite` in Application Support; `<APP_STORE>-history.sqlite` in
  test runs). `HistoryView` reads it and downsamples with `HistoryRange` (Kit).
- Snapshot runs skip the sampler and show `StatusData.sample` (app target), unless `APP_LIVE=1`.

## App folders

- `Sampling/` system readers, process reader (ps + proc_pid_rusage), sensor reader (IOAccelerator GPU load,
  SMC temperatures and fans, IOReport energy; links libIOReport), sampler.
- `DesignKit/` tokens, icons, parts, gallery (design/KIT.md).
- `PopoverView.swift`, `StatusView.swift` (Status | History tabs), `HistoryView.swift`, `SettingsView.swift`.
- `Models.swift` `AppModel` (menu bar layout, status, open surfaces) and `Store` (settings domain).
