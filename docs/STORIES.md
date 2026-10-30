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
Status: done

### S-016 See CPU and GPU temperatures
As the user, I see CPU and GPU temperatures in the card pills and can show temperature in the menu bar.
Depends: S-003, S-015
Acceptance:
- [unit] On Apple silicon, temperatures come from the IOHID temperature sensors, averaged per group (CPU dies, GPU).
- [self] When no sensor is readable, the pill shows "--" and nothing crashes.
Note: temperatures come from SMC keys (CPU Tp*/Te*, GPU Tg*, averaged), not IOHID: the IOHID sensor names don't say which die is CPU or GPU.
Status: done

### S-017 Read power draw
As the user, I see CPU and GPU watts under each card ("idle · 0.9W").
Depends: S-003, S-015
Acceptance:
- [unit] Watts come from IOReport "Energy Model" deltas divided by the elapsed time.
- [self] Without IOReport access, the power part is hidden instead of showing 0.
Note: IOReport channels use different units (CPU Energy in mJ, GPU Energy in nJ); the reader converts by the unit label.
Status: done

### S-018 Read the fan card
As the user, I see fan RPM, speed % and "Managed by macOS", with Auto/Cool/Max shown and Auto selected.
Screens: status-window.png, menubar-popover.png
Depends: S-010
Acceptance:
- [unit] RPM is read from SMC keys `F0Ac`/`F0Mx`; speed % = actual / max.
- [snap] Cool and Max are disabled with the tooltip "Fan control is coming in a later version".
- [self] Fanless Macs show "No fan".
Status: done

## M4 System

