import SwiftUI

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
    Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.brandInk)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
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
