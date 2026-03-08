import SwiftUI

struct AppToolbarFilterTriggerLabel: View {
    var body: some View {
        Image(systemName: "line.3.horizontal.decrease.circle.fill")
            .font(.title3)
            .frame(width: 34, height: 34)
            .foregroundStyle(AppTheme.shellSelectedContent)
    }
}

struct AppToolbarSummaryText: View {
    let text: String

    var body: some View {
        Text(text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .truncationMode(.tail)
            .font(AppTheme.typography.filterSummary)
            .foregroundStyle(AppTheme.shellUnselectedContent)
    }
}

struct AppToolbarSummaryPair: View {
    let leading: String
    let trailing: String

    var body: some View {
        HStack(spacing: 12) {
            Text(leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .font(AppTheme.typography.filterSummary)
            Text(trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .font(AppTheme.typography.filterSummary)
        }
        .foregroundStyle(AppTheme.shellUnselectedContent)
    }
}

struct AppRefreshStatusRow: View {
    let updatedAtLabel: String
    let isRefreshing: Bool
    let hasNewerData: Bool
    let onRefresh: () -> Void

    var body: some View {
        Button(action: onRefresh) {
            HStack(spacing: 5) {
                Text(updatedAtLabel)
                if isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .opacity(hasNewerData ? 0.35 : 1)
                        .animation(
                            hasNewerData
                                ? .easeInOut(duration: 0.65).repeatForever(autoreverses: true)
                                : .default,
                            value: hasNewerData
                        )
                }
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.shellUnselectedContent)
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppDropdownMenuLabel: View {
    let text: String
    let isLargeTablet: Bool
    var widestText: String? = nil
    var fillsWidth: Bool = true
    var embeddedInNavigation: Bool = false

    var body: some View {
        Group {
            if let widestText {
                ZStack {
                    labelRow(text: widestText)
                        .opacity(0)
                    labelRow(text: text)
                }
            } else {
                labelRow(text: text)
            }
        }
        .padding(.horizontal, AppLayout.dropdownHorizontalPadding(isLargeTablet: isLargeTablet))
        .padding(.vertical, AppLayout.dropdownVerticalPadding(isLargeTablet: isLargeTablet))
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        .contentShape(Rectangle())
        .background {
            if embeddedInNavigation {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay {
            if embeddedInNavigation {
                Capsule()
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.6)
            }
        }
    }

    private func labelRow(text: String) -> some View {
        HStack(spacing: AppLayout.dropdownContentSpacing) {
            Text(text)
                .lineLimit(1)
                .font(AppLayout.dropdownTextFont(isLargeTablet: isLargeTablet))
                .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
            Spacer(minLength: fillsWidth ? 0 : 4)
            Image(systemName: "chevron.down")
                .font(AppLayout.dropdownChevronFont(isLargeTablet: isLargeTablet))
                .foregroundStyle(AppTheme.shellUnselectedContent)
        }
    }
}
