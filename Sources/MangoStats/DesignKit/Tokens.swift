import SwiftUI

// MangoStats design kit tokens, measured from design/reference (design/KIT.md).
// Three layers: Palette (raw colors, this file only), Ink (meaning), and the
// scales KitType, Metric, Motion. The popover and Status window are always
// dark, like the reference, so each token has one value.

/// Raw colors. Only this file reads them.
private enum KitPalette {
    static let umber700 = Color(hex: 0x4D3B16)
    static let umber800 = Color(hex: 0x3B2E17)
    static let umber850 = Color(hex: 0x302617)
    static let umber900 = Color(hex: 0x2B2316)
    static let popTop = Color(hex: 0x3F3312)
    static let popBottom = Color(hex: 0x16151B)
    static let snow = Color(hex: 0xFFFFFF)
    static let bone200 = Color(hex: 0xDCD9D6)
    static let bone400 = Color(hex: 0xB6B1AA)
    static let bone500 = Color(hex: 0xADA8A6)
    static let jade = Color(hex: 0x50C69A)
    static let jadeDeep = Color(hex: 0x56B68F)
    static let apricot = Color(hex: 0xEEB07A)
    static let butter = Color(hex: 0xFFEAA1)
    static let honey = Color(hex: 0xF9C684)
    static let honeyDim = Color(hex: 0xC9A777)
    static let slate = Color(hex: 0x5B7FB8)
    static let sky = Color(hex: 0x44BCFC)
    static let hot = Color(hex: 0xFFDA90)
    static let ember = Color(hex: 0xE8603A)
}

/// What a color means. Parts read only this layer.
enum Ink {
    static let text = KitPalette.snow
    static let label = KitPalette.bone200
    static let secondary = KitPalette.bone400
    static let tertiary = KitPalette.bone500
    static let hot = KitPalette.hot
    static let warning = KitPalette.ember

    static let cpu = KitPalette.jade
    static let gpu = KitPalette.apricot
    static let memory = KitPalette.butter
    static let disk = KitPalette.honey
    static let diskStart = KitPalette.honeyDim
    static let diskPopover = KitPalette.slate
    static let network = KitPalette.sky
    static let battery = KitPalette.jadeDeep
    static let health = KitPalette.butter

    static let cardFill = Color.white.opacity(0.03)
    static let cardHover = Color.white.opacity(0.07)
    static let cardStroke = Color.white.opacity(0.06)
    static let pillFill = Color.white.opacity(0.07)
    static let track = Color.white.opacity(0.08)
    static let rowHover = Color.white.opacity(0.04)
    static let controlFill = Color.white.opacity(0.05)
    static let controlHover = Color.white.opacity(0.08)
    static let controlPressed = Color.white.opacity(0.12)
    static let selectedSegment = Color.white.opacity(0.14)
    static let divider = Color.white.opacity(0.07)

    /// Stops measured down the reference window (vline x 200): 0, 32 %, 53 %.
    static let windowBackground = LinearGradient(stops: [
        .init(color: KitPalette.umber700, location: 0),
        .init(color: KitPalette.umber800, location: 0.32),
        .init(color: KitPalette.umber850, location: 0.53),
        .init(color: KitPalette.umber900, location: 1),
    ], startPoint: .top, endPoint: .bottom)
    static let popoverBackground = LinearGradient(colors: [KitPalette.popTop, KitPalette.popBottom],
                                                  startPoint: .top, endPoint: .bottom)
}

/// Type roles. Views set fonts only through `.kitType(_:)`.
enum KitType {
    case cardHeader, popHeader, hero, popHero, unit, footer, pill, chip, health, healthWord
    case row, rowNumber, columnHeader, segment

    var font: Font {
        switch self {
        case .cardHeader: .system(size: 11.5, weight: .semibold)
        case .popHeader: .system(size: 12, weight: .medium)
        case .hero: .system(size: 28, weight: .semibold).monospacedDigit()
        case .popHero: .system(size: 22, weight: .semibold).monospacedDigit()
        case .unit: .system(size: 12.5, weight: .medium)
        case .footer: .system(size: 12.5, weight: .regular).monospacedDigit()
        case .pill: .system(size: 11.5, weight: .medium).monospacedDigit()
        case .chip: .system(size: 12, weight: .medium)
        case .health: .system(size: 30, weight: .bold).monospacedDigit()
        case .healthWord: .system(size: 15, weight: .medium)
        case .row: .system(size: 13, weight: .medium)
        case .rowNumber: .system(size: 12.5, weight: .regular).monospacedDigit()
        case .columnHeader: .system(size: 10.5, weight: .semibold)
        case .segment: .system(size: 12, weight: .medium)
        }
    }

