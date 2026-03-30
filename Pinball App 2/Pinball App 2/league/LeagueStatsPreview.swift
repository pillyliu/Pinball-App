import SwiftUI

struct StatsPreview: View {
    let rows: [LeagueStatsPreviewRow]
    let bankLabel: String
    let playerLabel: String
    let showScore: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(bankLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !playerLabel.isEmpty {
                    Spacer(minLength: 0)
                    Text(playerLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack(spacing: 8) {
                Text("Game")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Text(showScore ? "Score" : "Pts")
                    .id("stats-header-\(showScore)")
                    .transition(.opacity)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(showScore ? AppTheme.statsHigh : AppTheme.statsMeanMedian)
            }

            if rows.isEmpty {
                AppInlineStatusMessage(text: "Tap to open full stats")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            Text(row.machine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer(minLength: 6)

                            Text(showScore ? row.score.leagueHubFormattedWholeNumber : row.points.leagueHubFormattedWholeNumber)
                                .id("stats-\(row.id)-\(showScore)")
                                .transition(.opacity)
                                .font(.footnote.monospacedDigit().weight(.semibold))
                                .foregroundStyle(showScore ? AppTheme.statsHigh : AppTheme.statsMeanMedian)
                                .lineLimit(1)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.0), value: showScore)
    }
}
