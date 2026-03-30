import SwiftUI

enum AppTableLayout {
    static func adjustedCellWidth(_ width: CGFloat, horizontalPadding: CGFloat) -> CGFloat {
        max(0, width - (horizontalPadding * 2))
    }
}

enum AppDividerStyle {
    static let tableHeader = AppTheme.brandChalk.opacity(0.38)
    static let tableRow = AppTheme.brandChalk.opacity(0.18)
    static let section = AppTheme.brandChalk.opacity(0.55)
}

struct AppTableHeaderDivider: View {
    var body: some View {
        Divider().overlay(AppDividerStyle.tableHeader)
    }
}

struct AppTableRowDivider: View {
    var body: some View {
        Divider().overlay(AppDividerStyle.tableRow)
    }
}

struct AppSectionDivider: View {
    var verticalPadding: CGFloat = 10

    var body: some View {
        Divider()
            .overlay(AppDividerStyle.section)
            .padding(.vertical, verticalPadding)
    }
}

struct AppHeaderCell: View {
    let title: String
    let width: CGFloat
    var alignment: Alignment = .leading
    var horizontalPadding: CGFloat = 4
    var largeText: Bool = false

    var body: some View {
        let adjustedWidth = AppTableLayout.adjustedCellWidth(width, horizontalPadding: horizontalPadding)
        Text(title)
            .font((largeText ? Font.footnote : Font.caption).weight(.semibold))
            .foregroundStyle(AppTheme.brandChalk)
            .frame(width: adjustedWidth, alignment: alignment)
            .padding(.horizontal, horizontalPadding)
    }
}
