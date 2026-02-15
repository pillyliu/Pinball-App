import SwiftUI
import Combine

private enum LeagueDestination: String, CaseIterable, Identifiable {
    case stats
    case standings
    case targets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stats: return "Stats"
        case .standings: return "Standings"
        case .targets: return "Targets"
        }
    }

    var subtitle: String {
        switch self {
        case .stats: return "Player trends and machine performance"
        case .standings: return "Season standings and bank breakdown"
        case .targets: return "Great game, main target, and floor goals"
        }
    }

    var icon: String {
        switch self {
        case .stats: return "chart.xyaxis.line"
        case .standings: return "list.number"
        case .targets: return "scope"
        }
    }
}

private enum LeagueTargetMetric: Int, CaseIterable {
    case second
    case fourth
    case eighth

    var title: String {
        switch self {
        case .second: return "2nd"
        case .fourth: return "4th"
        case .eighth: return "8th"
        }
    }

    var color: Color {
        switch self {
        case .second: return AppTheme.targetGreat
        case .fourth: return AppTheme.targetMain
        case .eighth: return AppTheme.targetFloor
        }
    }

    func value(for row: LeagueTargetPreviewRow) -> Int64 {
        switch self {
        case .second: return row.secondHighest
        case .fourth: return row.fourthHighest
        case .eighth: return row.eighthHighest
        }
    }
}

private enum LeagueStandingsPreviewMode: Int, CaseIterable {
    case topFive
    case aroundYou

    var title: String {
        switch self {
        case .topFive: return "Top 5"
        case .aroundYou: return "Around You"
        }
    }
}

private struct LeagueTargetPreviewRow {
    let game: String
    let secondHighest: Int64
    let fourthHighest: Int64
    let eighthHighest: Int64
    let bank: Int?
    let order: Int
}

private struct LeagueStandingsPreviewRow: Identifiable {
    let rank: Int
    let rawPlayer: String
    let displayPlayer: String
    let points: Double

    var id: String { "\(rank)-\(rawPlayer)" }
}

private struct LeagueStatsPreviewRow: Identifiable {
    let machine: String
    let score: Double
    let points: Double
    let order: Int

    var id: String { "\(order)-\(machine)" }
}

struct LeagueHubView: View {
    @StateObject private var previewModel = LeagueHubPreviewModel()

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    AppBackground()

