import SwiftUI

struct PinballResourceChipButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        AppPressFeedbackButtonStyleBody(isPressed: configuration.isPressed) { isPressed in
            configuration.label
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.brandInk.opacity(isEnabled ? 1 : 0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                        .fill(
                            isPressed
                                ? AppTheme.brandGold.opacity(isEnabled ? 0.24 : 0.14)
                                : AppTheme.controlBg
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .fill(Color.white.opacity(isEnabled && isPressed ? 0.14 : 0))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                                .stroke(
                                    AppTheme.brandGold.opacity(
                                        isEnabled
                                            ? (isPressed ? 0.74 : 0.34)
                                            : 0.18
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
                .scaleEffect(isPressed ? 0.975 : 1)
                .opacity(isEnabled ? 1 : 0.72)
        }
    }
}

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
    PinballResourceRowView(title: title, content: content())
}

private struct PinballResourceRowView<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let content: Content

    var body: some View {
        if horizontalSizeClass == .compact {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(title):")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.brandChalk)
                    .lineLimit(1)

                PinballChipWrapLayout(spacing: 8, rowSpacing: 8) {
                    content
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        } else {
            PinballResourceRowLayout(labelColumnWidth: 68, columnSpacing: 6) {
                Text("\(title):")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.brandChalk)
                    .lineLimit(1)

                PinballChipWrapLayout(spacing: 8, rowSpacing: 8) {
                    content
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
        }
    }
}

private struct PinballResourceRowLayout: Layout {
    let labelColumnWidth: CGFloat
    let columnSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }

        let resolvedRowWidth = proposal.width ?? fallbackRowWidth

        let labelProposal = ProposedViewSize(width: labelColumnWidth, height: proposal.height)
        let labelSize = subviews[0].sizeThatFits(labelProposal)

        let contentProposal = ProposedViewSize(
            width: max(resolvedRowWidth - labelColumnWidth - columnSpacing, 0),
            height: proposal.height
        )
        let contentSize = subviews[1].sizeThatFits(contentProposal)

        let width = proposal.width ?? resolvedRowWidth
        let height = max(labelSize.height, contentSize.height)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }

        let labelProposal = ProposedViewSize(width: labelColumnWidth, height: bounds.height)
        let labelSize = subviews[0].sizeThatFits(labelProposal)

        let contentWidth = max(bounds.width - labelColumnWidth - columnSpacing, 0)
        let contentProposal = ProposedViewSize(width: contentWidth, height: bounds.height)
        let contentSize = subviews[1].sizeThatFits(contentProposal)

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + (bounds.height - labelSize.height) / 2),
            anchor: .topLeading,
            proposal: labelProposal
        )

        subviews[1].place(
            at: CGPoint(x: bounds.minX + labelColumnWidth + columnSpacing, y: bounds.minY + (bounds.height - contentSize.height) / 2),
            anchor: .topLeading,
            proposal: contentProposal
        )
    }

    private var fallbackRowWidth: CGFloat {
        max(680, labelColumnWidth + columnSpacing)
    }
}

struct PinballChipWrapLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needsWrap = currentRowWidth > 0 && (currentRowWidth + spacing + size.width) > maxWidth

            if needsWrap {
                totalHeight += currentRowHeight + rowSpacing
                maxRowWidth = max(maxRowWidth, currentRowWidth)
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                if currentRowWidth > 0 {
                    currentRowWidth += spacing
                }
                currentRowWidth += size.width
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        if currentRowHeight > 0 {
            totalHeight += currentRowHeight
            maxRowWidth = max(maxRowWidth, currentRowWidth)
        }

        return CGSize(width: maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var cursorX = bounds.minX
        var cursorY = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextMaxX = cursorX == bounds.minX ? cursorX + size.width : cursorX + spacing + size.width

            if nextMaxX > bounds.maxX, cursorX > bounds.minX {
                cursorX = bounds.minX
                cursorY += currentRowHeight + rowSpacing
                currentRowHeight = 0
            }

            if cursorX > bounds.minX {
                cursorX += spacing
            }

            subview.place(
                at: CGPoint(x: cursorX, y: cursorY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            cursorX += size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }
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