    /// Letter spacing for the uppercase headers.
    var tracking: CGFloat {
        switch self {
        case .cardHeader, .columnHeader: 1.2
        default: 0
        }
    }

    var uppercase: Bool { self == .cardHeader || self == .columnHeader }
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
    // Status window. status-window.png is a capture scaled to 0.70 (its text
    // measures 0.70 of native sizes, the popover's does not), so measured
    // layout values are multiplied by `zoom` to get real points.
    private static let zoom: CGFloat = 1 / 0.7
    static let windowWidth: CGFloat = (993 * zoom).rounded()
    static let windowHeight: CGFloat = (664 * zoom).rounded()
    static let windowMinWidth: CGFloat = 1000
    static let windowMinHeight: CGFloat = 640
    static let windowMargin: CGFloat = 14
    /// Below the traffic lights. The reference has a tab bar here; we have none.
    static let windowTop: CGFloat = 44
    static let cardGap: CGFloat = 13
    /// Health and Battery are this many times wider than the other cards (303 / 214).
    static let wideCardRatio: CGFloat = 1.416
    static let cardHeight: CGFloat = (128.5 * zoom).rounded()
    static let cardRadius: CGFloat = 16
    static let cardPadding: CGFloat = 20
    /// The footer sits closer to the bottom edge than the header to the top.
    static let cardPaddingBottom: CGFloat = 16
    /// Header to big number.
    static let heroTop: CGFloat = 12
    static let cardStroke: CGFloat = 1

    // Popover
    /// 340 measured, but the popover capture is also scaled (text 0.78–0.87); 392 fits native text.
    static let popoverWidth: CGFloat = 392
    static let popoverMargin: CGFloat = 10
    /// 108 at the capture's scale; 122 fits native text.
    static let popCardHeight: CGFloat = 122
    static let popCardPadding: CGFloat = 14
    /// Popover charts, measured 14 pt in menubar-popover.png.
    static let popChartHeight: CGFloat = 14
    static let popCardPaddingBottom: CGFloat = 12

    static let iconSize: CGFloat = 11
    static let iconGap: CGFloat = 6
    static let unitGap: CGFloat = 3
    static let pillHeight: CGFloat = 18
    static let pillPadding: CGFloat = 6
    static let pillRadius: CGFloat = 5
    static let chipHeight: CGFloat = 22
    static let chipPadding: CGFloat = 8
    static let chipRadius: CGFloat = 6

    static let barCount = 10
    static let barGap: CGFloat = 3
    static let barHeight: CGFloat = 16
    static let barRadius: CGFloat = 2
    static let lineWidth: CGFloat = 1.5
    static let chartHeight: CGFloat = 28
    static let progressHeight: CGFloat = 8

    static let ringSize: CGFloat = 36
    static let ringStroke: CGFloat = 2.5
    static let segmentHeight: CGFloat = 24
    static let segmentPadding: CGFloat = 17
    static let segmentGap: CGFloat = 12
    static let compactSegmentHeight: CGFloat = 22
    static let compactSegmentPadding: CGFloat = 9
    static let compactSegmentGap: CGFloat = 4
    static let popColMemory: CGFloat = 80
    static let headerIcon: CGFloat = 20

    static let orbSize: CGFloat = 92

    // Process table: measured in the reference, times zoom.
    static let rowHeight: CGFloat = (21.75 * zoom).rounded()
    static let popRowHeight: CGFloat = 27
    static let tableHeaderHeight: CGFloat = 34
    static let tableInset: CGFloat = 24
    static let hotMarker = CGSize(width: 4, height: 18)
    static let appIcon: CGFloat = 18
    static let colMemory: CGFloat = 140
    static let colMemoryGap: CGFloat = 92
    static let miniBar = CGSize(width: 52, height: 5)
    static let colCPU: CGFloat = 58
    static let colPower: CGFloat = 136
    static let colPID: CGFloat = 144
    static let colMore: CGFloat = 42
}

enum Motion {
    static let hover = Animation.easeOut(duration: 0.12)
    static let value = Animation.easeInOut(duration: 0.35)
}

/// A forced look for the gallery, so hover and pressed show in a snapshot.
enum KitForcedState: String, CaseIterable {
    case none, hover, pressed, disabled
}

extension EnvironmentValues {
    @Entry var kitForcedState: KitForcedState = .none
}
