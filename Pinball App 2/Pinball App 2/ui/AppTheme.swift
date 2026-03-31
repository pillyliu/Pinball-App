import SwiftUI
import UIKit

struct AppSemanticColors {
    let background: Color
    let panel: Color
    let border: Color
    let brandInk: Color
    let brandGold: Color
    let brandOnGold: Color
    let brandChalk: Color
    let atmosphereTop: Color
    let atmosphereBottom: Color
    let atmosphereGlow: Color
    let controlBackground: Color
    let controlBorder: Color
    let rowOdd: Color
    let rowEven: Color
    let shellSelectedContent: Color
    let shellUnselectedContent: Color
    let statsHigh: Color
    let statsLow: Color
    let statsMeanMedian: Color
    let podiumGold: Color
    let podiumSilver: Color
    let podiumBronze: Color
    let targetGreat: Color
    let targetMain: Color
    let targetFloor: Color
    let rulesheetLink: Color
}

struct AppSpacingTokens {
    let screenHorizontal: CGFloat
    let screenHorizontalLarge: CGFloat
    let screenVerticalCompact: CGFloat
    let panelPadding: CGFloat
    let controlHorizontal: CGFloat
    let controlVertical: CGFloat
}

struct AppShapeTokens {
    let panelCorner: CGFloat
    let controlCorner: CGFloat
}

struct AppTypographyTokens {
    let sectionTitle: Font
    let emptyState: Font
    let filterSummary: Font
    let dropdownCompact: Font
    let dropdownLarge: Font
    let dropdownChevronCompact: Font
    let dropdownChevronLarge: Font
    let shellLabel: Font
    let tableCell: Font
}

struct AppStatusChromeTokens {
    let inlineSpacing: CGFloat
    let panelSpacing: CGFloat
    let panelAccentWidth: CGFloat
    let panelAccentHeight: CGFloat
    let panelPaddingHorizontal: CGFloat
    let panelPaddingVertical: CGFloat
    let emptyCardPaddingHorizontal: CGFloat
    let emptyCardPaddingVertical: CGFloat
    let refreshSpacing: CGFloat
    let successCompactSpacing: CGFloat
    let successRegularSpacing: CGFloat
    let successCompactHorizontal: CGFloat
    let successRegularHorizontal: CGFloat
    let successCompactVertical: CGFloat
    let successRegularVertical: CGFloat
}

struct AppAtmosphereTokens {
    let primaryGlowOpacity: Double
    let secondaryGlowOpacity: Double
}

enum AppTheme {
    static let colors = AppSemanticColors(
        background: Color(uiColor: .systemBackground),
        panel: Color(uiColor: .secondarySystemBackground),
        border: Color(uiColor: .separator),
        brandInk: dynamicColor(light: UIColor(red: 0.05, green: 0.11, blue: 0.23, alpha: 1), dark: UIColor(red: 0.82, green: 0.90, blue: 1.00, alpha: 1)),
        brandGold: dynamicColor(light: UIColor(red: 0.87, green: 0.69, blue: 0.16, alpha: 1), dark: UIColor(red: 1.00, green: 0.83, blue: 0.29, alpha: 1)),
        brandOnGold: dynamicColor(light: UIColor(red: 0.13, green: 0.11, blue: 0.04, alpha: 1), dark: UIColor(red: 0.16, green: 0.11, blue: 0.02, alpha: 1)),
        brandChalk: dynamicColor(light: UIColor(red: 0.37, green: 0.53, blue: 0.47, alpha: 1), dark: UIColor(red: 0.54, green: 0.72, blue: 0.66, alpha: 1)),
        atmosphereTop: dynamicColor(light: UIColor(red: 0.94, green: 0.96, blue: 1.00, alpha: 1), dark: UIColor(red: 0.07, green: 0.09, blue: 0.14, alpha: 1)),
        atmosphereBottom: dynamicColor(light: UIColor(red: 0.90, green: 0.93, blue: 0.98, alpha: 1), dark: UIColor(red: 0.10, green: 0.13, blue: 0.18, alpha: 1)),
        atmosphereGlow: dynamicColor(light: UIColor(red: 1.00, green: 0.86, blue: 0.45, alpha: 1), dark: UIColor(red: 1.00, green: 0.80, blue: 0.35, alpha: 1)),
        controlBackground: Color(uiColor: .secondarySystemFill),
        controlBorder: Color(uiColor: .separator),
        rowOdd: Color(uiColor: .secondarySystemBackground),
        rowEven: Color(uiColor: .tertiarySystemBackground),
        shellSelectedContent: Color.primary,
        shellUnselectedContent: Color.secondary,
        statsHigh: dynamicColor(light: UIColor(red: 0.12, green: 0.55, blue: 0.30, alpha: 1), dark: UIColor(red: 110 / 255, green: 231 / 255, blue: 183 / 255, alpha: 1)),
        statsLow: dynamicColor(light: UIColor(red: 0.77, green: 0.23, blue: 0.23, alpha: 1), dark: UIColor(red: 252 / 255, green: 165 / 255, blue: 165 / 255, alpha: 1)),
        statsMeanMedian: dynamicColor(light: UIColor(red: 0.09, green: 0.39, blue: 0.78, alpha: 1), dark: UIColor(red: 125 / 255, green: 211 / 255, blue: 252 / 255, alpha: 1)),
        podiumGold: dynamicColor(light: UIColor(red: 0.48, green: 0.35, blue: 0.00, alpha: 1), dark: UIColor(red: 1.00, green: 0.87, blue: 0.44, alpha: 1)),
        podiumSilver: dynamicColor(light: UIColor(red: 0.30, green: 0.33, blue: 0.38, alpha: 1), dark: UIColor(red: 0.94, green: 0.95, blue: 0.96, alpha: 1)),
        podiumBronze: dynamicColor(light: UIColor(red: 0.48, green: 0.25, blue: 0.08, alpha: 1), dark: UIColor(red: 1.00, green: 0.76, blue: 0.57, alpha: 1)),
        targetGreat: dynamicColor(light: UIColor(red: 0.12, green: 0.55, blue: 0.30, alpha: 1), dark: UIColor(red: 0.73, green: 0.96, blue: 0.82, alpha: 1)),
        targetMain: dynamicColor(light: UIColor(red: 0.09, green: 0.39, blue: 0.78, alpha: 1), dark: UIColor(red: 0.75, green: 0.86, blue: 0.99, alpha: 1)),
        targetFloor: dynamicColor(light: UIColor(red: 0.35, green: 0.38, blue: 0.43, alpha: 1), dark: UIColor(red: 0.90, green: 0.91, blue: 0.92, alpha: 1)),
        rulesheetLink: dynamicColor(light: UIColor(red: 0.04, green: 0.40, blue: 0.80, alpha: 1), dark: UIColor(red: 0.65, green: 0.78, blue: 1.0, alpha: 1))
    )

