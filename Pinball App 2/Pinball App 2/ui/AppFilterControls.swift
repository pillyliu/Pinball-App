import SwiftUI

struct AppPrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fillsWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.brandOnGold.opacity(isEnabled ? 1 : 0.55))
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                    .fill(AppTheme.brandGold.opacity(isEnabled ? (configuration.isPressed ? 0.74 : 0.94) : 0.28))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                            .stroke(AppTheme.brandGold.opacity(isEnabled ? 0.48 : 0.22), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppSecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fillsWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.brandInk.opacity(isEnabled ? 1 : 0.55))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                    .fill(AppTheme.controlBg.opacity(configuration.isPressed ? 0.92 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                            .stroke(AppTheme.brandGold.opacity(isEnabled ? 0.34 : 0.18), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
            .opacity(isEnabled ? 1 : 0.72)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppCompactSecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.brandInk.opacity(isEnabled ? 1 : 0.55))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                    .fill(AppTheme.controlBg.opacity(configuration.isPressed ? 0.92 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                            .stroke(AppTheme.brandGold.opacity(isEnabled ? 0.34 : 0.18), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
            .opacity(isEnabled ? 1 : 0.72)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppDestructiveActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fillsWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.red : Color.red.opacity(0.55))
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.14 : 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                            .stroke(Color.red.opacity(isEnabled ? 0.34 : 0.18), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
            .opacity(isEnabled ? 1 : 0.72)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppCompactIconActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.brandInk.opacity(isEnabled ? 1 : 0.55))
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                    .fill(AppTheme.controlBg.opacity(configuration.isPressed ? 0.92 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                            .stroke(AppTheme.brandGold.opacity(isEnabled ? 0.34 : 0.18), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
            .opacity(isEnabled ? 1 : 0.72)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppIconTileActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.brandInk.opacity(isEnabled ? 1 : 0.55))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                    .fill(AppTheme.controlBg.opacity(configuration.isPressed ? 0.92 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                            .stroke(AppTheme.brandGold.opacity(isEnabled ? 0.34 : 0.18), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
            .opacity(isEnabled ? 1 : 0.72)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppToolbarIconTriggerLabel: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.title3)
            .frame(width: 34, height: 34)
            .foregroundStyle(AppTheme.brandGold)
    }
}

struct AppToolbarFilterTriggerLabel: View {
    var body: some View {
        AppToolbarIconTriggerLabel(systemName: "line.3.horizontal.decrease.circle.fill")
    }
}

struct AppToolbarSearchTriggerLabel: View {
    var body: some View {
        AppToolbarIconTriggerLabel(systemName: "magnifyingglass")
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
            .foregroundStyle(AppTheme.brandChalk)
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
        .foregroundStyle(AppTheme.brandChalk)
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
            .foregroundStyle(AppTheme.brandChalk)
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
                    .stroke(AppTheme.brandGold.opacity(0.28), lineWidth: 0.8)
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
                .foregroundStyle(AppTheme.brandGold)
        }
    }
}

struct AppCompactDropdownLabel: View {
    let text: String
    var font: Font = .subheadline
    var minHeight: CGFloat = 36

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(font)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(AppTheme.brandInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.brandGold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: minHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appControlStyle()
    }
}

struct AppCompactFilterLabel: View {
    let text: String
    var font: Font = .subheadline
    var minHeight: CGFloat = 36

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(font)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(AppTheme.brandInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.brandGold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: minHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appControlStyle()
    }
}

struct AppCompactIconMenuLabel: View {
    let text: String
    let systemName: String
    var font: Font = .subheadline
    var minHeight: CGFloat = 36

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(font)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(AppTheme.brandInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: systemName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.brandGold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: minHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appControlStyle()
    }
}

struct AppExternalLinkButtonLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.brandInk)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .appControlStyle()
    }
}

struct AppCompactStackedMenuLabel: View {
    let title: String
    let value: String
    var minHeight: CGFloat = 36

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.brandChalk)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(AppTheme.brandInk)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.brandGold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: minHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appControlStyle()
    }
}

struct AppSelectableMenuRow: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.brandGold)
            }
            Text(text)
                .foregroundStyle(isSelected ? AppTheme.brandInk : Color.primary)
        }
    }
}

struct AppInlineActionChipStyle: ViewModifier {
    var isDestructive = false

    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.semibold))
            .foregroundStyle(isDestructive ? Color.red : AppTheme.brandInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.controlBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isDestructive ? Color.red.opacity(0.28) : AppTheme.brandGold.opacity(0.35), lineWidth: 1)
                    )
            )
    }
}

struct AppInlineActionChipButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(AppInlineActionChipStyle(isDestructive: isDestructive))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppPassiveStatusChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.brandInk)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.controlBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppTheme.brandGold.opacity(0.35), lineWidth: 1)
                    )
            )
    }
}

struct AppTintedStatusChip: View {
    let text: String
    let foreground: Color
    var compact = false

    var body: some View {
        Text(text)
            .font((compact ? Font.caption2 : Font.caption).weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 5)
            .background(
                Capsule()
                    .fill(foreground.opacity(0.16))
                    .overlay(
                        Capsule()
                            .stroke(foreground.opacity(0.28), lineWidth: 1)
                    )
            )
    }
}

struct AppMetricPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.brandChalk)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.brandInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.controlBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.brandGold.opacity(0.24), lineWidth: 1)
                )
        )
    }
}

struct AppSuccessBanner: View {
    let text: String
    var compact = false

    private var foreground: Color { AppTheme.statsHigh }

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Image(systemName: "checkmark.circle.fill")
                .font((compact ? Font.caption2 : Font.caption).weight(.semibold))
            Text(text)
                .lineLimit(2)
        }
        .font((compact ? Font.caption2 : Font.caption).weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 5 : 7)
        .background(
            Capsule()
                .fill(foreground.opacity(0.16))
                .overlay(
                    Capsule()
                        .stroke(foreground.opacity(0.28), lineWidth: 1)
                )
            )
    }
}

struct AppSwipeRevealActionButton: View {
    let systemName: String
    let foreground: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(foreground.opacity(0.16))
    }
}

extension View {
    func appSegmentedControlStyle() -> some View {
        self
            .pickerStyle(.segmented)
            .tint(AppTheme.brandGold)
    }
}
