# MangoStats stories

References: `local/reference/menubar-popover.png` (popover), `local/reference/status-window.png` (window).
Snapshot pages without a reference: `menubar-item`, `settings-menubar`, `settings-general`.

## M1 Glance (menu bar + popover)

### S-001 See live CPU and memory in the menu bar
As the user, I see MangoStats in the menu bar showing CPU % and memory %, updating every 2 seconds.
Screens: menubar-item
Acceptance:
- [unit] The CPU sampler returns 0–100 % from two `host_processor_info` reads; memory % is (active + wired + compressed) / total.
- [self] After 3 s the menu bar label shows two values that differ from the placeholder "--".
- [snap] The label uses monospaced digits, so its width doesn't jump as values change.
UX:
- Flow: app launches -> menu bar item appears with "--" -> first values within 2 s -> click opens the popover (S-002)
- Surface: menu bar item (shows info needing no action, always visible)
- States: before the first sample "--"; a stat that cannot be read shows "--", never 0
- Words: default stats CPU and Memory, style Icon and Value (SF Symbols cpu, memorychip + "15%")
- Access: VoiceOver reads "MangoStats, CPU 15 percent, Memory 84 percent"; the item opens with Return when focused (Control-F8)
Note: memory % uses Activity Monitor's "Memory Used" (app + wired + compressed). The label is one template image, since MenuBarExtra flattens HStack labels.
Status: done

### S-002 Open the popover and see the health header
As the user, I click the menu bar item and see a health score (0–100 + Good/Fair/Poor), and chips for chip name, RAM, macOS version and uptime.
Screens: menubar-popover.png
Depends: S-001
Acceptance:
- [unit] The health score drops for high memory pressure, low disk (<10 % free), hot CPU (>90 °C) and sustained CPU >80 %; each rule is tested.
- [snap] The header matches the reference: sun icon, "84 Good", four grey pill chips.
- [unit] Uptime reads "up 51 days, 10 hrs" for 51 d 10 h.
UX:
- Flow: click menu bar item -> popover opens -> Escape or a click outside closes it
- Surface: popover from the menu bar item (MenuBarExtra window style; a few related readings tied to one control)
- States: health while the first samples load shows "--" with no word; reasons behind the score in a tooltip on the number ("Disk space low · 99 GB free")
- Words: "84 Good"; chips "M5", "24 GB", "macOS 26.6.2", "up 51 days, 10 hrs"; footer row with icon buttons Open MangoStats (⌘1), Settings… (⌘,), Quit MangoStats (⌘Q) — not in the reference, but a menu bar app needs a way out
- Access: footer buttons have tooltips "Open the Status window (⌘1)", "Change which stats show in the menu bar (⌘,)", "Quit MangoStats (⌘Q)"; health color is also spelled out in the word
Status: done

### S-003 Read the CPU card
As the user, I see CPU % with a green bar history and "idle · 1.0W" below it.
Screens: menubar-popover.png
Depends: S-002
Acceptance:
- [snap] Big number + small "%", 10 bars of the last samples, temperature pill top right ("--" when no sensor).
- [unit] The history ring buffer keeps the last 60 samples and drops the oldest.
- [unit] The load label reads idle (<20 %), normal (20–60 %), busy (>60 %).
UX:
- Flow: read only; hover the chart for the value of a past sample
- Surface: card in the popover grid (inline, needs no action)
- States: no temperature sensor -> pill hidden (not "--") so it doesn't look broken; no power reading -> "idle" alone
- Words: header "CPU", pill "41°C", footer "idle · 1.0W"
- Access: VoiceOver reads the card as one element: "CPU, 15 percent, idle, 1 watt, 41 degrees"; bars are decorative
Note: temperature pill and watts arrive with S-016/S-017; until then the pill is hidden and the footer shows the load word only.
Status: done

