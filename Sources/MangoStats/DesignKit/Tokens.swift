import SwiftUI

// MangoStats design kit tokens, measured from design/reference/overview.png (design/KIT.md).
// Three layers: KitPalette (raw colors, this file only), Ink (meaning), and the
// scales KitType, Metric, Motion. The app is always dark. The accent follows
// Settings › Appearance (ThemeStore); Amber is the default.

/// Raw colors. Only this file reads them.
private enum KitPalette {
    static let coal = Color(hex: 0x17150F)       // window
    static let ash = Color(hex: 0x1D1A15)        // cards
    static let hairline = Color(hex: 0x2E2921)   // borders, tracks, selected chips
    static let chalk = Color(hex: 0xF3EEE6)      // primary text
    static let sand = Color(hex: 0xC9C0B1)       // body text, storage bar
    static let stone = Color(hex: 0xA39A8B)      // secondary text, labels
    static let pebble = Color(hex: 0x6F675B)     // faint text
    static let mint = Color(hex: 0x8FD3B0)       // calm: CPU, battery, live
    static let sky = Color(hex: 0x9DB8F5)        // network
    static let amber = Color(hex: 0xF2A93B)      // GPU (and the default accent)
    static let ink = Color(hex: 0x1A1408)        // text on the accent
    static let coral = Color(hex: 0xF0806A)      // critical
}

/// What a color means. Parts read only this layer.
enum Ink {
    static let text = KitPalette.chalk
    static let body = KitPalette.sand
    static let label = KitPalette.sand
    static let secondary = KitPalette.stone
    static let tertiary = KitPalette.stone
    static let faint = KitPalette.pebble

    /// The accent from Settings › Appearance: buttons, hot values, the top CPU bar, links.
    static var accent: Color { ThemeStore.shared.theme.tint ?? .accentColor }
    /// Text on an accent fill.
    static var onAccent: Color {
        let theme = ThemeStore.shared.theme
        return theme.darkText || theme.id == "amber" ? KitPalette.ink : .white
    }
    static var hot: Color { accent }
    static let warning = KitPalette.coral

    static let cpu = KitPalette.mint
    static let gpu = KitPalette.amber
    static var memory: Color { accent }
    static let disk = KitPalette.sand
    static let network = KitPalette.sky
    static let battery = KitPalette.mint
    static let health = KitPalette.mint
    static let live = KitPalette.mint

    static let windowBackground = KitPalette.coal
    static let popoverBackground = KitPalette.coal
    static let cardFill = KitPalette.ash
    static let cardStroke = KitPalette.hairline
    static let cardHover = Color.white.opacity(0.03)
    /// The insight card: the card tinted toward the accent (#221D14 / #4A3A1E with Amber).
    static var insightFill: Color { accent.opacity(0.045) }
    static var insightStroke: Color { accent.opacity(0.28) }
    static let pillFill = KitPalette.hairline
    static let liveFill = KitPalette.mint.opacity(0.12)
    static let track = KitPalette.hairline
    static let rowHover = Color.white.opacity(0.025)
    static let controlFill = KitPalette.ash
    static let controlHover = Color.white.opacity(0.05)
    static let controlPressed = Color.white.opacity(0.08)
    static let selectedSegment = KitPalette.hairline
    static let divider = KitPalette.hairline
    static let chartGrid = Color.white.opacity(0.05)
    static let tabSelected = KitPalette.chalk
    static let tabSelectedText = KitPalette.ink
}

/// Type roles. Views set fonts only through `.kitType(_:)`. Numbers and meta
/// lines are monospaced (SF Mono), like the reference.
enum KitType {
    case pageTitle, pageSubtitle, eyebrow, insightTitle, body, mono, sectionTitle
    case statLabel, statValue, statUnit, footer, pill
    case rowName, rowKind, rowNumber, columnHeader, button, segment
    // Popover
    case popValue, popLabel, popRow, popNumber
    // Kept for the History page.
    case cardHeader, popHeader, hero, popHero, unit, chip, health, healthWord, row

    var font: Font {
        switch self {
        case .pageTitle: .system(size: 28, weight: .bold)
        case .pageSubtitle: .system(size: 14.5)
        case .eyebrow: .system(size: 11.5, weight: .semibold)
        case .insightTitle: .system(size: 23, weight: .semibold)
        case .body: .system(size: 14)
        case .mono, .pill: .system(size: 12.5, design: .monospaced)
        case .sectionTitle: .system(size: 17, weight: .semibold)
        case .statLabel, .cardHeader, .popHeader: .system(size: 13.5)
        case .statValue, .hero: .system(size: 30, weight: .semibold).monospacedDigit()
        case .statUnit, .unit: .system(size: 14)
        case .footer: .system(size: 12.5).monospacedDigit()
        case .rowName, .row: .system(size: 14.5, weight: .medium)
        case .rowKind: .system(size: 12)
        case .rowNumber: .system(size: 13.5, design: .monospaced)
        case .columnHeader: .system(size: 11.5, weight: .medium)
        case .button: .system(size: 14, weight: .semibold)
        case .segment, .chip: .system(size: 13, weight: .medium)
        case .popValue, .popHero: .system(size: 22, weight: .semibold).monospacedDigit()
        case .popLabel: .system(size: 12.5)
        case .popRow: .system(size: 13, weight: .medium)
        case .popNumber: .system(size: 12, design: .monospaced)
        case .health: .system(size: 22, weight: .bold).monospacedDigit()
        case .healthWord: .system(size: 14.5)
        }
    }

