import SwiftUI

enum AppVariantPillStyle {
    case resource
    case mini
    case standard
    case machineTitle
    case editSelector

    var font: Font {
        switch self {
        case .resource:
            return .caption.weight(.semibold)
        case .mini:
            return .system(size: 10, weight: .semibold)
        case .standard:
            return .caption2.weight(.semibold)
        case .machineTitle:
            return .footnote.weight(.semibold)
        case .editSelector:
            return .subheadline.weight(.semibold)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .mini:
            return 6
        case .resource, .standard, .machineTitle, .editSelector:
            return 8
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .resource:
            return 4
        case .mini, .standard, .machineTitle, .editSelector:
            return 3
        }
    }
}

@ViewBuilder
func PinballResourceRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    HStack(alignment: .center, spacing: 8) {
        Text("\(title):")
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.brandChalk)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
    }
}

@ViewBuilder
func PinballUnavailableResourceChip(_ title: String = "Unavailable") -> some View {
    Text(title)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(AppTheme.brandChalk.opacity(0.92))
        .background(AppTheme.brandGold.opacity(0.08), in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.brandGold.opacity(0.22), lineWidth: 1)
        )
        .opacity(0.7)
        .allowsHitTesting(false)
}

@ViewBuilder
func PinballVariantBadge(_ title: String) -> some View {
    AppVariantPill(title: title, style: .resource)
}

@ViewBuilder
func AppVariantPill(
    title: String,
    style: AppVariantPillStyle = .resource,
    maxWidth: CGFloat? = nil
) -> some View {
    Text(title)
        .font(style.font)
        .foregroundStyle(AppTheme.brandInk)
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
        .frame(maxWidth: maxWidth)
        .background(AppTheme.brandGold.opacity(0.16), in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.brandGold.opacity(0.34), lineWidth: 0.8)
        )
}

@ViewBuilder
func PinballOverlayMetadataBadge(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.white.opacity(0.96))
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(AppTheme.brandInk.opacity(0.54), in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.brandGold.opacity(0.38), lineWidth: 0.7)
        )
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
    let border = saved ? AppTheme.statsHigh.opacity(0.34) : AppTheme.brandChalk.opacity(0.24)

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
    let label = link.label.lowercased()
    if label.contains("(tf)") { return "TF" }
    if label.contains("(pp)") { return "PP" }
    if label.contains("(papa)") { return "PAPA" }
    if label.contains("(bob)") { return "Bob" }
    if label.contains("(local)") || label.contains("(source)") { return "Local" }
    if link.destinationURL == nil && link.embeddedRulesheetSource == nil { return "Local" }
    return "Local"
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