### S-004 Read the memory card
As the user, I see memory %, a gold area chart, the pressure pill (Normal/Warning/Critical) and "20,25 GB / 24 GB".
Screens: menubar-popover.png
Depends: S-002
Acceptance:
- [snap] Gold line with a fading fill below, pressure pill top right.
- [unit] Pressure maps from `kern.memorystatus_vm_pressure_level` 1/2/4 to Normal/Warning/Critical.
- [unit] Byte values use the user's locale (comma decimal in pt_BR).
UX:
- Flow: read only
- Surface: card in the popover grid
- States: Warning pill amber, Critical pill red, each with the word (not color alone)
- Words: header "MEM" in the popover, "Memory" in the Status window; pill "Normal"; footer "20,25 GB / 24 GB"
- Access: VoiceOver "Memory, 84 percent, pressure normal, 20.25 of 24 gigabytes"
Status: done

### S-005 Read the free space card
As the user, I see free GB on the startup disk, a usage bar, total capacity pill and "396 GB used · 80%".
Screens: menubar-popover.png
Depends: S-002
Acceptance:
- [unit] Free space uses `volumeAvailableCapacityForImportantUsage` (matches Finder, includes purgeable).
- [snap] Bar fill matches used %, capacity pill top right.
UX:
- Flow: read only; click the card to open the startup disk in Finder
- Surface: card in the popover grid
- States: under 10 % free the bar turns amber and Health says why
- Words: header "Free space", value "99 GB", pill "494 GB", footer "396 GB used · 80%"
- Access: VoiceOver "Free space, 99 gigabytes of 494, 80 percent used"; the bar is a progress value
Status: done

### S-006 Read the network card
As the user, I see download speed, a blue line, the interface pill (Wi-Fi/Ethernet), "Upload <1KB/s" and a latency label.
Screens: menubar-popover.png
Depends: S-002
Acceptance:
- [unit] Speed is the byte delta of `getifaddrs` counters on non-loopback interfaces divided by the elapsed time; values under 1 KB/s show "<1".
- [unit] Latency: Low (<50 ms), Medium (<150 ms), High, from a TCP connect to 1.1.1.1:443 every 30 s; "Offline" when it fails.
- [snap] Blue line, interface pill, upload left and latency right in the footer.
UX:
- Flow: read only
- Surface: card in the popover grid
- States: offline -> value "--", pill "Offline", latency "Offline"; unknown interface -> pill "Network"
- Words: header "Network", value "<1 KB/s" (auto KB/s, MB/s), pill "Wi-Fi" or "Ethernet", footer "Upload <1 KB/s" and "Low Lag"
- Access: VoiceOver "Network, download under 1 kilobyte per second, upload under 1 kilobyte per second, Wi-Fi, low lag"
Status: done

### S-007 Read the battery card
As the user, I see battery %, charger watts, state (Charged/Charging/On battery, with time left) and health %.
Screens: menubar-popover.png
Depends: S-002
Acceptance:
- [unit] Health = max capacity / design capacity from `AppleSmartBattery`, capped at 100 %.
- [snap] Big "100%", bolt + "65W" when plugged in, health pill, two green ring buttons.
- [self] On a Mac without a battery, the card shows "No battery" and power source watts.
UX:
- Flow: read only; the two ring buttons open System Settings → Battery and Energy
- Surface: full-width card in the popover
- States: Charging "Charging · 45 min to full"; On Battery "On Battery · 3 h 20 min left"; desktop "No battery"
- Words: header "Battery", "100%", bolt + "65W", "Charged", pill "100% Health"
- Access: ring buttons have tooltips "Open Battery settings" and "Open Energy settings"; VoiceOver reads state in words
Status: done

