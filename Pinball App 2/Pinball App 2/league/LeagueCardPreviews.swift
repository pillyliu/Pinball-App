import SwiftUI

struct LeagueCard: View {
    let destination: LeagueDestination
    @ObservedObject var previewModel: LeaguePreviewModel
    @AppStorage(LPLNamePrivacySettings.showFullLastNameDefaultsKey) private var showFullLPLLastNames = false
    @StateObject private var rotationState = LeaguePreviewRotationState()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: destination.icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 20, alignment: .leading)
                AppCardTitle(text: destination.title)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(destination.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .padding(.leading, 28)

            preview
                .padding(.leading, 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .appPanelStyle()
    }

    @ViewBuilder
    private var preview: some View {
        switch destination {
        case .targets:
            TargetsPreview(
                rows: previewModel.nextBankTargets,
                bankLabel: previewModel.nextBankLabel,
                metric: rotationState.targetMetric
            )

        case .standings:
            let mode = rotationState.standingsMode(hasAroundYouStandings: previewModel.hasAroundYouStandings)
            StandingsPreview(
                seasonLabel: previewModel.standingsSeasonLabel,
                mode: mode,
                topRows: previewModel.standingsTopRows,
                aroundRows: previewModel.standingsAroundRows,
                currentPlayerRow: previewModel.currentPlayerStanding
            )
            .transition(.opacity)

        case .stats:
            StatsPreview(
                rows: previewModel.statsRecentRows,
                bankLabel: previewModel.statsRecentBankLabel,
                playerLabel: displayLPLPlayerName(previewModel.statsPlayerRawName),
                showScore: rotationState.showStatsScore
            )
        case .aboutLpl:
            Text("League details, schedule, and official links.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func displayLPLPlayerName(_ raw: String) -> String {
        formatLPLPlayerNameForDisplay(raw, showFullLastNames: showFullLPLLastNames)
    }
}
