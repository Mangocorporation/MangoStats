# MangoStats design kit

## Feel
Warm, dense, glanceable. Measured from reference screenshots kept out of git (`local/reference/`), dark only.

The popover and the Status window are always dark (`.preferredColorScheme(.dark)`), like the
reference. Settings stays system (light or dark) with Apple's controls.

Measured with `design-from-app/scripts/measure.swift` on `status-window.png` (1000 × 675 pt)
and `menubar-popover.png` (window 340 pt wide). The screenshots are PNG captures,
so colors are rounded to clean values.

## Tokens

### Palette (raw colors, only `Tokens.swift` reads them)
| Name | Value | Measured from |
| --- | --- | --- |
| umber700 | #4D3B16 | window background, top (`vline 200`) |
| umber800 | #3B2E17 | window background at 32 % |
| umber850 | #302617 | window background at 53 % |
| umber900 | #2B2316 | window background, bottom |
| popTop | #3F3312 | popover background, top |
| popBottom | #16151B | popover background, bottom |
| snow | #FFFFFF | big numbers, process names |
| bone200 | #DCD9D6 | card headers (#D7D3D1), table numbers (#DCDBDB) |
| bone400 | #B6B1AA | secondary text, units, pills (#B2ADA3 … #B8B3AC) |
| bone500 | #ADA8A6 | table column headers |
| jade | #50C69A | CPU bars, CPU/battery icons (#52B98F) |
| jadeDeep | #56B68F | battery rings |
| apricot | #EEB07A | GPU line |
| butter | #FFEAA1 | memory line |
| honey | #F9C684 | disk bar end, gradient from #C9A777 |
| sky | #44BCFC | network line |
| hot | #FFDA90 | % CPU and power over the hot threshold, hot row marker |

