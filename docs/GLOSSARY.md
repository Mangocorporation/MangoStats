# MangoStats glossary

| Term | Means | Not |
| --- | --- | --- |
| Menu bar item | MangoStats' entry in the macOS menu bar, showing the stats you chose | top bar, status item, tray |
| Popover | The panel that opens when you click the menu bar item | dropdown, menu, panel |
| Status window | The dashboard window with every card and the process table | dashboard, main window |
| Stat | One measured value: CPU, GPU, Memory, Disk, Network, Temperature, Fan, Battery | metric, sensor, widget |
| Card | The rounded box that shows one stat with its chart | tile, widget, panel |
| Health | 0–100 score for how the Mac is doing, with a word: Good, Fair, Poor | score, status, grade |
| CPU | Processor load, in % | processor, load |
| GPU | Graphics processor load, in % | graphics |
| Memory | RAM in use, in %, with pressure | RAM, MEM (only as the card header in the popover) |
| Pressure | macOS memory pressure: Normal, Warning, Critical | load |
| Free space | Space left on the startup disk, including purgeable | disk free, storage |
| Disk | The menu bar stat for Free space | storage, drive |
| Network | Download and upload speed of the active connection | net, traffic, bandwidth |
| Latency | How fast the internet answers: Low Lag, Medium Lag, High Lag, Offline | ping |
| Temperature | CPU temperature in °C | temp, heat |
| Fan | Fan speed in RPM and % of max | cooling |
| Battery | Charge %, state, health %, charger watts | power |
| Battery health | Max capacity as % of design capacity | condition, capacity |
| Charged / Charging / On Battery | The battery states | plugged, unplugged |
| Process | One running program, with memory, % CPU, power, and PID | app, task |
| Top processes | The 5 processes using the most memory, in the popover | top apps |
| Menu bar style | How each stat shows in the menu bar: "Icon and Value" or "Value Only" | display mode |
| Open MangoStats | Opens the Status window | show dashboard |
| Settings… | Opens the Settings window (⌘,) | preferences, options |
| Quit MangoStats | Quits the app (⌘Q) | exit, close |
| Power | A process's energy use in watts (PWR column) | energy impact, drain |
| Top drain | The app using the most CPU now, shown on the Battery card | battery hog |
| Hot | A process over 20 % CPU: orange marker and value | high, busy |
| Sort by <column> | Order the process table by that column | order, arrange |
| Name or PID | What the process search matches | filter, query |
| Quit <name> | Ask a process to quit; it may ask to save | close, end, kill |
| Force Quit <name>… | End a process at once; unsaved work is lost | kill, terminate |
| Show in Activity Monitor | Open Activity Monitor | inspect |
| Copy PID | Put the process ID on the clipboard | copy ID |
| Owned by another user | Why Quit is unavailable for system processes | permission denied |
| Not in use / Camera in use / Mic in use | Whether an app is using the camera or microphone | recording, active |
| Awake / Can sleep | Whether an app keeps the Mac from sleeping | caffeinated, insomnia |
| Screen on / Screen can sleep | Whether an app keeps the display on | display awake |
| Open at login | Start MangoStats when you log in | launch at startup, auto-start |
| Refresh every | Seconds between samples: 1, 2, or 5 | update rate, polling |
| Fan control | Letting MangoStats set the fan through its helper | fan override |
| Helper | The small part of MangoStats that runs as root to set the fan | daemon, service, tool |
| Auto / Cool / Max | Fan modes: macOS decides / 60 % / full speed | quiet, turbo, boost |
| History | Recorded stats over time, one averaged sample per minute | log, timeline, records |
| Hour / Day / Week / Month | The time range shown on the History page | period, span |
| Keep history for | How long recorded stats are kept | retention |
| Clear History… | Delete all recorded stats | reset, wipe |
| Alert | A macOS notification MangoStats shows when a rule's condition holds | warning, notification (in UI) |
| Show alerts | The master switch for all alerts | enable notifications |
| Busy app | One app using more CPU than its threshold for 5 minutes | hog, runaway |
| Send Test Alert | Show a sample alert now | test notification |
