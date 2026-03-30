import SwiftUI

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
