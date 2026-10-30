# MangoStats

A menu bar system monitor for one Mac user: live CPU, GPU, memory, disk, network, fan, battery and process stats at a glance, with a full dashboard window when you want detail.

Bundle id: `com.mangocorp.mangostats`

## Replaces
A system monitor's status view (reference screenshots), plus opening Activity Monitor to see what's eating CPU or memory.

## Main jobs
1. Glance at the menu bar for the stats I chose (e.g. CPU %, memory %, network speed, temperature).
2. Click the menu bar item for a popover with every stat card, a health score, and the top processes.
3. Open the Status window for the full dashboard and a sortable, searchable process table (and quit a process from its `…` menu).

## Data
No stored documents. It reads live samples, and only settings are saved:
- **Snapshot** (live, in memory): cpu %, per-core load, gpu %, temps, power (W), memory used/total/swap/pressure, disk free/used/total, network up/down KB/s and interface, fan RPM, battery %/health/charging/watts, uptime, chip, macOS version, camera/mic in use, awake (power assertion) state.
- **ProcessSample**: name, icon, pid, memory, cpu %, energy impact.
- **History**: ring buffer of the last ~60 samples per metric for the sparklines.
- **MenuBarSettings** (UserDefaults): which metrics show in the menu bar and in what order, compact vs. labeled style, refresh interval. *(decided by the agent)*

## Shape
Menu bar extra (`MenuBarExtra`, window style) as the main surface, plus one Status window (card grid + process table) and a Settings window. macOS 26 or later. Local data. Works offline. No accounts. Launch at login option. *(decided by the agent)*

## System hooks
- Menu bar item whose content you configure: pick any of CPU, GPU, Memory, Disk, Network, Temperature, Fan, Battery; drag to reorder.
- Launch at login (SMAppService).
- Fan control (Auto / Cool / Max) through a root launch daemon in the bundle (SMAppService.daemon), added in M6.
- Private reads: IOKit/SMC for temperatures and fan RPM, IOReport for GPU and power, `host_statistics`/`proc_pidinfo` for CPU, memory and processes. *(decided by the agent)*

## Reference
Screenshots of a system monitor's status window and menu bar popover, kept out of git: `local/reference/menubar-popover.png`, `local/reference/status-window.png`.

## Look
Its own look, not stock Apple. Dark warm brown/olive background, rounded translucent cards with small uppercase headers and grey pill tags, big numbers with small units, a green bar chart for CPU, an orange line for GPU, a gold area chart for memory, a gold progress bar for disk, a blue line for network, green ring buttons for battery, and orange highlights for hot processes. Built with the `design-from-app` skill.

## Not in version one
- Clean, Apps, Optimize and Analyze tabs, and the "Cleaned / Uninstalled / Optimized" counters.
- History beyond the live session, alerts and notifications, and iCloud sync.
