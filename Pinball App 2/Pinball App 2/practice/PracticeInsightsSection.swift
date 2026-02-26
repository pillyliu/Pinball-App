import SwiftUI

struct PracticeInsightsSectionView: View {
    let games: [PinballGame]
    let librarySources: [PinballLibrarySource]
    let selectedLibrarySourceID: String?
    let onSelectLibrarySourceID: (String?) -> Void
    @Binding var selectedGameID: String
    let scoreSummaryForGame: (String) -> ScoreSummary?
    let scoreTrendValuesForGame: (String) -> [Double]

    let playerName: String
    @Binding var opponentName: String
    let opponentOptions: [String]
    let isLoadingHeadToHead: Bool
    let headToHead: HeadToHeadComparison?
    let redactName: (String) -> String
    let onRefreshHeadToHead: () async -> Void
    let onRefreshOpponentOptions: () async -> Void

    private var selectedGame: PinballGame? {
        games.first(where: { $0.canonicalPracticeKey == selectedGameID || $0.id == selectedGameID })
    }

    private var selectedGameName: String {
        guard !selectedGameID.isEmpty else { return "Select game" }
        if let game = games.first(where: { $0.canonicalPracticeKey == selectedGameID || $0.id == selectedGameID }) {
            return game.name
        }
        return "Select game"
    }

    private var orderedInsightGames: [PinballGame] {
        orderedGamesForDropdown(games, collapseByPracticeIdentity: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            insightsGameDropdown

            VStack(alignment: .leading, spacing: 8) {
                Text("Stats")
                    .font(.headline)

                if let gameID = selectedGame?.canonicalPracticeKey,
                   let summary = scoreSummaryForGame(gameID) {
                    HStack {
                        Text("Average")
                        Spacer()
                        Text(formattedScore(summary.average))
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Median")
                        Spacer()
                        Text(formattedScore(summary.median))
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Floor")
                        Spacer()
                        Text(formattedScore(summary.floor))
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.trailing)
                    }
                    Text("IQR: \(formattedScore(summary.p25)) to \(formattedScore(summary.p75))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Mode: Shows raw calendar spacing between score entries.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScoreTrendSparkline(values: scoreTrendValuesForGame(gameID))
                        .frame(height: 180)

                    HStack(spacing: 8) {
                        let spreadRatio = summary.median > 0 ? (summary.p75 - summary.floor) / summary.median : 0
                        MetricPill(label: "Consistency", value: spreadRatio >= 0.6 ? "High Risk" : "Stable")
                        MetricPill(label: "Floor", value: formattedScore(summary.floor))
                        MetricPill(label: "Median", value: formattedScore(summary.median))
                    }
                } else {
                    Text("Log scores to unlock trends and consistency analytics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Head-to-Head")
                        .font(.headline)
                    Spacer()
                    Button {
                        Task { await onRefreshHeadToHead() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingHeadToHead)
                }

                insightsOpponentDropdown

                if isLoadingHeadToHead {
                    ProgressView("Loading player comparison...")
                        .font(.footnote)
                } else if opponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Select a player above to enable player-vs-player views.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let scoped = headToHead {
                    HStack(spacing: 8) {
                        MetricPill(label: "Games", value: "\(scoped.totalGamesCompared)")
                        MetricPill(label: "You Lead", value: "\(scoped.gamesYouLeadByMean)")
                        MetricPill(label: "Avg Delta", value: signedScore(scoped.averageMeanDelta))
                    }

                    ForEach(Array(scoped.games.prefix(8))) { game in
                        HeadToHeadGameRow(game: game)
                    }
                    if scoped.games.count > 8 {
                        Text("Showing top 8 by mean delta.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    let chartGames = Array(scoped.games.prefix(8))
                    Rectangle()
                        .fill(Color.white.opacity(0.22))
                        .frame(height: 1)
                    HeadToHeadDeltaBars(games: chartGames)
                        .frame(height: headToHeadPlotHeight(for: chartGames.count))
                } else {
                    Text("No shared machine history yet between \(playerName.isEmpty ? "you" : redactName(playerName)) and \(redactName(opponentName)).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()
        }
        .task {
            await onRefreshOpponentOptions()
        }
        .task(id: "\(playerName)|\(opponentName)") {
            await onRefreshHeadToHead()
        }
    }

    private var insightsGameDropdown: some View {
        Menu {
            if librarySources.count > 1 {
                Button((selectedLibrarySourceID == nil ? "✓ " : "") + "All games") {
                    onSelectLibrarySourceID(nil)
                }
                ForEach(librarySources) { source in
                    Button((source.id == selectedLibrarySourceID ? "✓ " : "") + source.name) {
                        onSelectLibrarySourceID(source.id)
                    }
                }
                Divider()
            }

            if orderedInsightGames.isEmpty {
                Text("No game data")
            } else {
                ForEach(orderedInsightGames) { game in
                    Button(game.name) {
                        selectedGameID = game.canonicalPracticeKey
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedGameName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()
        }
    }

    private var insightsOpponentDropdown: some View {
        Menu {
            Button("Select player") {
                opponentName = ""
            }
            ForEach(opponentOptions, id: \.self) { name in
                Button(redactName(name)) {
                    opponentName = name
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(opponentName.isEmpty ? "Select player" : redactName(opponentName))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()
        }
    }

    private func headToHeadPlotHeight(for count: Int) -> CGFloat {
        guard count > 0 else { return 170 }
        let rowHeight: CGFloat = 20
        let rowSpacing: CGFloat = 6
        let rows = CGFloat(count)
        let content = (rows * rowHeight) + (max(0, rows - 1) * rowSpacing) + 14
        return max(170, content)
    }

    private func formattedScore(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    private func signedScore(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(formattedScore(value))"
    }
}
