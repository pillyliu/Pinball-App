import SwiftUI

struct SettingsProviderCaption: View {
    let prefix: String
    let linkText: String
    let urlString: String

    var body: some View {
        HStack(spacing: 0) {
            Text(prefix)
                .foregroundStyle(AppTheme.brandChalk)
            Link(linkText, destination: URL(string: urlString)!)
                .foregroundStyle(AppTheme.brandGold)
        }
        .font(.caption)
    }
}

struct SettingsImportResultRow: View {
    let title: String
    let subtitle: String
    let accessorySystemName: String
    var showsHighlightBadge = false
    var highlightBadgeText = ""

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    AppCardSubheading(text: title)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if showsHighlightBadge {
                        AppTintedStatusChip(
                            text: highlightBadgeText,
                            foreground: AppTheme.brandGold,
                            compact: true
                        )
                    }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            Image(systemName: accessorySystemName)
                .font(.title3)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 8)
    }
}