    static let spacing = AppSpacingTokens(
        screenHorizontal: 14,
        screenHorizontalLarge: 22,
        screenVerticalCompact: 8,
        panelPadding: 12,
        controlHorizontal: 12,
        controlVertical: 6
    )

    static let shapes = AppShapeTokens(
        panelCorner: 12,
        controlCorner: 10
    )

    static let typography = AppTypographyTokens(
        sectionTitle: .subheadline.weight(.semibold),
        emptyState: .footnote,
        filterSummary: .caption.weight(.semibold),
        dropdownCompact: .footnote,
        dropdownLarge: .callout,
        dropdownChevronCompact: .caption,
        dropdownChevronLarge: .footnote,
        shellLabel: .caption,
        tableCell: .caption
    )

    static let statusChrome = AppStatusChromeTokens(
        inlineSpacing: 8,
        panelSpacing: 10,
        panelAccentWidth: 5,
        panelAccentHeight: 36,
        panelPaddingHorizontal: 12,
        panelPaddingVertical: 10,
        emptyCardPaddingHorizontal: 10,
        emptyCardPaddingVertical: 6,
        refreshSpacing: 5,
        successCompactSpacing: 6,
        successRegularSpacing: 8,
        successCompactHorizontal: 8,
        successRegularHorizontal: 12,
        successCompactVertical: 5,
        successRegularVertical: 9
    )

    static let atmosphere = AppAtmosphereTokens(
        primaryGlowOpacity: 0.18,
        secondaryGlowOpacity: 0.12
    )

    static let bg = colors.background
    static let panel = colors.panel
    static let border = colors.border
    static let brandInk = colors.brandInk
    static let brandGold = colors.brandGold
    static let brandOnGold = colors.brandOnGold
    static let brandChalk = colors.brandChalk
    static let atmosphereTop = colors.atmosphereTop
    static let atmosphereBottom = colors.atmosphereBottom
    static let atmosphereGlow = colors.atmosphereGlow
    static let controlBg = colors.controlBackground
    static let controlBorder = colors.controlBorder
    static let rowOdd = colors.rowOdd
    static let rowEven = colors.rowEven
    static let shellSelectedContent = colors.shellSelectedContent
    static let shellUnselectedContent = colors.shellUnselectedContent
    static let statsHigh = colors.statsHigh
    static let statsLow = colors.statsLow
    static let statsMeanMedian = colors.statsMeanMedian
    static let podiumGold = colors.podiumGold
    static let podiumSilver = colors.podiumSilver
    static let podiumBronze = colors.podiumBronze
    static let targetGreat = colors.targetGreat
    static let targetMain = colors.targetMain
    static let targetFloor = colors.targetFloor
    static let rulesheetLink = colors.rulesheetLink

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}