### S-008 See the top processes
As the user, I see the 5 processes using the most memory, with memory and % CPU, and CPU over 20 % highlighted orange.
Screens: menubar-popover.png
Depends: S-002
Acceptance:
- [unit] The process sampler lists pid, name, resident memory and CPU % from `proc_pidinfo` deltas; sorting by memory is stable.
- [snap] Columns Memory and % CPU, a `…` button per row, orange values for >20 % CPU.
- [self] The list refreshes every sample without reordering rows whose values barely changed (no flicker).
UX:
- Flow: click `…` on a row -> menu: Show in Activity Monitor, Copy PID (Quit lives in the Status window, S-014)
- Surface: section inside the popover; row menu, never a second popover
- States: names truncate with the full name in a tooltip; rows keep order unless the rank changes
- Words: header "Top Processes", columns "Memory" and "% CPU"; `…` tooltip "More actions for Google Chrome"
- Access: orange CPU values also bold, so the meaning isn't color alone; VoiceOver "Google Chrome, 18.52 gigabytes, 45.2 percent CPU"
Note: other users' processes (WindowServer) come from /bin/ps, which runs as root; own processes use proc_pid_rusage. Processes are grouped by app (Chrome and its helpers = one row), like the reference. Row menu has Show in Activity Monitor and Copy PID; Quit lands with S-014.
Status: done

### S-009 Choose which stats show in the menu bar
As the user, I open Settings → Menu Bar, turn stats on or off (CPU, GPU, Memory, Disk, Network, Temperature, Fan, Battery), and drag them into the order I want. The menu bar updates right away.
Screens: settings-menubar, menubar-item
Depends: S-001
Acceptance:
- [snap] A list of all 8 stats with a toggle and drag handle each, plus a live preview of the menu bar label.
- [unit] Settings save to UserDefaults and survive a restart; unknown keys are ignored.
- [self] With everything off, the menu bar shows the app icon only, so the item is never invisible.
- [snap] Style picker: "Icon + value" or "Value only".
UX:
- Flow: popover Settings… (⌘,) -> Settings window opens on the Menu Bar tab -> toggle a stat or drag a row -> preview and real menu bar update at once -> close the window (no Save button)
- Surface: Settings window tab (a place people come back to; changes apply live)
- States: all stats off -> note under the list "The menu bar shows the MangoStats icon when no stats are on."; a stat this Mac lacks (Fan, Battery) is listed but disabled with "Not available on this Mac"
- Words: tab "Menu Bar"; section "Show in Menu Bar"; rows "CPU", "GPU", "Memory", "Disk", "Network", "Temperature", "Fan", "Battery"; picker "Menu bar style" with "Icon and Value" and "Value Only"; "Preview"
- Access: rows reorder with drag and with ⌥⌘↑ / ⌥⌘↓; each toggle reads "Show CPU in menu bar"
Note: GPU, Temperature and Fan are listed but off ("Coming in a later version") until M3. Keyboard reorder is Move Up / Move Down in the row's context menu instead of ⌥⌘↑/↓.
Status: done

## M2 Dashboard window

### S-010 Open the Status window
As the user, I choose "Open MangoStats" in the popover (or press Command-1 in it) and the dashboard window opens with 8 cards in a 4×2 grid.
Screens: status-window.png
Depends: S-003, S-004, S-005, S-006, S-007
Acceptance:
- [snap] Health, CPU, GPU, Memory / Battery, Free space, Network, Fan, matching the reference layout.
- [snap] The health card shows a reason line ("Disk space low · 99 GB Free") and the uptime.
- [snap] The battery card shows "Top drain now <process>".
UX:
- Flow: popover "Open MangoStats" button or ⌘1 while the popover is open -> Status window opens in front (or comes forward if already open) -> ⌘W or the close button closes it; the menu bar item keeps running
- Surface: new window (a place people keep open beside their work)
- States: before the first sample every value reads "--" in Ink.secondary; health reason "Measuring…"; a stat this Mac can't read hides its pill instead of showing "--"
- Words: window title "MangoStats" (hidden, shown in Mission Control and the Window menu); card headers HEALTH, CPU, GPU, MEMORY, BATTERY, FREE SPACE, NETWORK, FAN; "Pressure normal"; "Top drain now <app>"
- Access: VoiceOver reads each card as one element ("CPU, 15 percent, idle"); ⌘W closes
Status: done

