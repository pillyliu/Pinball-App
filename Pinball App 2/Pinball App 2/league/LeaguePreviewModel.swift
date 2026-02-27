import SwiftUI
import Combine

@MainActor
final class LeaguePreviewModel: ObservableObject {
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
    private static let libraryPath = "/pinball/data/pinball_library_v3.json"

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
                if let nextBank = resolveNextBank(
                    statsCSV: statsTextResult.text,
                    availableBanks: availableBanks,
                    preferredPlayer: selectedPlayer
                ) {
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

        let sortedMostRecentRows = mostRecentRows
            .sorted { $0.sourceOrder < $1.sourceOrder }

        let rowsForPreview: [ParsedStatsRow] = {
            guard sortedMostRecentRows.count > 5 else { return sortedMostRecentRows }
            let nonZeroScoreRows = sortedMostRecentRows.filter { abs($0.rawScore) > 0.000_001 }
            return nonZeroScoreRows.count >= 5 ? nonZeroScoreRows : sortedMostRecentRows
        }()

        let previewRows = rowsForPreview
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
              let root = try? JSONDecoder().decode(LeagueLibraryGameRoot.self, from: data) else {
            return targetRows
        }
        let games = root.items

        let normalizedLibrary: [(normalizedName: String, bank: Int?, order: Int)] = games.enumerated().map { index, game in
            let weightedOrder: Int
            if let group = game.group, let position = game.position {
                weightedOrder = (group * 1000) + position
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

    private func resolveNextBank(statsCSV: String?, availableBanks: Set<Int>, preferredPlayer: String?) -> Int? {
        let sortedBanks = availableBanks.sorted()
        guard !sortedBanks.isEmpty else { return nil }
        guard let statsCSV else { return sortedBanks.first }

        let statsRows = parseStatsRows(statsCSV)
        guard !statsRows.isEmpty else { return sortedBanks.first }

        let scopedRows = scopedStatsRows(statsRows, preferredPlayer: preferredPlayer)
        guard !scopedRows.isEmpty else { return sortedBanks.first }

        let latestSeason = scopedRows.map(\.season).max() ?? 0
        guard latestSeason > 0 else { return sortedBanks.first }

        let playedBanks = Set(
            scopedRows
                .filter { $0.season == latestSeason && sortedBanks.contains($0.bankNumber) }
                .map(\.bankNumber)
        )

        if let lowestMissing = sortedBanks.first(where: { !playedBanks.contains($0) }) {
            return lowestMissing
        }

        return sortedBanks.first
    }

    private func scopedStatsRows(_ rows: [ParsedStatsRow], preferredPlayer: String?) -> [ParsedStatsRow] {
        guard let preferredPlayer, !preferredPlayer.isEmpty else { return rows }
        let normalizedPreferred = normalizeHumanName(preferredPlayer)
        let selectedRows = rows.filter { normalizeHumanName($0.player) == normalizedPreferred }
        return selectedRows.isEmpty ? rows : selectedRows
    }

    private func loadPreferredLeaguePlayerName() -> String? {
        guard let state = PracticeStore.loadPersistedStateFromDefaults() else {
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

private struct LeagueLibraryGame: Decodable {
    enum CodingKeys: String, CodingKey {
        case name
        case game
        case area
        case location
        case group
        case position
        case bank
    }

    let name: String
    let area: String?
    let group: Int?
    let position: Int?
    let bank: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedName = try container.decodeIfPresent(String.self, forKey: .name) {
            name = decodedName
        } else {
            name = try container.decode(String.self, forKey: .game)
        }
        area = (
            try container.decodeIfPresent(String.self, forKey: .area) ??
                container.decodeIfPresent(String.self, forKey: .location)
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
        group = try container.decodeIfPresent(Int.self, forKey: .group)
        position = try container.decodeIfPresent(Int.self, forKey: .position)
        bank = try container.decodeIfPresent(Int.self, forKey: .bank)
    }

}

private struct LeagueLibraryGameRoot: Decodable {
    let items: [LeagueLibraryGame]
}
