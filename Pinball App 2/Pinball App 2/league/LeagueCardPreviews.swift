import SwiftUI
import Combine

struct LeagueCard: View {
    let destination: LeagueDestination
    @ObservedObject var previewModel: LeaguePreviewModel
    @AppStorage(LPLNamePrivacySettings.showFullLastNameDefaultsKey) private var showFullLPLLastNames = false

    @State private var targetMetricIndex: Int = 0
    @State private var standingsModeIndex: Int = 0
    @State private var statsValueIndex: Int = 0

    private let targetMetricTimer = Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()
    private let standingsModeTimer = Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()
    private let statsValueTimer = Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: destination.icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 20, alignment: .leading)
                Text(destination.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
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
        .onReceive(targetMetricTimer) { _ in
            guard destination == .targets else { return }
            withAnimation(.easeInOut(duration: 1.0)) {
                targetMetricIndex = (targetMetricIndex + 1) % LeagueTargetMetric.allCases.count
            }
        }
        .onReceive(standingsModeTimer) { _ in
            guard destination == .standings else { return }
            guard previewModel.hasAroundYouStandings else { return }
            withAnimation(.easeInOut(duration: 1.0)) {
                standingsModeIndex = (standingsModeIndex + 1) % LeagueStandingsPreviewMode.allCases.count
            }
        }
        .onReceive(statsValueTimer) { _ in
            guard destination == .stats else { return }
            withAnimation(.easeInOut(duration: 1.0)) {
                statsValueIndex = (statsValueIndex + 1) % 2
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch destination {
        case .targets:
            let metric = LeagueTargetMetric.allCases[targetMetricIndex]
            TargetsPreview(
                rows: previewModel.nextBankTargets,
                bankLabel: previewModel.nextBankLabel,
                metric: metric
            )

        case .standings:
            let mode: LeagueStandingsPreviewMode = {
                if previewModel.hasAroundYouStandings {
                    return LeagueStandingsPreviewMode.allCases[standingsModeIndex]
                }
                return .topFive
            }()
            StandingsPreview(
                seasonLabel: previewModel.standingsSeasonLabel,
                mode: mode,
                topRows: previewModel.standingsTopRows,
                aroundRows: previewModel.standingsAroundRows,
                currentPlayerRow: previewModel.currentPlayerStanding
            )
            .id("standings-mode-\(mode.rawValue)")
            .transition(.opacity)

        case .stats:
            StatsPreview(
                rows: previewModel.statsRecentRows,
                bankLabel: previewModel.statsRecentBankLabel,
                playerLabel: displayLPLPlayerName(previewModel.statsPlayerRawName),
                showScore: statsValueIndex == 0
            )
        }
    }

    private func displayLPLPlayerName(_ raw: String) -> String {
        _ = showFullLPLLastNames
        return formatLPLPlayerNameForDisplay(raw)
    }
}
