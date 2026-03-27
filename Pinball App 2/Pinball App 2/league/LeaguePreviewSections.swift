import SwiftUI

struct TargetsPreview: View {
    let rows: [LeagueTargetPreviewRow]
    let bankLabel: String
    let metric: LeagueTargetMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(bankLabel)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("Game")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Text("\(metric.title) highest")
                    .id("target-metric-\(metric.rawValue)")
                    .transition(.opacity)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(metric.color)
            }

            if rows.isEmpty {
                AppInlineStatusMessage(text: "No target preview available yet")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(rows.prefix(5).indices, id: \.self) { index in
                        let row = rows[index]
                        HStack(spacing: 8) {
                            Text(row.game)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer(minLength: 6)

                            Text(metric.value(for: row).leagueHubFormattedWithCommas)
                                .id("target-\(row.order)-\(metric.rawValue)")
                                .transition(.opacity)
                                .font(.footnote.monospacedDigit().weight(.semibold))
                                .foregroundStyle(metric.color)
                                .lineLimit(1)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.0), value: metric.rawValue)
    }
}

struct StandingsPreview: View {
    let seasonLabel: String
    let mode: LeagueStandingsPreviewMode
    let topRows: [LeagueStandingsPreviewRow]
    let aroundRows: [LeagueStandingsPreviewRow]
    let currentPlayerRow: LeagueStandingsPreviewRow?
    @AppStorage(LPLNamePrivacySettings.showFullLastNameDefaultsKey) private var showFullLPLLastNames = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(seasonLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                AppTintedStatusChip(
                    text: mode.title,
                    foreground: AppTheme.statsMeanMedian,
                    compact: true
                )
                .id("standings-mode-title-\(mode.rawValue)")
                .transition(.opacity)
            }

            Group {
                switch mode {
                case .topFive:
                    if topRows.isEmpty {
                        AppInlineStatusMessage(text: "No standings preview available yet")
                    } else {
                        headerRow
                        standingsRows(topRows)

                        if let currentPlayerRow, currentPlayerRow.rank > 5 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.28))
                                .frame(height: 2)
                                .padding(.vertical, 1)

                            standingsRow(currentPlayerRow, emphasized: true)
                        }
                    }
                case .aroundYou:
                    if aroundRows.isEmpty {
                        AppInlineStatusMessage(text: "Set a league player name in Practice to enable Around You")
                            .lineLimit(1)
                    } else {
                        headerRow
                        standingsRows(aroundRows)
                    }
                }
            }
            .id("standings-mode-content-\(mode.rawValue)")
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 1.0), value: mode.rawValue)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("#")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)

            Text("Player")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)

            Text("Pts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func standingsRows(_ rows: [LeagueStandingsPreviewRow]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(rows) { row in
                standingsRow(row, emphasized: currentPlayerRow?.id == row.id)
            }
        }
    }

    private func standingsRow(_ row: LeagueStandingsPreviewRow, emphasized: Bool) -> some View {
        HStack(spacing: 0) {
            Text("\(row.rank)")
                .font(.footnote.monospacedDigit().weight(row.rank <= 3 ? .bold : .semibold))
                .foregroundStyle(rankColor(row.rank))
                .frame(width: 32, alignment: .leading)

            Text(displayLPLPlayerName(row.rawPlayer))
                .font(.footnote.weight(emphasized ? .semibold : .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)

            Text(row.points.leagueHubFormattedWholeNumber)
                .font(.footnote.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 78, alignment: .trailing)
        }
    }

    private func displayLPLPlayerName(_ raw: String) -> String {
        formatLPLPlayerNameForDisplay(raw, showFullLastNames: showFullLPLLastNames)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return AppTheme.podiumGold
        case 2: return AppTheme.podiumSilver
        case 3: return AppTheme.podiumBronze
        default: return .secondary
        }
    }
}

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
