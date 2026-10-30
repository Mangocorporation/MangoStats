# MangoStats design kit (v2)

## Feel
Calm, editorial, honest. Warm near-black surfaces, one accent, plain-language insight first,
numbers in monospace. Reference: `design/reference/overview.png` (our own mock, 1440 pt wide).
v1 copied another app's look; v2 replaces it entirely (2026-10-30).

The app is always dark. The **accent** follows Settings › Appearance (`ThemeStore`); Amber is the
default and the mock's color. Everything else is fixed.

## Tokens

### Palette (`Tokens.swift` only)
| Name | Value | Measured |
| --- | --- | --- |
| coal | #17150F | window |
| ash | #1D1A15 | cards |
| hairline | #2E2921 | borders, tracks, selected chips |
| chalk | #F3EEE6 | primary text |
| sand | #C9C0B1 | body text, storage bar |
| stone | #A39A8B | labels, secondary |
| pebble | #6F675B | faint ("--") |
| mint | #8FD3B0 | CPU, battery, live |
| sky | #9DB8F5 | network |
| amber | #F2A93B | GPU; default accent |
| ink | #1A1408 | text on the accent |
| coral | #F0806A | critical |

### Meaning
`Ink.accent` (theme) drives: primary buttons, the insight card's eyebrow, tint (accent 4.5 %) and
border (accent 28 %), the memory bar, the busiest process's CPU bar, the largest memory value, links,
hot values. Stat lines keep their own colors (mint, amber, sky).

### Metric
Window margin 32, section gap 32, card gap 16, card radius 12, card padding 24 (insight 32),
insight height 216 (63 % of the row), stat card 170, row 58, avatar 32 (radius 8), buttons 40 high
(radius 10), segmented 40 high with 4 inset, live pill 28. Default window 1360 × 920.

## Type (SF Pro + SF Mono)
| Role | Size | Weight | Use |
| --- | --- | --- | --- |
| pageTitle | 28 | bold | "Overview", "History" |
| pageSubtitle | 14.5 | regular | "Health 84 · Good — 2 things worth a look" |
| eyebrow | 11.5 | semibold, caps, 1.1 | "MEMORY IS TIGHT", "STORAGE" |
| insightTitle | 23 | semibold | "Google Chrome is holding 19,4 GB" |
| body | 14 | regular | insight text |
| mono | 12.5 | mono | "20,62 GB used of 24 GB", card details "37°C" |
| statLabel / statValue / statUnit | 13.5 / 30 semibold / 14 | | stat cards |
| sectionTitle | 17 | semibold | "Processes" |
| rowName / rowKind / rowNumber | 14.5 medium / 12 / 13.5 mono | | process rows |
| columnHeader | 11.5 | medium, caps | "NAME", "CPU" |

## Parts
- **Card**, **insight card** (tinted), **stat card**: label + mono detail, value + unit, sparkline, footer.
- **Live pill**: mint dot + "Live · every 2 s" on mint 12 %.
- **Buttons**: primary (accent fill), secondary (hairline outline), icon (square, optional outline), link.
- **Segmented control**: chips in a coal track with hairline border; selected chip hairline fill.
- **Field**: filter with magnifier, same track.
- **Process row**: letter avatar (filled for apps, outlined mono for background), name + kind,
  CPU bar (accent for the busiest) + value, memory (accent when it's the largest above 4 GB),
  energy, PID, "…" menu.
- **Fan mode menu**: the Fan card's "Auto ⌄" detail opens Auto / Cool / Max.
- Gallery: `APP_KIT_GALLERY=1 tools/snap.sh`.