### S-011 Browse the process table
As the user, I see every process with icon, name, memory, a CPU bar, % CPU, power and PID, and a count in the header ("NAME (156)").
Screens: status-window.png
Depends: S-008, S-010
Acceptance:
- [snap] Columns match the reference; an orange left marker on rows above 20 % CPU.
- [unit] The power column comes from `proc_pid_rusage` energy deltas; "--" when unavailable.
UX:
- Flow: Status window -> table lists every process, refreshed every 2 s, rows keep their place unless the rank really changes
- Surface: inline table in the Status window
- States: before the first read "Reading processes…" row; long names truncate in the middle with the full name in a tooltip; 500+ rows scroll smoothly (lazy rows)
- Words: header "NAME (156)", "MEM", "% CPU", "PWR", "PID"; power in watts with one decimal, "--" for other users' processes; tooltip on PWR "Power in watts. -- for processes of other users."
- Access: the hot marker is paired with a bold hot-colored value, so it never rests on color alone; VoiceOver "Google Chrome, 18.5 gigabytes, 47.7 percent CPU, 42.8 watts"
Status: done

### S-012 Sort the process table
As the user, I click a column header to sort by it; clicking again flips the order.
Screens: status-window.png
Depends: S-011
Acceptance:
- [unit] Sort works on name, memory, CPU, power and PID in both directions.
- [snap] The active header shows a small arrow.
UX:
- Flow: click a column header -> sorts by it, largest first (names A–Z) -> click again flips -> arrow shows the order
- Surface: inline (header buttons change one value on screen)
- States: default sort Memory, largest first; the order is kept while the window stays open
- Words: tooltips "Sort by memory", "Sort by % CPU", "Sort by power", "Sort by PID", "Sort by name"
- Access: headers are buttons; VoiceOver "Sort by memory, sorted descending"
Status: done

### S-013 Search processes
As the user, I click the magnifier (or press Command-F) and type to filter processes by name or PID.
Screens: status-window.png
Depends: S-011
Acceptance:
- [unit] The filter is case-insensitive and matches a PID exactly.
- [snap] The search field replaces the magnifier in the header; Escape clears it.
UX:
- Flow: ⌘F or the magnifier -> search field replaces the magnifier, focused -> type to filter by name, or an exact PID -> Escape clears and closes the field
- Surface: inline field in the table header (changes one value on screen)
- States: no match -> one row "No processes match "<text>"" ; the count in the header shows matches ("NAME (3 of 156)")
- Words: placeholder "Name or PID"; magnifier tooltip "Filter processes by name or PID (⌘F)"
- Access: the field gets focus on ⌘F; Escape clears; VoiceOver "Search processes"
Status: done

