import SwiftUI

enum AppTableLayout {
    static func adjustedCellWidth(_ width: CGFloat, horizontalPadding: CGFloat) -> CGFloat {
        max(0, width - (horizontalPadding * 2))
    }
}

enum AppDividerStyle {
    static let tableHeader = Color(uiColor: .separator).opacity(0.35)
    static let tableRow = Color(uiColor: .separator).opacity(0.22)
    static let section = Color.primary.opacity(0.92)
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
            .foregroundStyle(.secondary)
            .frame(width: adjustedWidth, alignment: alignment)
            .padding(.horizontal, horizontalPadding)
    }
}

struct AppSectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTheme.typography.sectionTitle)
            .foregroundStyle(.primary)
    }
}

struct AppInlineStatusMessage: View {
    let text: String
    var isError: Bool = false

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(isError ? .red : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppTablePlaceholder: View {
    let text: String
    var minHeight: CGFloat = 64

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
    }
}
