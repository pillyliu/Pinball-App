import SwiftUI

enum AppSpacing {
    static let screenHorizontal = AppTheme.spacing.screenHorizontal
    static let screenHorizontalLarge = AppTheme.spacing.screenHorizontalLarge
    static let screenVerticalCompact = AppTheme.spacing.screenVerticalCompact
    static let panelPadding = AppTheme.spacing.panelPadding
    static let controlHorizontal = AppTheme.spacing.controlHorizontal
    static let controlVertical = AppTheme.spacing.controlVertical
}

enum AppRadii {
    static let panel = AppTheme.shapes.panelCorner
    static let control = AppTheme.shapes.controlCorner
}

enum AppLayout {
    static func isLargeTablet(horizontalSizeClass: UserInterfaceSizeClass?, width: CGFloat) -> Bool {
        horizontalSizeClass == .regular && width >= 1000
    }

    static func contentHorizontalPadding(isLargeTablet: Bool) -> CGFloat {
        isLargeTablet ? AppSpacing.screenHorizontalLarge : AppSpacing.screenHorizontal
    }

    static func maxReadableContentWidth(isLargeTablet: Bool) -> CGFloat? {
        isLargeTablet ? 1180 : nil
    }

    static func maxTableWidthScale(isLargeTablet _: Bool) -> CGFloat {
        1.7
    }

    static func dropdownTextFont(isLargeTablet: Bool) -> Font {
        isLargeTablet ? AppTheme.typography.dropdownLarge : AppTheme.typography.dropdownCompact
    }

    static func dropdownChevronFont(isLargeTablet: Bool) -> Font {
        isLargeTablet ? AppTheme.typography.dropdownChevronLarge : AppTheme.typography.dropdownChevronCompact
    }

    static func dropdownHorizontalPadding(isLargeTablet: Bool) -> CGFloat {
        isLargeTablet ? AppSpacing.screenHorizontal : AppSpacing.controlHorizontal
    }

    static func dropdownVerticalPadding(isLargeTablet: Bool) -> CGFloat {
        isLargeTablet ? AppSpacing.screenVerticalCompact : AppSpacing.controlVertical
    }

    static var dropdownContentSpacing: CGFloat { 6 }
}
