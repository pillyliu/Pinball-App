import SwiftUI

enum AppButtonPressFeedback {
    static let minimumHoldDuration: TimeInterval = 0
    static let pressAnimation: Animation? = nil
    static let releaseAnimation: Animation = .easeOut(duration: 0.08)
}

struct AppPressFeedbackButtonStyleBody<Content: View>: View {
    let isPressed: Bool
    let minimumHoldDuration: TimeInterval
    let pressAnimation: Animation?
    let releaseAnimation: Animation
    let content: (Bool) -> Content

    @State private var visualPressed = false
    @State private var pressStartedAt: Date?
    @State private var releaseTask: Task<Void, Never>?

    init(
        isPressed: Bool,
        minimumHoldDuration: TimeInterval = AppButtonPressFeedback.minimumHoldDuration,
        pressAnimation: Animation? = AppButtonPressFeedback.pressAnimation,
        releaseAnimation: Animation = AppButtonPressFeedback.releaseAnimation,
        @ViewBuilder content: @escaping (Bool) -> Content
    ) {
        self.isPressed = isPressed
        self.minimumHoldDuration = minimumHoldDuration
        self.pressAnimation = pressAnimation
        self.releaseAnimation = releaseAnimation
        self.content = content
    }

    var body: some View {
        content(visualPressed)
            .onAppear {
                visualPressed = isPressed
                if isPressed {
                    pressStartedAt = Date()
                }
            }
            .onChange(of: isPressed) { _, newValue in
                handlePressChange(newValue)
            }
            .onDisappear {
                releaseTask?.cancel()
                releaseTask = nil
            }
    }

    private func handlePressChange(_ newValue: Bool) {
        releaseTask?.cancel()
        releaseTask = nil

        if newValue {
            pressStartedAt = Date()
            guard !visualPressed else { return }
            setPressedState(true, animation: pressAnimation)
            return
        }

        let elapsed = Date().timeIntervalSince(pressStartedAt ?? Date())
        let remaining = max(0, minimumHoldDuration - elapsed)
        pressStartedAt = nil

        guard visualPressed else { return }

        if remaining == 0 {
            setPressedState(false, animation: releaseAnimation)
            return
        }

        releaseTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                setPressedState(false, animation: releaseAnimation)
                releaseTask = nil
            }
        }
    }

    private func setPressedState(_ pressed: Bool, animation: Animation?) {
        if let animation {
            withAnimation(animation) {
                visualPressed = pressed
            }
            return
        }

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            visualPressed = pressed
        }
    }
}

struct AppPrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fillsWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
        AppPressFeedbackButtonStyleBody(isPressed: configuration.isPressed) { isPressed in
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.brandOnGold.opacity(isEnabled ? 1 : 0.55))
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    shape
                        .fill(AppTheme.brandGold.opacity(isEnabled ? 0.94 : 0.28))
                        .overlay(
                            shape
                                .fill(AppTheme.brandInk.opacity(isEnabled && isPressed ? 0.24 : 0))
                        )
                        .overlay(
                            shape
                                .stroke(
                                    isEnabled ? AppTheme.brandGold.opacity(0.48) : AppTheme.brandGold.opacity(0.22),
                                    lineWidth: 1
                                )
                        )
                )
                .clipShape(shape)
        }
    }
}

struct AppSecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fillsWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        AppPressFeedbackButtonStyleBody(isPressed: configuration.isPressed) { isPressed in
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
                        .fill(AppTheme.controlBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .fill(AppTheme.brandGold.opacity(isEnabled && isPressed ? 0.16 : 0))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .stroke(AppTheme.brandGold.opacity(isEnabled ? (isPressed ? 0.56 : 0.34) : 0.18), lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
                .opacity(isEnabled ? 1 : 0.72)
                .scaleEffect(isPressed ? 0.985 : 1)
        }
    }
}

struct AppCompactSecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fillsWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        AppPressFeedbackButtonStyleBody(isPressed: configuration.isPressed) { isPressed in
            configuration.label
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.brandInk.opacity(isEnabled ? 1 : 0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                        .fill(AppTheme.controlBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .fill(AppTheme.brandGold.opacity(isEnabled && isPressed ? 0.16 : 0))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .stroke(AppTheme.brandGold.opacity(isEnabled ? (isPressed ? 0.56 : 0.34) : 0.18), lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
                .opacity(isEnabled ? 1 : 0.72)
                .scaleEffect(isPressed ? 0.985 : 1)
        }
    }
}

struct AppDestructiveActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fillsWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        AppPressFeedbackButtonStyleBody(isPressed: configuration.isPressed) { isPressed in
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEnabled ? Color.red : Color.red.opacity(0.55))
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                        .fill(Color.red.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .fill(Color.white.opacity(isEnabled && isPressed ? 0.14 : 0))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .stroke(Color.red.opacity(isEnabled ? (isPressed ? 0.52 : 0.34) : 0.18), lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
                .opacity(isEnabled ? 1 : 0.72)
                .scaleEffect(isPressed ? 0.985 : 1)
        }
    }
}

struct AppCompactIconActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        AppPressFeedbackButtonStyleBody(isPressed: configuration.isPressed) { isPressed in
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.brandInk.opacity(isEnabled ? 1 : 0.55))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                        .fill(AppTheme.controlBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .fill(AppTheme.brandGold.opacity(isEnabled && isPressed ? 0.16 : 0))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .stroke(AppTheme.brandGold.opacity(isEnabled ? (isPressed ? 0.56 : 0.34) : 0.18), lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
                .opacity(isEnabled ? 1 : 0.72)
                .scaleEffect(isPressed ? 0.97 : 1)
        }
    }
}

struct AppIconTileActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        AppPressFeedbackButtonStyleBody(isPressed: configuration.isPressed) { isPressed in
            configuration.label
                .foregroundStyle(AppTheme.brandInk.opacity(isEnabled ? 1 : 0.55))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                        .fill(AppTheme.controlBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .fill(AppTheme.brandGold.opacity(isEnabled && isPressed ? 0.16 : 0))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .stroke(AppTheme.brandGold.opacity(isEnabled ? (isPressed ? 0.56 : 0.34) : 0.18), lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
                .opacity(isEnabled ? 1 : 0.72)
                .scaleEffect(isPressed ? 0.985 : 1)
        }
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
        AppPressFeedbackButtonStyleBody(isPressed: configuration.isPressed) { isPressed in
            configuration.label
                .modifier(AppInlineActionChipStyle(isDestructive: isDestructive))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(isPressed ? 0.14 : 0))
                )
                .opacity(isPressed ? 0.92 : 1)
                .scaleEffect(isPressed ? 0.985 : 1)
        }
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
        HStack(spacing: compact ? 6 : 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(iconFont)
            Text(text)
                .lineLimit(2)
        }
        .font(textFont)
        .foregroundStyle(contentForeground)
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 5 : 9)
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

extension View {
    func appSegmentedControlStyle() -> some View {
        self
            .pickerStyle(.segmented)
            .tint(AppTheme.brandGold)
    }
}
