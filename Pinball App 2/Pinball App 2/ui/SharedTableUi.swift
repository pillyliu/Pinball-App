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

struct AppSectionTitle: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.brandGold, AppTheme.brandChalk],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 18)
            Text(text)
                .font(AppTheme.typography.sectionTitle)
                .foregroundStyle(AppTheme.brandInk)
            Spacer(minLength: 0)
        }
    }
}

struct AppCardSubheading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.brandInk)
    }
}

struct AppInlineStatusMessage: View {
    let text: String
    var isError: Bool = false

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(isError ? .red : AppTheme.brandChalk)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppInlineTaskStatus: View {
    let text: String
    var showsProgress: Bool = false
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(isError ? .red : AppTheme.brandGold)
            }
            AppInlineStatusMessage(text: text, isError: isError)
        }
    }
}

struct AppTablePlaceholder: View {
    let text: String
    var minHeight: CGFloat = 64

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(AppTheme.brandChalk)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
    }
}

struct AppPanelStatusCard: View {
    let text: String
    var showsProgress: Bool = false
    var isError: Bool = false

    var body: some View {
        AppInlineTaskStatus(
            text: text,
            showsProgress: showsProgress,
            isError: isError
        )
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadii.panel, style: .continuous)
                .fill(.regularMaterial)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppRadii.panel, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    (isError ? Color.red : AppTheme.brandGold).opacity(0.82),
                                    AppTheme.brandChalk.opacity(0.16)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 5)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadii.panel)
                        .stroke(AppTheme.brandChalk.opacity(0.28), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadii.panel, style: .continuous))
    }
}

struct AppPanelEmptyCard: View {
    let text: String

    var body: some View {
        AppTablePlaceholder(text: text, minHeight: 0)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                    .fill(AppTheme.controlBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                            .stroke(AppTheme.brandChalk.opacity(0.45), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
    }
}
