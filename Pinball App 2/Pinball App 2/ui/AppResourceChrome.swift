import SwiftUI

struct PinballVideoLaunchButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        AppPressFeedbackButtonStyleBody(isPressed: configuration.isPressed) { isPressed in
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(isEnabled ? 1 : 0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                        .fill(Color.white.opacity(isPressed ? 0.28 : 0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .fill(Color.white.opacity(isEnabled && isPressed ? 0.08 : 0))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .stroke(
                                    Color.white.opacity(isEnabled ? (isPressed ? 0.66 : 0.26) : 0.16),
                                    lineWidth: 1
                                )
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
                .scaleEffect(isPressed ? 0.975 : 1)
                .opacity(isEnabled ? 1 : 0.72)
        }
    }
}

@ViewBuilder
func AppOverlayTitle(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(1.0), radius: 4, x: 0, y: 3)
        .lineSpacing(-1)
        .multilineTextAlignment(.leading)
}

@ViewBuilder
func AppOverlaySubtitle(_ title: String, emphasis: Double = 0.96) -> some View {
    Text(title)
        .font(.caption)
        .foregroundStyle(.white.opacity(emphasis))
        .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
}

@ViewBuilder
func AppReadingProgressPill(
    text: String,
    saved: Bool,
    pulseOpacity: Double = 1
) -> some View {
    let foreground = saved ? AppTheme.statsHigh : AppTheme.brandInk
    let background = saved ? AppTheme.statsHigh.opacity(0.18) : AppTheme.controlBg.opacity(0.88)
    let border = saved ? AppTheme.statsHigh.opacity(0.34) : AppTheme.brandGold.opacity(0.34)

    Text(text)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(background, in: Capsule())
        .overlay(
            Capsule()
                .stroke(border, lineWidth: 0.8)
        )
        .opacity(pulseOpacity)
}

func PinballShortRulesheetTitle(for link: PinballGame.ReferenceLink) -> String {
    link.shortRulesheetTitle
}

@ViewBuilder
func PinballMediaPreviewPlaceholder(
    message: String? = nil,
    showsProgress: Bool = false
) -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.atmosphereBottom.opacity(0.95))
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(AppTheme.brandChalk.opacity(0.2), lineWidth: 1)

        VStack(spacing: 8) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.brandGold)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(AppTheme.brandGold)
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.brandChalk)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(12)
    }
}

private struct PinballVideoTileChrome: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                selected
                    ? AppTheme.brandGold.opacity(0.14)
                    : AppTheme.controlBg.opacity(0.82)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        selected
                            ? AppTheme.brandGold.opacity(0.62)
                            : AppTheme.brandChalk.opacity(0.26),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension View {
    func pinballVideoTileChrome(selected: Bool) -> some View {
        modifier(PinballVideoTileChrome(selected: selected))
    }
}