### S-014 Quit a process from its row menu
As the user, I click `…` on a process and choose Quit, Force Quit, Show in Activity Monitor, or Copy PID.
Screens: status-window.png
Depends: S-011
Acceptance:
- [self] Quit sends SIGTERM; Force Quit asks for confirmation, then sends SIGKILL.
- [manual] System processes the user doesn't own show Quit disabled with a tooltip explaining why.
UX:
- Flow: click `…` on a row or Control-click the row -> menu: Quit, Force Quit…, Show in Activity Monitor, Copy PID -> Quit asks the app to quit (it can still ask to save) -> Force Quit… shows a confirmation, then ends it at once
- Surface: menu on the row (a few related actions); confirmation dialog for Force Quit (destroys unsaved work, cannot be undone)
- States: processes owned by another user (WindowServer, root daemons) -> Quit and Force Quit disabled, menu note "Owned by another user"; a quit that fails -> the row stays, nothing else
- Words: "Quit <name>", "Force Quit <name>…", dialog title "Force Quit <name>?", message "Unsaved changes in <name> will be lost.", buttons "Force Quit" and "Cancel"; "Show in Activity Monitor", "Copy PID"
- Access: Return confirms, Escape cancels the dialog; the menu works from the keyboard
Note: the row menu and the Force Quit dialog are not in snapshots (menus and dialogs aren't window captures); check by hand.
Status: done

## M3 Sensors

### S-015 Read the GPU card
As the user, I see GPU %, an orange line, temperature and "normal · 0.3W".
Screens: status-window.png, menubar-popover.png
Depends: S-010
Acceptance:
- [unit] GPU % reads `Device Utilization %` from the IOAccelerator `PerformanceStatistics`.
- [snap] Orange line chart, temperature pill.
Status: todo

### S-016 See CPU and GPU temperatures
As the user, I see CPU and GPU temperatures in the card pills and can show temperature in the menu bar.
Depends: S-003, S-015
Acceptance:
- [unit] On Apple silicon, temperatures come from the IOHID temperature sensors, averaged per group (CPU dies, GPU).
- [self] When no sensor is readable, the pill shows "--" and nothing crashes.
Status: todo

### S-017 Read power draw
As the user, I see CPU and GPU watts under each card ("idle · 0.9W").
Depends: S-003, S-015
Acceptance:
- [unit] Watts come from IOReport "Energy Model" deltas divided by the elapsed time.
- [self] Without IOReport access, the power part is hidden instead of showing 0.
Status: todo

### S-018 Read the fan card
As the user, I see fan RPM, speed % and "Managed by macOS", with Auto/Cool/Max shown and Auto selected.
Screens: status-window.png, menubar-popover.png
Depends: S-010
Acceptance:
- [unit] RPM is read from SMC keys `F0Ac`/`F0Mx`; speed % = actual / max.
- [snap] Cool and Max are disabled with the tooltip "Fan control is coming in a later version".
- [self] Fanless Macs show "No fan".
Status: todo

## M4 System

### S-019 See privacy and power status
As the user, I see whether the camera or microphone is in use, whether the Mac is kept awake, and whether the screen is on, at the bottom of the popover.
Screens: menubar-popover.png
Depends: S-002
Acceptance:
- [unit] The camera reads `kCMIODevicePropertyDeviceIsRunningSomewhere`; the mic reads `kAudioDevicePropertyDeviceIsRunningSomewhere`.
- [unit] "Awake" is true when any `PreventUserIdleSystemSleep` assertion exists (`IOPMCopyAssertionsByProcess`).
- [snap] Row reads "Not in use · Awake · Screen", like the reference without the counters.
Status: todo

### S-020 Launch at login
As the user, I turn on "Open at login" in Settings → General.
Screens: settings-general
Acceptance:
- [self] The toggle reflects `SMAppService.mainApp.status`, including when the user changed it in System Settings.
Status: todo

### S-021 Change the refresh interval
As the user, I pick 1, 2, or 5 seconds in Settings → General.
Screens: settings-general
Depends: S-001
Acceptance:
- [unit] The sampler restarts with the new interval without losing history.
- [self] Process sampling runs at most every 2 s, even at the 1 s interval, to save energy.
Status: todo

## M5 Polish

### S-022 App icon
As the user, I see a MangoStats icon in the Dock, Settings, and Finder.
Acceptance:
- [snap] The icon renders in light, dark, and tinted looks.
Status: todo

### S-023 Popover stays light on energy
As the user, I leave the app running all day without it showing in Activity Monitor's energy list.
Acceptance:
- [manual] Average CPU under 1 % with the popover closed and under 3 % with it open (measured in Instruments).
- [self] Charts and the process list stop updating while the popover and window are closed; only the menu bar values refresh.
Status: todo

## Dropped
- Clean, Apps, Optimize, Analyze tabs: another app's job (MangoCleaner).
- "Cleaned / Uninstalled / Optimized" counters: belong to cleaning, not stats.
- The reference app's upgrade button: vendor-only.
- Fan control (Cool/Max): needs a privileged SMC helper; read-only in v1 (S-018).

## Later
- Fan control with a privileged helper.
- Stats history across days, and alerts (e.g. memory pressure critical).
- iCloud sync of settings.