### S-019 See privacy and power status
As the user, I see whether the camera or microphone is in use, whether the Mac is kept awake, and whether the screen is on, at the bottom of the popover.
Screens: menubar-popover.png
Depends: S-002
Acceptance:
- [unit] The camera reads `kCMIODevicePropertyDeviceIsRunningSomewhere`; the mic reads `kAudioDevicePropertyDeviceIsRunningSomewhere`.
- [unit] "Awake" is true when any `PreventUserIdleSystemSleep` assertion exists (`IOPMCopyAssertionsByProcess`).
- [snap] Row reads "Not in use · Awake · Screen", like the reference without the counters.
Note: "Awake" = an app holds a system-sleep assertion, "Screen on" = a display-sleep assertion (there's no public API for screen recording). powerd's own "Prevent sleep while display is on" is ignored. Tooltips name the apps.
Status: done

### S-020 Launch at login
As the user, I turn on "Open at login" in Settings → General.
Screens: settings-general
Acceptance:
- [self] The toggle reflects `SMAppService.mainApp.status`, including when the user changed it in System Settings.
Note: test and snapshot runs never register the login item.
Status: done

### S-021 Change the refresh interval
As the user, I pick 1, 2, or 5 seconds in Settings → General.
Screens: settings-general
Depends: S-001
Acceptance:
- [unit] The sampler restarts with the new interval without losing history.
- [self] Process sampling runs at most every 2 s, even at the 1 s interval, to save energy.
Status: done

## M5 Polish

### S-022 App icon
As the user, I see a MangoStats icon in the Dock, Settings, and Finder.
Acceptance:
- [snap] The icon renders in light, dark, and tinted looks.
Note: icon review in design/icon-review.png (Default, Dark, Tinted, Clear, 32 and 16 pt).
Status: done

### S-023 Popover stays light on energy
As the user, I leave the app running all day without it showing in Activity Monitor's energy list.
Acceptance:
- [manual] Average CPU under 1 % with the popover closed and under 3 % with it open (measured in Instruments).
- [self] Charts and the process list stop updating while the popover and window are closed; only the menu bar values refresh.
Note: measured with tools/energy.sh (CPU time over 30 s, release build): closed 0.73 %, popover 1.37 %, window 1.87 %. Was 5.87 / 4.20 / 4.97 %: free space (CacheDelete) was 56 % of samples, now read every 30 s; the menu bar image re-renders only when its text changes.
Status: done

## M6 Fan control

Probe on this M5 (as root): `F0md=1` + `F0Tg=4000` drove the fan to ~4,000 RPM after ~3 s; `F0md=0`
returned it to macOS. No `Ftst` unlock key on M5. Writes need root: a launch daemon helper.

### S-024 Allow fan control
As the user, I turn on fan control once in Settings → General; macOS asks me to allow the MangoStats helper.
Screens: settings-general
Acceptance:
- [self] The helper is a launch daemon in the app bundle (SMAppService.daemon); its state reads Off, Needs approval, or On.
- [manual] "Allow Fan Control…" registers the helper and opens System Settings > General > Login Items when approval is needed.
- [self] The helper accepts connections only from MangoStats signed by the same team.
- [manual] "Turn Off Fan Control" unregisters the helper; the fan is back to Auto.
UX:
- Flow: Settings → General → Fan control section → "Allow Fan Control…" → System Settings opens on Login Items → switch on MangoStats → back in MangoStats the state reads "On" within 2 s
- Surface: Settings section (a place people come back to); state rechecked every 2 s while the tab is open
- States: Off "Fan control is off. Cool and Max need a helper that runs as root."; Needs approval "Allow MangoStats in System Settings > General > Login Items."; On "The helper can set the fan. It returns to Auto when MangoStats quits."; error inline with the reason
- Words: "Fan control" section; buttons "Allow Fan Control…", "Open Login Items…", "Turn Off Fan Control"
- Access: buttons reachable by Tab; VoiceOver reads the state line
Note: confirmed by hand on this M5 (approval with the Apple Development signature, Cool/Max/Auto, quit and force quit return to Auto).
Status: done

### S-025 Pick Auto, Cool, or Max
As the user, I click Cool or Max on the Fan card (window or popover) and the fan spins up; Auto gives control back to macOS.
Screens: status-window.png, menubar-popover.png
Depends: S-024
Acceptance:
- [unit] Cool targets 60 % of the fan's range (min + 0.6 × (max − min)), Max targets the fan's max; never below min.
- [self] Picking Cool writes F0md = 1 and F0Tg through the helper; Auto writes F0md = 0.
- [snap] The selected segment shows; the note reads "Managed by macOS", "Cool · 4,857 RPM target", or "Max · 6,550 RPM target".
- [manual] Without the helper, Cool and Max are disabled with the tooltip "Allow fan control in Settings > General".
UX:
- Flow: click Cool or Max → segment selects at once → fan reaches target in ~3 s (RPM climbs on the card) → click Auto to give control back
- Surface: inline segments on the Fan card (changes one value on screen)
- States: helper missing → Cool/Max disabled with tooltip; helper error → note "Unable to set the fan: <reason>", selection returns to Auto
- Words: "Auto", "Cool", "Max"; tooltips "Let macOS control the fan", "Run the fan at 60 % for cooler temperatures", "Run the fan at full speed"
- Access: segments are buttons with the selected trait; VoiceOver "Fan mode Cool, selected"
Status: done

### S-026 The fan never stays forced
As the user, I trust that a forced fan goes back to Auto when MangoStats isn't watching, and speeds up if the Mac gets hot.
Depends: S-025
Acceptance:
- [unit] The helper's policy returns Auto when the app hasn't pinged for 15 s, on helper start, and when the connection drops.
- [unit] In Cool, a CPU temperature of 90 °C or more raises the target to Max until it drops below 80 °C.
- [self] Quitting MangoStats sets Auto before it exits.
- [manual] Force quitting MangoStats returns the fan to Auto within 15 s.
- [self] MangoStats always starts in Auto.
Status: done

## M7 History

Decided by the agent: one averaged sample per minute in a local SQLite file
(~/Library/Application Support/MangoStats/history.sqlite), kept 30 days by default.

### S-027 Record stats history
As the user, I leave MangoStats running and it remembers how my Mac did, minute by minute, across restarts.
Acceptance:
- [unit] Samples average into one row per minute (CPU, GPU, memory, CPU and GPU temperature, download, upload, battery, CPU and GPU watts); missing sensors stay empty, not 0.
- [self] A row is written each minute and read back after reopening the database.
- [unit] Rows older than the retention are deleted once a day.
- [self] Test and snapshot runs write to a database in /tmp, never the real one.
Note: verified live: one row per minute with every sensor (sqlite3 read-back).
Status: done

### S-028 See history charts
As the user, I switch the Status window to History and see charts for the last hour, day, week, or month.
Screens: status-history
Depends: S-027
Acceptance:
- [unit] A range downsamples to at most ~200 points: Hour 1 min, Day 10 min, Week 1 h, Month 4 h buckets.
- [snap] Seven chart cards in two columns: CPU, GPU, Memory, Temperature (CPU and GPU), Network (down and up), Battery, Power (CPU and GPU), each in its stat color.
- [snap] Empty state before the first minute: "History starts after a minute of recording."
UX:
- Flow: Status window top bar "Status | History" (⌘1 / ⌘2) → History → range "Hour, Day, Week, Month" (default Day) → charts redraw → switch back to Status
- Surface: a page of the Status window (a place people come back to), switched by a segmented control in the top bar
- States: empty (first minute) message; a stat this Mac lacks (no battery) hides its card; gaps when the Mac slept show as breaks, not lines
- Words: "Status", "History"; ranges "Hour", "Day", "Week", "Month"; card titles CPU, GPU, MEMORY, TEMPERATURE, NETWORK, BATTERY, POWER; legends "CPU", "GPU", "Down", "Up"
- Access: the range control is a segmented picker; each chart has an accessibility summary ("CPU, last day, average 18 percent, peak 64 percent")
Status: done

### S-029 Read a value at a time
As the user, I hover a chart and see the value and time under the pointer.
Screens: status-history
Depends: S-028
Acceptance:
- [snap] A vertical rule and a callout "14:20 · 23 %" follow the pointer; every chart in the page shows the same time.
UX:
- Flow: move the pointer over a chart → rule and callout appear on all charts at that time → move out, they disappear
- Surface: inline overlay on the charts
- Words: callout "<time> · <value><unit>"; time format follows the system (14:20 or 2:20 PM), with the day for Week and Month ("Mon 14:00")
- Access: VoiceOver uses the chart summary; Audio Graphs via Swift Charts
Note: hover callout not in snapshots (needs a pointer); check by hand.
Status: done

### S-030 Choose how long history is kept
As the user, I pick 7, 30, or 90 days in Settings → General, or clear history.
Screens: settings-general
Depends: S-027
Acceptance:
- [unit] Changing the retention prunes older rows right away.
- [self] "Clear History…" asks first, then empties the database; the History page shows the empty state.
UX:
- Flow: Settings → General → History → "Keep history for" 7 / 30 / 90 days; "Clear History…" → confirmation "Clear History?" "All recorded stats will be deleted. This can't be undone." buttons "Clear History" / "Cancel"
- Surface: Settings section; confirmation dialog for Clear (destroys data, can't be undone)
- Words: "History", "Keep history for", "7 days", "30 days", "90 days", "Clear History…", footer "Stored only on this Mac, about 1 MB per week."
Status: done

## M8 Alerts

Decided by the agent: macOS notifications; a master "Show alerts" switch asks for permission when
turned on; each rule fires once per episode and at most every 30 minutes.

### S-031 Turn on alerts
As the user, I turn on "Show alerts" in Settings → Alerts and allow notifications.
Screens: settings-alerts
Acceptance:
- [manual] Turning the switch on asks macOS for notification permission; denied shows "Notifications are off for MangoStats." with "Open Notification Settings…".
- [self] Alerts are off by default; nothing asks for permission at launch.
- [manual] "Send Test Alert" shows a notification at once.
UX:
- Flow: Settings → Alerts → "Show alerts" on → macOS permission prompt → Allow → rules below turn active
- Surface: Settings tab (a place people come back to)
- States: off (rules dimmed); on + allowed; on + denied (inline message and button); permission checked again every 2 s while the tab is open
- Words: tab "Alerts"; "Show alerts"; "Send Test Alert"; "Open Notification Settings…"
Note: confirmed by hand (permission prompt, test alert, click opens the Status window).
Status: done

### S-032 Get an alert when something needs attention
As the user, I get one notification when memory pressure turns critical, the CPU runs hot or busy, disk space runs low, the battery runs low, or one app hogs the CPU.
Depends: S-031
Acceptance:
- [unit] Each rule fires after its condition holds for its time (temperature 1 min, CPU busy 5 min, busy app 5 min; the others at once).
- [unit] A rule fires once per episode: not again until the condition clears (with a margin) and returns, and at most every 30 minutes.
- [unit] Alert words name the value and the top app: "CPU is hot: 93°C" / "Above 90°C for a minute. Top CPU: Google Chrome."
- [self] With the busy-app rule on and nothing open, processes are read once a minute.
UX:
- Words: titles "Memory pressure is critical", "CPU is hot: 93°C", "CPU busy for 5 minutes", "Disk space low: 8 GB free", "Battery at 20 %", "Google Chrome is using 180 % CPU"; bodies say what it means and one next step, no blame
Status: done

### S-033 Open MangoStats from an alert
As the user, I click an alert and the Status window opens.
Depends: S-032
Acceptance:
- [manual] Clicking a notification opens the Status window in front; a busy-app alert also filters the process table to that app.
Note: confirmed by hand (permission prompt, test alert, click opens the Status window).
Status: done

### S-034 Choose which alerts and when
As the user, I turn each alert on or off and set its threshold in Settings → Alerts.
Screens: settings-alerts
Depends: S-031
Acceptance:
- [unit] Settings save and load; unknown values fall back to defaults.
- [snap] One row per rule: switch, name, threshold picker (90 / 95 °C; 80 / 90 %; 5 / 10 / 20 GB; 10 / 20 %; 50 / 80 / 100 % CPU).
UX:
- Words: "Memory pressure is critical", "CPU temperature above", "CPU busy above", "Disk space below", "Battery below", "An app uses more than"; footer "Each alert shows once, then waits until the problem clears. At most every 30 minutes."
Status: done

## M9 Updates

### S-035 Check for updates
As the user, I get new versions of MangoStats without downloading them by hand.
Acceptance:
- [self] Sparkle 2.10.1 is embedded and signed inside-out; the feed is https://mangocorporation.github.io/MangoStats/appcast.xml, signed with the team's EdDSA key (shared with MangoMemory).
- [self] Test runs never check for updates.
- [manual] Settings › General › Updates: "Check for Updates…" and "Check for updates automatically" (daily); a background find shows "Install MangoStats <version>…" in the popover.
Status: done

### S-036 Release a version
As the developer, I run tools/release.sh and tools/publish.sh to ship a notarized version that every copy installs.
Acceptance:
- [self] tools/release.sh --check: Developer ID signature, hardened runtime on the app and the helper, the helper accepts the build.
- [manual] tools/release.sh notarizes and staples, signs the zip, adds it to site/appcast.xml; tools/publish.sh creates the GitHub release, then pushes the feed.
Note: 1.0 released 2026-10-30: notarized (Accepted), GitHub release v1.0, feed live; the downloaded zip's EdDSA signature verifies.
Status: done

## M10 Design v2

### S-037 Overview with what's worth a look
As the user, I open the window and first read the one thing worth a look ("Memory is tight · Google Chrome is holding 19,4 GB") with Review and Dismiss, then storage, five stat cards, and the processes.
Screens: design/reference/overview.png
Acceptance:
- [unit] Insights come most urgent first: memory, hot CPU, busy app, storage, battery; calm when none.
- [snap] Layout and colors match overview.png (Amber); the accent follows Settings › Appearance.
- [manual] Review filters the process list to that app; Dismiss hides it until it changes.
Status: done

### S-038 Apps or background processes
As the user, I switch the process list between All, Apps, and Background, sort by CPU or memory, and see the top 13 or all.
Acceptance:
- [unit] A process is an app when it lives in a .app bundle.
- [snap] Segmented controls and "Show all <n>" like overview.png.
Status: done

## Dropped
- Clean, Apps, Optimize, Analyze tabs: another app's job (MangoCleaner).
- "Cleaned / Uninstalled / Optimized" counters: belong to cleaning, not stats.
- The reference app's upgrade button: vendor-only.

## Later
- iCloud sync of settings.
