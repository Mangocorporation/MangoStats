# MangoStats glossary

| Term | pt-BR | Means | Not |
| --- | --- | --- | --- |
| Menu bar item | Item da barra de menus | MangoStats' entry in the macOS menu bar, showing the stats you chose | top bar, status item, tray |
| Popover | Popover | The panel that opens when you click the menu bar item | dropdown, menu, panel |
| Status window | Janela (Visão Geral) | The dashboard window with every card and the process table | dashboard, main window |
| Stat | Dado | One measured value: CPU, GPU, Memory, Disk, Network, Temperature, Fan, Battery | metric, sensor, widget |
| Card | Cartão | The rounded box that shows one stat with its chart | tile, widget, panel |
| Health | Saúde | 0–100 score for how the Mac is doing, with a word: Good, Fair, Poor | score, status, grade |
| CPU | CPU | Processor load, in % | processor, load |
| GPU | GPU | Graphics processor load, in % | graphics |
| Memory | Memória | RAM in use, in %, with pressure | RAM, MEM (only as the card header in the popover) |
| Pressure | Pressão | macOS memory pressure: Normal, Warning, Critical | load |
| Free space | Espaço livre | Space left on the startup disk, including purgeable | disk free, storage |
| Disk | Disco | The menu bar stat for Free space | storage, drive |
| Network | Rede | Download and upload speed of the active connection | net, traffic, bandwidth |
| Latency | Latência | How fast the internet answers: Low Lag, Medium Lag, High Lag, Offline | ping |
| Temperature | Temperatura | CPU temperature in °C | temp, heat |
| Fan | Ventoinha | Fan speed in RPM and % of max | cooling |
| Battery | Bateria | Charge %, state, health %, charger watts | power |
| Battery health | Saúde da bateria | Max capacity as % of design capacity | condition, capacity |
| Charged / Charging / On Battery | Carregada / Carregando / Na Bateria | The battery states | plugged, unplugged |
| Process | Processo | One running program, with memory, % CPU, power, and PID | app, task |
| Top processes | Principais processos | The 5 processes using the most memory, in the popover | top apps |
| Menu bar style | Estilo na barra de menus | How each stat shows in the menu bar: "Icon and Value" or "Value Only" | display mode |
| Open MangoStats | Abrir MangoStats | Opens the Status window | show dashboard |
| Settings… | Ajustes… | Opens the Settings window (⌘,) | preferences, options |
| Quit MangoStats | Encerrar MangoStats | Quits the app (⌘Q) | exit, close |
| Power | Potência | A process's energy use in watts (PWR column) | energy impact, drain |
| Top drain | Quem mais gasta | The app using the most CPU now, shown on the Battery card | battery hog |
| Hot | Quente | A process over 20 % CPU: orange marker and value | high, busy |
| Sort by <column> | Ordenar por <coluna> | Order the process table by that column | order, arrange |
| Name or PID | Nome ou PID | What the process search matches | filter, query |
| Quit <name> | Encerrar <nome> | Ask a process to quit; it may ask to save | close, end, kill |
| Force Quit <name>… | Forçar Encerramento de <nome>… | End a process at once; unsaved work is lost | kill, terminate |
| Show in Activity Monitor | Mostrar no Monitor de Atividade | Open Activity Monitor | inspect |
| Copy PID | Copiar PID | Put the process ID on the clipboard | copy ID |
| Owned by another user | Pertence a outro usuário | Why Quit is unavailable for system processes | permission denied |
| Not in use / Camera in use / Mic in use | Sem uso / Câmera em uso / Microfone em uso | Whether an app is using the camera or microphone | recording, active |
| Awake / Can sleep | Acordado / Pode repousar | Whether an app keeps the Mac from sleeping | caffeinated, insomnia |
| Screen on / Screen can sleep | Tela ligada / A tela pode repousar | Whether an app keeps the display on | display awake |
| Open at login | Abrir ao iniciar sessão | Start MangoStats when you log in | launch at startup, auto-start |
| Refresh every | Atualizar a cada | Seconds between samples: 1, 2, or 5 | update rate, polling |
| Fan control | Controle da ventoinha | Letting MangoStats set the fan through its helper | fan override |
| Helper | Auxiliar | The small part of MangoStats that runs as root to set the fan | daemon, service, tool |
| Auto / Cool / Max | Auto / Frio / Máx | Fan modes: macOS decides / 60 % / full speed | quiet, turbo, boost |
| History | Histórico | Recorded stats over time, one averaged sample per minute | log, timeline, records |
| Hour / Day / Week / Month | Hora / Dia / Semana / Mês | The time range shown on the History page | period, span |
| Keep history for | Manter histórico por | How long recorded stats are kept | retention |
| Clear History… | Apagar Histórico… | Delete all recorded stats | reset, wipe |
| Alert | Alerta | A macOS notification MangoStats shows when a rule's condition holds | warning, notification (in UI) |
| Show alerts | Mostrar alertas | The master switch for all alerts | enable notifications |
| Busy app | App ocupado | One app using more CPU than its threshold for 5 minutes | hog, runaway |
| Send Test Alert | Enviar Alerta de Teste | Show a sample alert now | test notification |
| Network tab | Aba Rede | Where a connection problem is: path, router, Wi-Fi, internet, DNS, speed test, devices | diagnostics |
| Path | Caminho | This Mac → Wi-Fi → Router → ISP → Internet, a color per step | route, hops |
| Jitter | Jitter | How much latency varies between pings | variance |
| Loss | Perda | Share of pings that got no answer | drops |
| SNR | SNR | Wi-Fi signal above the noise, in dB; rated Excellent, Good, Fair, Poor | signal quality |
| Run Speed Test | Testar Velocidade | Measure download, upload, and responsiveness with Apple's networkQuality | bandwidth test |
| Responsiveness | Responsividade | Round trips per minute under load (RPM): High, Medium, Low | bufferbloat |
| Devices | Dispositivos | Things on the local network the Mac has seen, named when they announce themselves | clients, hosts |
| Insight | Vale uma olhada | The card that says what's worth a look and why | tip, alert |
| Hardware tab | Aba Hardware | Battery details, energy by app, and disk activity | system info |
| Energy used | Energia usada | Watt-hours an app used since it started | consumption |
| Disk activity | Atividade do disco | Bytes read and written per second | I/O |


The pt-BR column follows macOS's own Portuguese words: Ajustes, Encerrar, Forçar Encerramento, Itens de Início, Monitor de Atividade. Translations live in `Resources/pt-BR.lproj/Localizable.strings`; `tools/l10n-missing.py` lists any UI text without one.
