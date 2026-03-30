import SwiftUI

struct GameRoomVariantPill: View {
    enum Style {
        case mini
        case standard
        case machineTitle
        case editSelector

        var sharedStyle: AppVariantPillStyle {
            switch self {
            case .mini:
                return .mini
            case .standard:
                return .standard
            case .machineTitle:
                return .machineTitle
            case .editSelector:
                return .editSelector
            }
        }
    }

    let label: String
    var style: Style = .standard

    var body: some View {
        if style == .mini || style == .standard {
            Text(compactLabel)
                .font(style.sharedStyle.font)
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, style.sharedStyle.horizontalPadding)
                .padding(.vertical, style.sharedStyle.verticalPadding)
                .frame(maxWidth: style == .mini ? nil : 84)
                .background(AppTheme.brandGold.opacity(0.20), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.brandGold.opacity(0.42), lineWidth: 0.8)
                )
                .offset(y: style.sharedStyle.verticalOffset)
        } else {
            AppVariantPill(
                title: compactLabel,
                style: style.sharedStyle,
                maxWidth: 84
            )
        }
    }

    private var compactLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxAllowed = 7
        guard trimmed.count > maxAllowed else { return trimmed }
        let prefix = String(trimmed.prefix(max(0, maxAllowed - 1)))
        return prefix + "…"
    }
}

func gameRoomVariantBadgeLabel(variant: String?, title: String) -> String? {
    if let variant {
        let cleanedVariant = variant.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedVariant.isEmpty,
           cleanedVariant.lowercased() != "null",
           cleanedVariant.lowercased() != "none",
           cleanedVariant.lowercased() != "premium/le",
           cleanedVariant.lowercased() != "premium le",
           cleanedVariant.lowercased() != "premium-le" {
            return cleanedVariant
        }
    }

    let loweredVariant = variant?.lowercased() ?? ""
    let loweredTitle = title.lowercased()
    let source = "\(loweredVariant) \(loweredTitle)"

    if source.contains("limited edition") ||
        source.contains("(le") ||
        source.hasSuffix(" le") ||
        source.contains(" le)") {
        return "LE"
    }
    if source.contains("premium") {
        return "Premium"
    }
    if source.contains("(pro") ||
        source.hasSuffix(" pro") ||
        source.contains(" pro)") ||
        loweredVariant == "pro" {
        return "Pro"
    }
    return nil
}

func gameRoomVariantBadgeLabel(for machine: OwnedMachine) -> String? {
    gameRoomVariantBadgeLabel(variant: machine.displayVariant, title: machine.displayTitle)
}