                    let isLandscape = geo.size.width > geo.size.height
                    ScrollView {
                        if isLandscape {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12),
                                ],
                                spacing: 12
                            ) {
                                destinationCards
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 14)
                        } else {
                            VStack(spacing: 12) {
                                destinationCards
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 14)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await previewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private func destinationView(for destination: LeagueDestination) -> some View {
        switch destination {
        case .stats:
            StatsView(embeddedInNavigation: true)
                .navigationBarTitleDisplayMode(.inline)
        case .standings:
            StandingsView(embeddedInNavigation: true)
                .navigationBarTitleDisplayMode(.inline)
        case .targets:
            LPLTargetsView(embeddedInNavigation: true)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var destinationCards: some View {
        ForEach(LeagueDestination.allCases) { destination in
            NavigationLink {
                destinationView(for: destination)
            } label: {
                LeagueCard(destination: destination, previewModel: previewModel)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct LeagueCard: View {
    let destination: LeagueDestination
    @ObservedObject var previewModel: LeagueHubPreviewModel

    @State private var targetMetricIndex: Int = 0
    @State private var standingsModeIndex: Int = 0
    @State private var statsValueIndex: Int = 0

    private let targetMetricTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()
    private let standingsModeTimer = Timer.publish(every: 5.5, on: .main, in: .common).autoconnect()
    private let statsValueTimer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

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
            withAnimation(.easeInOut(duration: 0.75)) {
                targetMetricIndex = (targetMetricIndex + 1) % LeagueTargetMetric.allCases.count
            }
        }
        .onReceive(standingsModeTimer) { _ in
            guard destination == .standings else { return }
            guard previewModel.hasAroundYouStandings else { return }
            withAnimation(.easeInOut(duration: 0.75)) {
                standingsModeIndex = (standingsModeIndex + 1) % LeagueStandingsPreviewMode.allCases.count
            }
        }
        .onReceive(statsValueTimer) { _ in
            guard destination == .stats else { return }
            withAnimation(.easeInOut(duration: 0.75)) {
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
                playerLabel: previewModel.statsPlayerLabel,
                showScore: statsValueIndex == 0
            )
        }
    }
}

private struct TargetsPreview: View {
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
                Text("No target preview available yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

                            Text(metric.value(for: row).formattedWithCommas)
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
        .animation(.easeInOut(duration: 0.75), value: metric.rawValue)
    }
}

private struct StandingsPreview: View {
    let seasonLabel: String
    let mode: LeagueStandingsPreviewMode
    let topRows: [LeagueStandingsPreviewRow]
    let aroundRows: [LeagueStandingsPreviewRow]
    let currentPlayerRow: LeagueStandingsPreviewRow?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(seasonLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(mode.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.statsMeanMedian)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(AppTheme.statsMeanMedian.opacity(0.14), in: Capsule())
            }

            switch mode {
            case .topFive:
                if topRows.isEmpty {
                    Text("No standings preview available yet")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                    Text("Set a league player name in Practice to enable Around You")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    headerRow
                    standingsRows(aroundRows)
                }
            }
        }
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

            Text(row.displayPlayer)
                .font(.footnote.weight(emphasized ? .semibold : .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)

            Text(row.points.formattedWholeNumber)
                .font(.footnote.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 78, alignment: .trailing)
        }
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

private struct StatsPreview: View {
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
                Text("Tap to open full stats")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

                            Text(showScore ? row.score.formattedWholeNumber : row.points.formattedWholeNumber)
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
        .animation(.easeInOut(duration: 0.75), value: showScore)
    }
}

@MainActor
private final class LeagueHubPreviewModel: ObservableObject {
    @Published private(set) var nextBankTargets: [LeagueTargetPreviewRow] = []
    @Published private(set) var nextBankLabel: String = "Next Bank"

    @Published private(set) var standingsSeasonLabel: String = "Season"
    @Published private(set) var standingsTopRows: [LeagueStandingsPreviewRow] = []
    @Published private(set) var standingsAroundRows: [LeagueStandingsPreviewRow] = []
    @Published private(set) var currentPlayerStanding: LeagueStandingsPreviewRow?
    @Published private(set) var statsRecentRows: [LeagueStatsPreviewRow] = []
    @Published private(set) var statsRecentBankLabel: String = "Most Recent Bank"
    @Published private(set) var statsPlayerLabel: String = ""

    var hasAroundYouStandings: Bool { !standingsAroundRows.isEmpty }

    private var didLoad = false

    private static let targetsPath = "/pinball/data/LPL_Targets.csv"
    private static let standingsPath = "/pinball/data/LPL_Standings.csv"
    private static let statsPath = "/pinball/data/LPL_Stats.csv"
    private static let libraryPath = "/pinball/data/pinball_library.json"
    private static let practiceStorageKey = "practice-upgrade-state-v1"

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await loadPreviews()
    }

    private func loadPreviews() async {
        do {
            async let targetsResult = PinballDataCache.shared.loadText(path: Self.targetsPath)
            async let standingsResult = PinballDataCache.shared.loadText(path: Self.standingsPath, allowMissing: true)
            async let statsResult = PinballDataCache.shared.loadText(path: Self.statsPath, allowMissing: true)
            async let libraryResult = PinballDataCache.shared.loadText(path: Self.libraryPath, allowMissing: true)

            let (targetsTextResult, standingsTextResult, statsTextResult, libraryTextResult) = try await (targetsResult, standingsResult, statsResult, libraryResult)
            let selectedPlayer = loadPreferredLeaguePlayerName()

            if let targetsText = targetsTextResult.text {
                let targetRows = parseTargetRows(targetsText)
                let mergedRows = mergeTargetsWithLibrary(targetRows: targetRows, libraryJSON: libraryTextResult.text)
                let availableBanks = Set(mergedRows.compactMap(\.bank))
                if let nextBank = resolveNextBank(statsCSV: statsTextResult.text, availableBanks: availableBanks) {
                    let rowsForBank = mergedRows
                        .filter { $0.bank == nextBank }
                        .sorted { lhs, rhs in
                            if lhs.order == rhs.order {
                                return lhs.game.localizedCaseInsensitiveCompare(rhs.game) == .orderedAscending
                            }
                            return lhs.order < rhs.order
                        }
                    nextBankTargets = Array(rowsForBank.prefix(5))
                    nextBankLabel = "Next Bank • B\(nextBank)"
                }
            }

            if let standingsText = standingsTextResult.text {
                applyStandingsPreview(standingsCSV: standingsText, selectedPlayer: selectedPlayer)
            }

            if let statsText = statsTextResult.text {
                applyStatsPreview(statsCSV: statsText, preferredPlayer: selectedPlayer)
            } else {
                statsRecentRows = []
                statsRecentBankLabel = "Most Recent Bank"
                statsPlayerLabel = ""
            }

        } catch {
            nextBankTargets = []
            nextBankLabel = "Next Bank"
            standingsTopRows = []
            standingsAroundRows = []
            currentPlayerStanding = nil
            standingsSeasonLabel = "Season"
            statsRecentRows = []
            statsRecentBankLabel = "Most Recent Bank"
            statsPlayerLabel = ""
        }
    }

    private func applyStandingsPreview(standingsCSV: String, selectedPlayer: String?) {
        let rows = parseStandingsRows(standingsCSV)
        guard !rows.isEmpty else {
            standingsTopRows = []
            standingsAroundRows = []
            currentPlayerStanding = nil
            standingsSeasonLabel = "Season"
            return
        }

        let latestSeason = rows.map(\.season).max() ?? 0
        standingsSeasonLabel = latestSeason > 0 ? "Season \(latestSeason)" : "Season"

        let seasonRows = rows.filter { $0.season == latestSeason }
        guard !seasonRows.isEmpty else {
            standingsTopRows = []
            standingsAroundRows = []
            currentPlayerStanding = nil
            return
        }

        let hasRankForAll = seasonRows.allSatisfy { $0.rank != nil }
        let sortedRows: [ParsedStandingRow]
        if hasRankForAll {
            sortedRows = seasonRows.sorted { ($0.rank ?? Int.max) < ($1.rank ?? Int.max) }
        } else {
            sortedRows = seasonRows.sorted { $0.total > $1.total }
        }

        let previewRows = sortedRows.enumerated().map { index, row in
            LeagueStandingsPreviewRow(
                rank: row.rank ?? (index + 1),
                rawPlayer: row.player,
                displayPlayer: redactPlayerNameForDisplay(row.player),
                points: row.total
            )
        }

        standingsTopRows = Array(previewRows.prefix(5))

        guard let selectedPlayer, !selectedPlayer.isEmpty else {
            currentPlayerStanding = nil
            standingsAroundRows = []
            return
        }

        let normalizedSelected = normalizeHumanName(selectedPlayer)
        guard let selectedIndex = previewRows.firstIndex(where: { normalizeHumanName($0.rawPlayer) == normalizedSelected }) else {
            currentPlayerStanding = nil
            standingsAroundRows = []
            return
        }

        currentPlayerStanding = previewRows[selectedIndex]

        let totalCount = previewRows.count
        let selectedRank = selectedIndex + 1
        let startIndex: Int
        if selectedRank <= 3 {
            startIndex = 0
        } else if selectedRank >= totalCount - 2 {
            startIndex = max(0, totalCount - 5)
        } else {
            startIndex = max(0, selectedIndex - 2)
        }

        let endIndex = min(totalCount, startIndex + 5)
        standingsAroundRows = Array(previewRows[startIndex..<endIndex])
    }

    private func applyStatsPreview(statsCSV: String, preferredPlayer: String?) {
        let rows = parseStatsRows(statsCSV)
        guard !rows.isEmpty else {
            statsRecentRows = []
            statsRecentBankLabel = "Most Recent Bank"
            statsPlayerLabel = ""
            return
        }

        let selectedPlayer = resolvePlayerForStats(preferredPlayer: preferredPlayer, rows: rows)
        let normalizedSelected = normalizeHumanName(selectedPlayer)
        let selectedRows = rows.filter { normalizeHumanName($0.player) == normalizedSelected }

        guard !selectedRows.isEmpty else {
            statsRecentRows = []
            statsRecentBankLabel = "Most Recent Bank"
            statsPlayerLabel = ""
            return
        }

        let grouped = Dictionary(grouping: selectedRows, by: { "\($0.season)-\($0.bankNumber)" })

        let mostRecentKey = grouped.keys.max { lhs, rhs in
            guard let lhsRows = grouped[lhs], let rhsRows = grouped[rhs] else { return false }
            return latestSortValue(lhsRows) < latestSortValue(rhsRows)
        }

        guard let mostRecentKey,
              let mostRecentRows = grouped[mostRecentKey],
              let sample = mostRecentRows.first else {
            statsRecentRows = []
            statsRecentBankLabel = "Most Recent Bank"
            statsPlayerLabel = ""
            return
        }

        let previewRows = mostRecentRows
            .sorted { $0.sourceOrder < $1.sourceOrder }
            .prefix(5)
            .enumerated()
            .map { localIndex, row in
                LeagueStatsPreviewRow(
                    machine: row.machine,
                    score: row.rawScore,
                    points: row.points,
                    order: localIndex
                )
            }

        statsRecentRows = previewRows
        statsRecentBankLabel = "Most Recent • S\(sample.season) B\(sample.bankNumber)"
        statsPlayerLabel = redactPlayerNameForDisplay(sample.player)
    }

    private func resolvePlayerForStats(preferredPlayer: String?, rows: [ParsedStatsRow]) -> String {
        if let preferredPlayer, !preferredPlayer.isEmpty {
            let normalized = normalizeHumanName(preferredPlayer)
            if rows.contains(where: { normalizeHumanName($0.player) == normalized }) {
                return preferredPlayer
            }
        }

        if let latestRow = rows.max(by: { latestSortValue($0) < latestSortValue($1) }) {
            return latestRow.player
        }

        return rows[0].player
    }

    private func latestSortValue(_ row: ParsedStatsRow) -> Double {
        let dateValue = row.eventDate?.timeIntervalSince1970 ?? 0
        return (dateValue * 1_000_000) + Double(row.season * 100 + row.bankNumber)
    }

    private func latestSortValue(_ rows: [ParsedStatsRow]) -> Double {
        rows.map(latestSortValue).max() ?? 0
    }

    private func parseTargetRows(_ text: String) -> [LeagueTargetPreviewRow] {
        let table = parseCSVRows(text)
        guard let header = table.first else { return [] }

        let headers = header.map(normalizeCSVHeader)
        guard let gameIndex = headers.firstIndex(of: "game"),
              let secondIndex = headers.firstIndex(of: "second_highest_avg"),
              let fourthIndex = headers.firstIndex(of: "fourth_highest_avg"),
              let eighthIndex = headers.firstIndex(of: "eighth_highest_avg") else {
            return []
        }

        return table.dropFirst().compactMap { row in
            guard row.indices.contains(gameIndex),
                  row.indices.contains(secondIndex),
                  row.indices.contains(fourthIndex),
                  row.indices.contains(eighthIndex) else {
                return nil
            }

            let game = row[gameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !game.isEmpty else { return nil }

            return LeagueTargetPreviewRow(
                game: game,
                secondHighest: Int64(row[secondIndex]) ?? 0,
                fourthHighest: Int64(row[fourthIndex]) ?? 0,
                eighthHighest: Int64(row[eighthIndex]) ?? 0,
                bank: nil,
                order: Int.max
            )
        }
    }

    private func parseStandingsRows(_ text: String) -> [ParsedStandingRow] {
        let table = parseCSVRows(text)
        guard let header = table.first else { return [] }
        let headers = header.map(normalizeCSVHeader)

        guard let seasonIndex = headers.firstIndex(of: "season"),
              let playerIndex = headers.firstIndex(of: "player"),
              let totalIndex = headers.firstIndex(of: "total") else {
            return []
        }

        let rankIndex = headers.firstIndex(of: "rank")

        return table.dropFirst().compactMap { row in
            guard row.indices.contains(seasonIndex),
                  row.indices.contains(playerIndex),
                  row.indices.contains(totalIndex) else {
                return nil
            }

            let season = coerceSeasonNumber(row[seasonIndex])
            let player = row[playerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let total = Double(row[totalIndex]) ?? 0

            guard season > 0, !player.isEmpty else { return nil }

            let rank: Int?
            if let rankIndex, row.indices.contains(rankIndex) {
                rank = Int(row[rankIndex].trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                rank = nil
            }

            return ParsedStandingRow(season: season, player: player, total: total, rank: rank)
        }
    }

    private func parseStatsRows(_ text: String) -> [ParsedStatsRow] {
        let table = parseCSVRows(text)
        guard let header = table.first else { return [] }
        let headers = header.map(normalizeCSVHeader)

        guard let seasonIndex = headers.firstIndex(of: "season"),
              let bankIndex = headers.firstIndex(of: "banknumber"),
              let playerIndex = headers.firstIndex(of: "player"),
              let machineIndex = headers.firstIndex(of: "machine"),
              let scoreIndex = headers.firstIndex(of: "rawscore"),
              let pointsIndex = headers.firstIndex(of: "points") else {
            return []
        }

        let eventDateIndex = headers.firstIndex(of: "eventdate")

        return table.dropFirst().enumerated().compactMap { offset, row in
            guard row.indices.contains(seasonIndex),
                  row.indices.contains(bankIndex),
                  row.indices.contains(playerIndex),
                  row.indices.contains(machineIndex),
                  row.indices.contains(scoreIndex),
                  row.indices.contains(pointsIndex) else {
                return nil
            }

            let season = coerceSeasonNumber(row[seasonIndex])
            let bankNumber = Int(row[bankIndex].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let player = row[playerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let machine = row[machineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let score = Double(row[scoreIndex].replacingOccurrences(of: ",", with: "")) ?? 0
            let points = Double(row[pointsIndex].replacingOccurrences(of: ",", with: "")) ?? 0

            guard season > 0, bankNumber > 0, !player.isEmpty, !machine.isEmpty else { return nil }
            guard score > 0 || points > 0 else { return nil }

            let eventDate: Date?
            if let eventDateIndex, row.indices.contains(eventDateIndex) {
                eventDate = Self.eventDateFormatter.date(from: row[eventDateIndex].trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                eventDate = nil
            }

            return ParsedStatsRow(
                season: season,
                bankNumber: bankNumber,
                player: player,
                machine: machine,
                rawScore: score,
                points: points,
                eventDate: eventDate,
                sourceOrder: offset
            )
        }
    }

    private func mergeTargetsWithLibrary(targetRows: [LeagueTargetPreviewRow], libraryJSON: String?) -> [LeagueTargetPreviewRow] {
        guard let libraryJSON,
              let data = libraryJSON.data(using: .utf8),
              let games = try? JSONDecoder().decode([LeagueHubLibraryGame].self, from: data) else {
            return targetRows
        }

        let normalizedLibrary: [(normalizedName: String, bank: Int?, order: Int)] = games.enumerated().map { index, game in
            let weightedOrder: Int
            if let group = game.group, let pos = game.pos {
                weightedOrder = (group * 1000) + pos
            } else {
                weightedOrder = 100_000 + index
            }
            return (normalizeMachineName(game.name), game.bank, weightedOrder)
        }

        return targetRows.map { row in
            let normalizedTarget = normalizeMachineName(row.game)
            let aliases = Self.aliases[normalizedTarget] ?? []
            let candidateKeys = [normalizedTarget] + aliases

            let bestMatch = normalizedLibrary.first { entry in
                candidateKeys.contains(entry.normalizedName)
            } ?? normalizedLibrary.first { entry in
                candidateKeys.contains { key in
                    entry.normalizedName.contains(key) || key.contains(entry.normalizedName)
                }
            }

            guard let bestMatch else { return row }

            return LeagueTargetPreviewRow(
                game: row.game,
                secondHighest: row.secondHighest,
                fourthHighest: row.fourthHighest,
                eighthHighest: row.eighthHighest,
                bank: bestMatch.bank,
                order: bestMatch.order
            )
        }
    }

    private func resolveNextBank(statsCSV: String?, availableBanks: Set<Int>) -> Int? {
        let sortedBanks = availableBanks.sorted()
        guard !sortedBanks.isEmpty else { return nil }
        guard let statsCSV else { return sortedBanks.first }

        let statsRows = parseStatsRows(statsCSV)
        guard !statsRows.isEmpty else { return sortedBanks.first }

        let latestSeason = statsRows.map(\.season).max() ?? 0
        guard latestSeason > 0 else { return sortedBanks.first }

        let playedBanks = Set(
            statsRows
                .filter { $0.season == latestSeason && sortedBanks.contains($0.bankNumber) }
                .map(\.bankNumber)
        )

        if let lowestMissing = sortedBanks.first(where: { !playedBanks.contains($0) }) {
            return lowestMissing
        }

        return sortedBanks.first
    }

    private func loadPreferredLeaguePlayerName() -> String? {
        guard let raw = UserDefaults.standard.data(forKey: Self.practiceStorageKey),
              let state = try? JSONDecoder().decode(PracticeUpgradeState.self, from: raw) else {
            return nil
        }

        let trimmed = state.leagueSettings.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizeHumanName(_ raw: String) -> String {
        raw
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func normalizeMachineName(_ raw: String) -> String {
        let lowered = raw.lowercased().replacingOccurrences(of: "&", with: " and ")
        return lowered.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static let aliases: [String: [String]] = [
        "tmnt": ["teenagemutantninjaturtles"],
        "thegetaway": ["thegetawayhighspeedii"],
        "starwars2017": ["starwars"],
        "jurassicparkstern2019": ["jurassicpark", "jurassicpark2019"],
        "attackfrommars": ["attackfrommarsremake"],
        "dungeonsanddragons": ["dungeonsdragons"]
    ]

    private static let eventDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct ParsedStandingRow {
    let season: Int
    let player: String
    let total: Double
    let rank: Int?
}

private struct ParsedStatsRow {
    let season: Int
    let bankNumber: Int
    let player: String
    let machine: String
    let rawScore: Double
    let points: Double
    let eventDate: Date?
    let sourceOrder: Int
}

private struct LeagueHubLibraryGame: Decodable {
    let name: String
    let group: Int?
    let pos: Int?
    let bank: Int?
}

private extension Int64 {
    var formattedWithCommas: String {
        self.formatted(.number.grouping(.automatic))
    }
}

private extension Double {
    var formattedWholeNumber: String {
        Int(self.rounded()).formatted(.number.grouping(.automatic))
    }
}

#Preview {
    LeagueHubView()
}
