import SwiftUI

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
        HStack(spacing: AppTheme.statusChrome.inlineSpacing) {
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
        HStack(alignment: .center, spacing: AppTheme.statusChrome.panelSpacing) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
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
                .frame(width: AppTheme.statusChrome.panelAccentWidth)
                .frame(minHeight: AppTheme.statusChrome.panelAccentHeight, maxHeight: .infinity)
                .padding(.vertical, 2)

            AppInlineTaskStatus(
                text: text,
                showsProgress: showsProgress,
                isError: isError
            )
        }
        .padding(.horizontal, AppTheme.statusChrome.panelPaddingHorizontal)
        .padding(.vertical, AppTheme.statusChrome.panelPaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadii.panel, style: .continuous)
                .fill(.regularMaterial)
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
            .padding(.horizontal, AppTheme.statusChrome.emptyCardPaddingHorizontal)
            .padding(.vertical, AppTheme.statusChrome.emptyCardPaddingVertical)
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

struct AppInlineLinkAction: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .foregroundStyle(AppTheme.brandGold)
        }
        .buttonStyle(.plain)
    }
}

struct AppRefreshStatusRow: View {
    let updatedAtLabel: String
    let isRefreshing: Bool
    let hasNewerData: Bool
    let onRefresh: () -> Void

    var body: some View {
        Button(action: onRefresh) {
            HStack(spacing: AppTheme.statusChrome.refreshSpacing) {
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
            .foregroundStyle(AppTheme.brandChalk)
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppSuccessBanner: View {
    let text: String
    var compact = false
    var prominent = false

    private var foreground: Color { AppTheme.statsHigh }
    private var contentForeground: Color {
        prominent ? Color.white.opacity(0.98) : foreground
    }
    private var textFont: Font { compact ? .caption2.weight(.semibold) : .footnote.weight(.semibold) }
    private var iconFont: Font { compact ? .caption2.weight(.semibold) : .footnote.weight(.bold) }
    private var backgroundOpacity: Double {
        if prominent {
            return compact ? 0.56 : 0.76
        }
        return compact ? 0.18 : 0.26
    }
    private var strokeOpacity: Double {
        if prominent {
            return compact ? 0.72 : 0.92
        }
        return compact ? 0.3 : 0.42
    }

    var body: some View {
        HStack(
            spacing: compact
                ? AppTheme.statusChrome.successCompactSpacing
                : AppTheme.statusChrome.successRegularSpacing
        ) {
            Image(systemName: "checkmark.circle.fill")
                .font(iconFont)
            Text(text)
                .lineLimit(2)
        }
        .font(textFont)
        .foregroundStyle(contentForeground)
        .padding(
            .horizontal,
            compact ? AppTheme.statusChrome.successCompactHorizontal : AppTheme.statusChrome.successRegularHorizontal
        )
        .padding(
            .vertical,
            compact ? AppTheme.statusChrome.successCompactVertical : AppTheme.statusChrome.successRegularVertical
        )
        .background(
            Capsule()
                .fill(foreground.opacity(backgroundOpacity))
                .overlay(
                    Capsule()
                        .stroke(foreground.opacity(strokeOpacity), lineWidth: 1)
                )
        )
    }
}
