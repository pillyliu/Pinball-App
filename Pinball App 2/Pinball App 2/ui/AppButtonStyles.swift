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
