import SwiftUI

struct AppSectionTitle: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.brandGold, AppTheme.brandChalk],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 18)
            Text(text)
                .font(AppTheme.typography.sectionTitle)
                .foregroundStyle(AppTheme.brandInk)
            Spacer(minLength: 0)
        }
    }
}

struct AppCardSubheading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.brandInk)
    }
}

struct AppCardTitle: View {
    let text: String
    var lineLimit: Int? = nil

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(AppTheme.brandInk)
            .lineLimit(lineLimit)
    }
}

struct AppCardTitleWithVariant: View {
    let text: String
    let variant: String?
    var lineLimit: Int = 2

    private var resolvedVariant: String? {
        let trimmed = variant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        if let resolvedVariant {
            AppInlineTitleWithVariantLabel(
                title: text,
                variant: resolvedVariant,
                lineLimit: lineLimit,
                style: .card
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            AppCardTitle(text: text, lineLimit: lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AppMetricItem: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

struct AppMetricGrid: View {
    let items: [AppMetricItem]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.brandChalk)
                    Text(item.value)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.brandInk)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
