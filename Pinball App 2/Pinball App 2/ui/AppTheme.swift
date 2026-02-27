import SwiftUI
import UIKit

enum AppTheme {
    static let bg = Color(uiColor: .systemBackground)
    static let panel = Color(uiColor: .secondarySystemBackground)
    static let border = Color(uiColor: .separator)
    static let controlBg = Color(uiColor: .secondarySystemFill)
    static let controlBorder = Color(uiColor: .separator)
    static let rowOdd = Color(uiColor: .secondarySystemBackground)
    static let rowEven = Color(uiColor: .tertiarySystemBackground)

    static let statsHigh = dynamicColor(light: UIColor(red: 0.12, green: 0.55, blue: 0.30, alpha: 1), dark: UIColor(red: 110 / 255, green: 231 / 255, blue: 183 / 255, alpha: 1))
    static let statsLow = dynamicColor(light: UIColor(red: 0.77, green: 0.23, blue: 0.23, alpha: 1), dark: UIColor(red: 252 / 255, green: 165 / 255, blue: 165 / 255, alpha: 1))
    static let statsMeanMedian = dynamicColor(light: UIColor(red: 0.09, green: 0.39, blue: 0.78, alpha: 1), dark: UIColor(red: 125 / 255, green: 211 / 255, blue: 252 / 255, alpha: 1))

    static let podiumGold = dynamicColor(light: UIColor(red: 0.48, green: 0.35, blue: 0.00, alpha: 1), dark: UIColor(red: 1.00, green: 0.87, blue: 0.44, alpha: 1))
    static let podiumSilver = dynamicColor(light: UIColor(red: 0.30, green: 0.33, blue: 0.38, alpha: 1), dark: UIColor(red: 0.94, green: 0.95, blue: 0.96, alpha: 1))
    static let podiumBronze = dynamicColor(light: UIColor(red: 0.48, green: 0.25, blue: 0.08, alpha: 1), dark: UIColor(red: 1.00, green: 0.76, blue: 0.57, alpha: 1))

    static let targetGreat = dynamicColor(light: UIColor(red: 0.12, green: 0.55, blue: 0.30, alpha: 1), dark: UIColor(red: 0.73, green: 0.96, blue: 0.82, alpha: 1))
    static let targetMain = dynamicColor(light: UIColor(red: 0.09, green: 0.39, blue: 0.78, alpha: 1), dark: UIColor(red: 0.75, green: 0.86, blue: 0.99, alpha: 1))
    static let targetFloor = dynamicColor(light: UIColor(red: 0.35, green: 0.38, blue: 0.43, alpha: 1), dark: UIColor(red: 0.90, green: 0.91, blue: 0.92, alpha: 1))
    static let rulesheetLink = dynamicColor(light: UIColor(red: 0.04, green: 0.40, blue: 0.80, alpha: 1), dark: UIColor(red: 0.65, green: 0.78, blue: 1.0, alpha: 1))

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}

enum AppLayout {
    static func isLargeTablet(horizontalSizeClass: UserInterfaceSizeClass?, width: CGFloat) -> Bool {
        horizontalSizeClass == .regular && width >= 1000
    }

    static func contentHorizontalPadding(isLargeTablet: Bool) -> CGFloat {
        return isLargeTablet ? 22 : 14
    }

    static func maxReadableContentWidth(isLargeTablet: Bool) -> CGFloat? {
        isLargeTablet ? 1180 : nil
    }

    static func maxTableWidthScale(isLargeTablet _: Bool) -> CGFloat {
        return 1.7
    }

    static func dropdownTextFont(isLargeTablet: Bool) -> Font {
        isLargeTablet ? .callout : .footnote
    }

    static func dropdownChevronFont(isLargeTablet: Bool) -> Font {
        isLargeTablet ? .footnote : .caption
    }

    static func dropdownHorizontalPadding(isLargeTablet: Bool) -> CGFloat {
        isLargeTablet ? 14 : 12
    }

    static func dropdownVerticalPadding(isLargeTablet: Bool) -> CGFloat {
        isLargeTablet ? 8 : 6
    }

    static var dropdownContentSpacing: CGFloat { 6 }
}

struct AppBackground: View {
    var body: some View {
        AppTheme.bg.ignoresSafeArea()
    }
}

extension View {
    func appReadableWidth(maxWidth: CGFloat?) -> some View {
        self
            .frame(maxWidth: maxWidth ?? .infinity)
            .frame(maxWidth: .infinity)
    }

    func appPanelStyle() -> some View {
        self
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.border.opacity(0.7), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func appControlStyle() -> some View {
        self
            .background(AppTheme.controlBg)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.controlBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func appGlassControlStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.24))
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
    }

    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            },
            including: .gesture
        )
    }
}