### Meaning
| Token | Palette | Used for |
| --- | --- | --- |
| Ink.text | snow | big values, process names |
| Ink.label | bone200 | card headers, table numbers |
| Ink.secondary | bone400 | units, footers, pills |
| Ink.tertiary | bone500 | table column headers |
| Ink.hot | hot | values over the hot threshold |
| Ink.cpu / gpu / memory / disk / network / battery | jade / apricot / butter / honey / sky / jadeDeep | chart and icon color per stat |
| Ink.cardFill | white 4 % | card surface (#46391E on #3E3215) |
| Ink.cardStroke | white 6 % | card hairline (#50452B) |
| Ink.pillFill | white 7 % | pill background (#56472C on #4C3D1F) |
| Ink.track | white 8 % | empty part of bars |
| Ink.tableFill | black 12 % | process table surface (#383020) |
| Ink.selectedSegment | white 12 % | "Auto" in the fan segments |

### Metric
**`status-window.png` is a scaled capture.** Its text measures 0.70 of native sizes
("Google Chrome" 68.5 pt vs 95.5 pt at 13 pt; headers, footers and pills 0.67–0.73), while the popover's
text is native. So Status window layout values are the measured value × 1/0.70 (`Metric.zoom`), and fonts
keep native sizes. The hero number measured 0.875, so it is 28 pt.
The reference image also has a 6.5 pt window shadow on the left: the window itself is 993 × 664 in the capture.

| Token | Value | Why |
| --- | --- | --- |
| windowWidth × windowHeight | 1419 × 949 | 993 × 664 measured, × zoom |
| windowMargin | 14 | 10 measured, × zoom |
| windowTop | 44 | below the traffic lights; the reference has a tab bar we dropped (its cards start at 78 × zoom) |
| cardGap | 13 | 9 measured, × zoom |
| wideCardRatio | 1.416 | Health and Battery 303 vs 214 |
| cardHeight | 184 | 128.5 measured, × zoom |
| cardRadius | 16 | ≈ 12 measured at capture scale |
| cardPadding / cardPaddingBottom | 20 / 16 | header at +14, footer baseline 16 from the bottom, × zoom; tuned by compare |
| heroTop | 12 | header to hero, tuned by compare |
| popoverWidth / popoverMargin | 392 / 10 | 340 measured, but the popover capture is also scaled (text 0.78–0.87); 392 fits native text and two 181 pt card columns |
| popCardHeight / padding / chart | 122 / 14·12 / 14 | 108 at capture scale; 122 fits native text |
| pillHeight / radius | 18 / 5 | 13 at capture scale × zoom |
| chipHeight / radius | 22 / 6 | popover chips |
| bars | 10 × up to 16, gap 3 | 11 measured × zoom, tuned by compare |
| chartHeight / progressHeight | 28 / 8 | 20 and 6 measured × zoom |
| ringSize / stroke | 36 / 2.5 | 25 measured × zoom |
| segment | height 24, padding 17, gap 12 | 16.5, 42.5 wide, 7.5 gap × zoom |
| orbSize | 92 | 65 × zoom |
| rowHeight | 31 | 21.75 × zoom |
| table columns (from right) | more 42, PID 144, power 136, CPU 58 + bar 52, gap 92, memory 140 | right edges measured × zoom |

### Motion
| Token | Curve | Used for |
| --- | --- | --- |
| hover | ease out 0.12 s | row and button hover |
| value | ease in out 0.35 s | chart and bar changes |

## Type (system font, SF Pro, monospaced digits for numbers)
| Role | Size | Weight | Tracking | Used for |
| --- | --- | --- | --- | --- |
| cardHeader | 11.5 | semibold | 1.2, uppercase | "CPU", "FREE SPACE" (Status window) |
| popHeader | 12.5 | medium | 0 | "CPU", "Free space" (popover) |
| hero | 28 | semibold | 0 | "15", "99" in the Status window (measured 0.875 of 32 → 28) |
| popHero | 22 | semibold | 0 | popover big numbers |
| unit | 13 | medium | 0 | "%", "GB", "KB/s" |
| footer | 12.5 | regular | 0 | "idle · 0.9W" |
| pill | 11.5 | medium | 0 | "45°C", "100% Health" |
| health | 30 | bold | 0 | popover "84" |
| row | 13 | medium | 0 | process names |
| rowNumber | 12.5 | regular | 0 | memory, % CPU, power, PID |
| columnHeader | 10.5 | semibold | 1.2, uppercase | "NAME (156)", "MEM" |

## Icons
Source: SF Symbols, regular weight, 11 pt, tinted with the stat's color.
`KitIcon`: cpu, gpu, memory, disk, network, fan, battery, health (sun.max), bolt, laptop, waves,
camera, mic, cup (awake), display, search, more (ellipsis), window, gear, power.
SF Symbols at a light size, so the icons and the brand stay ours.

## Window
Status window: standard title bar (traffic lights only, no title), full-size content,
background gradient behind everything. Default size 1000 × 675. No sidebar.
Popover: `MenuBarExtra` window style, 340 wide, its own gradient background.

## Parts

### Stat card
Anatomy: header row (icon 11 + 6 gap + header text; trailing pill), hero row (value + 3 gap + unit),
chart area (flex), footer row (footer text; optional trailing text).
Size: padding 14, radius 12, fill cardFill, 1 pt stroke cardStroke. Height 128 in the window, 108 in the popover.
| State | Fill | Notes |
| --- | --- | --- |
| rest | cardFill | |
| hover (clickable cards only) | cardFill + white 3 % | Free space opens Finder |
| no data | cardFill | hero shows "--" in Ink.secondary |

### Pill
Text in Ink.secondary on pillFill, height 18, horizontal padding 6, radius 5. Hot variant: Ink.hot text.

### Chip (popover header)
Same as pill, height 22, padding 8, radius 6, 13 pt medium: "M5", "24 GB", "macOS 26.6.2", "up 51 days, 10 hrs".

### Bar history (CPU)
10 bars, gap 4, height up to 24, radius 2 top, fill jade at 90 %, minimum height 2.

### Line chart (GPU, network)
1.5 pt line in the stat color, rounded joins, 60 samples, no axis.

### Area chart (memory)
1.5 pt butter line on top, fill butter 35 % → 0 % downward.

### Progress bar (free space)
Height 8, radius 4, track Ink.track, fill gradient honey 60 % → honey.
In the popover: sky-ish blue fill (#5B7FB8) to match the reference.

### Ring button (battery)
32 × 32 circle, 2.5 pt ring jadeDeep at progress, track white 8 %, icon 11 in Ink.secondary.
States: rest, hover (fill white 6 %), pressed (fill white 10 %).

### Segment button (fan)
Capsule height 24, padding 14, 12.5 pt medium. Selected: selectedSegment fill, Ink.text.
Rest: white 4 % fill, Ink.secondary. Disabled: 50 % opacity, tooltip explains.

### Process row
Columns: hot marker (3 × 14, radius 1.5, Ink.hot, only when hot), app icon 16, gap 8, name (row),
memory (rowNumber, right), CPU mini bar (72 × 4, track + bone fill, hot fill when hot),
% CPU (right), power (right), PID (right), more button (ellipsis).
Height 21.75 (window), 27 (popover, no icon, no bar, no power, no PID).
| State | Fill | Notes |
| --- | --- | --- |
| rest | none | |
| hover | white 4 % | more button shows full opacity |
| hot | none | values in Ink.hot, marker shows |

### Health header
Popover: sun icon 18 in butter, "84" (health), "Good" (footer size in Ink.label), chips row below.
Window: a stat card with a planet image on the right (ours: a warm radial gradient sphere, not the reference's art).

### Status row (popover bottom)
Icon + word pairs in Ink.secondary 13 pt: camera + mic "Not in use", cup "Awake", display "Screen".

## Replaced (step 7)
- The reference app's mascot, name, upgrade button, and unrelated tabs: removed.
- The reference's drawn illustration: replaced by our own radial gradient sphere.
- The reference's custom icons: replaced by SF Symbols.
- Palette, spacing, and type stay measured from the reference: that is the look the user asked for.

## Compare results (step 6)
- CPU card, scaled to capture size: 5.9 % of pixels differ (mostly background tone and font antialiasing).
  Header, hero, chart and footer rows within 1.5 pt. Still above the 2 % target.
- Whole window: columns and left edges line up; rows are offset because the tab bar is gone (intended).
- Commands: `swift .../compare.swift <ref crop> <mine crop scaled to ref> <out>`; crops in the scratchpad.
