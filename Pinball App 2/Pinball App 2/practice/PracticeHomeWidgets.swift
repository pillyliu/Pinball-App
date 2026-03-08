import SwiftUI

struct PracticeHubMiniCard: View {
    let destination: PracticeHubDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: destination.icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.brandGold)
                AppCardTitle(text: destination.label, lineLimit: 1)
            }
            Text(destination.subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.brandChalk)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 72, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .appPanelStyle()
    }
}