    var tracking: CGFloat {
        switch self {
        case .eyebrow: 1.1
        case .columnHeader: 0.6
        case .pageTitle, .insightTitle: -0.3
        default: 0
        }
    }

    var uppercase: Bool { self == .eyebrow || self == .columnHeader }
}

extension View {
    func kitType(_ role: KitType) -> some View {
        font(role.font)
            .tracking(role.tracking)
            .textCase(role.uppercase ? .uppercase : nil)
    }
}

/// Sizes, measured from the reference (design/KIT.md, Metric).
nonisolated enum Metric {
    // Window (overview.png: 1392 pt content, 32 pt margins)
    static let windowWidth: CGFloat = 1360
    static let windowHeight: CGFloat = 920
    static let windowMinWidth: CGFloat = 1000
    static let windowMinHeight: CGFloat = 680
    static let windowMargin: CGFloat = 32
    /// Below the tab bar in the title bar band.
    static let windowTop: CGFloat = 56
    static let sectionGap: CGFloat = 32
    static let cardGap: CGFloat = 16
    static let cardRadius: CGFloat = 12
    static let cardPadding: CGFloat = 24
    static let cardPaddingBottom: CGFloat = 20
    static let cardStroke: CGFloat = 1
    static let insightPadding: CGFloat = 32
    static let insightHeight: CGFloat = 216
    static let insightRatio: CGFloat = 0.63
    static let statHeight: CGFloat = 170
    static let heroTop: CGFloat = 12

    // Popover
    static let popoverWidth: CGFloat = 380
    static let popoverMargin: CGFloat = 12
    static let popCardHeight: CGFloat = 104
    static let popCardPadding: CGFloat = 14
    static let popCardPaddingBottom: CGFloat = 12
    static let popChartHeight: CGFloat = 18
    static let popRowHeight: CGFloat = 30

    // Parts
    static let iconSize: CGFloat = 12
    static let iconGap: CGFloat = 6
    static let unitGap: CGFloat = 4
    static let pillHeight: CGFloat = 20
    static let pillPadding: CGFloat = 8
    static let pillRadius: CGFloat = 6
    static let liveHeight: CGFloat = 28
    static let buttonHeight: CGFloat = 40
    static let buttonPadding: CGFloat = 20
    static let buttonRadius: CGFloat = 10
    static let iconButton: CGFloat = 40
    static let smallIconButton: CGFloat = 28
    static let segmentHeight: CGFloat = 32
    static let segmentPadding: CGFloat = 14
    static let segmentInset: CGFloat = 4
    static let segmentRadius: CGFloat = 10
    static let segmentGap: CGFloat = 8
    static let compactSegmentHeight: CGFloat = 24
    static let compactSegmentPadding: CGFloat = 10
    static let compactSegmentGap: CGFloat = 4
    static let fieldWidth: CGFloat = 220
    static let searchWidth: CGFloat = 220

    static let lineWidth: CGFloat = 1.5
    static let chartHeight: CGFloat = 36
    static let progressHeight: CGFloat = 8
    static let barCount = 10
    static let barGap: CGFloat = 3
    static let barHeight: CGFloat = 16
    static let barRadius: CGFloat = 2

    // Process table (overview.png: 59 pt rows, 32 pt avatars)
    static let rowHeight: CGFloat = 58
    static let tableHeaderHeight: CGFloat = 44
    static let tableInset: CGFloat = 24
    static let avatar: CGFloat = 32
    static let avatarRadius: CGFloat = 8
    static let cpuBar = CGSize(width: 180, height: 6)
    static let colCPUValue: CGFloat = 64
    static let colMemory: CGFloat = 130
    static let colEnergy: CGFloat = 110
    static let colPID: CGFloat = 110
    static let colMore: CGFloat = 52
    static let colCPU: CGFloat = 58
    static let popColMemory: CGFloat = 80
    static let topProcesses = 13

    // Tab bar and History page
    static let tabHeight: CGFloat = 28
    static let tabPadding: CGFloat = 16
    static let tabBarTop: CGFloat = 10
    static let historyChartHeight: CGFloat = 120
    static let historyCardHeight: CGFloat = 196
    static let legendStroke: CGFloat = 3
    static let headerIcon: CGFloat = 18
}

enum Motion {
    static let hover = Animation.easeOut(duration: 0.12)
    /// Not used on live values: animating every 2 s sample cost ~1.3 % CPU with the
    /// popover open (2.77 % vs 1.3–1.6 %, tools/energy.sh, S-023).
    static let value = Animation.easeInOut(duration: 0.35)
}

/// A forced look for the gallery, so hover and pressed show in a snapshot.
enum KitForcedState: String, CaseIterable {
    case none, hover, pressed, disabled
}

extension EnvironmentValues {
    @Entry var kitForcedState: KitForcedState = .none
}
