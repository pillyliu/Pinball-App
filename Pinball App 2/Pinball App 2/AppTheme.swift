import SwiftUI

enum AppTheme {
    static let bg = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
    static let panel = Color(red: 23 / 255, green: 23 / 255, blue: 23 / 255)
    static let border = Color(red: 52 / 255, green: 52 / 255, blue: 52 / 255)
    static let controlBg = Color(red: 23 / 255, green: 23 / 255, blue: 23 / 255)
    static let controlBorder = Color(red: 64 / 255, green: 64 / 255, blue: 64 / 255)
    static let rowOdd = Color(red: 23 / 255, green: 23 / 255, blue: 23 / 255)
    static let rowEven = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
}

enum AppLayout {
    static func isLargeTablet(horizontalSizeClass: UserInterfaceSizeClass?, width: CGFloat) -> Bool {
        horizontalSizeClass == .regular && width >= 1000
    }

    static func contentHorizontalPadding(verticalSizeClass: UserInterfaceSizeClass?, isLargeTablet: Bool) -> CGFloat {
        if verticalSizeClass == .compact {
            return 2
        }
        return isLargeTablet ? 22 : 14
    }

    static func maxReadableContentWidth(isLargeTablet: Bool) -> CGFloat? {
        isLargeTablet ? 1180 : nil
    }

    static func maxTableWidthScale(isLargeTablet _: Bool) -> CGFloat {
        return 1.9
    }
}

struct AppBackground: View {
    var body: some View {
        AppTheme.bg
            .overlay(
                RadialGradient(
                    colors: [Color(red: 56 / 255, green: 189 / 255, blue: 248 / 255).opacity(0.13), .clear],
                    center: .init(x: 0.2, y: -0.1),
                    startRadius: 0,
                    endRadius: 520
                )
            )
            .ignoresSafeArea()
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
            .background(AppTheme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.border, lineWidth: 1)
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
}
