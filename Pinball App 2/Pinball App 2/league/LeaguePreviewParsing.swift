import Foundation

struct LeagueStandingsPreviewPayload {
    var seasonLabel: String = "Season"
    var topRows: [LeagueStandingsPreviewRow] = []
    var aroundRows: [LeagueStandingsPreviewRow] = []
    var currentPlayerStanding: LeagueStandingsPreviewRow?
}

struct LeagueStatsPreviewPayload {
    var rows: [LeagueStatsPreviewRow] = []
    var bankLabel: String = "Most Recent Bank"
    var playerRawName: String = ""
}

func buildLeagueStandingsPreview(standingsCSV: String, selectedPlayer: String?) -> LeagueStandingsPreviewPayload {
    let rows = parseLeagueStandingsRows(standingsCSV)
    guard !rows.isEmpty else {
        return LeagueStandingsPreviewPayload()
    }

    let latestSeason = rows.map(\.season).max() ?? 0
    let seasonLabel = latestSeason > 0 ? "Season \(latestSeason)" : "Season"
    let seasonRows = rows.filter { $0.season == latestSeason }
    guard !seasonRows.isEmpty else {
        return LeagueStandingsPreviewPayload(seasonLabel: seasonLabel)
    }

    let sortedRows: [LeagueParsedStandingRow]
    if seasonRows.allSatisfy({ $0.rank != nil }) {
        sortedRows = seasonRows.sorted { ($0.rank ?? Int.max) < ($1.rank ?? Int.max) }
    } else {
        sortedRows = seasonRows.sorted { $0.total > $1.total }
    }

    let previewRows = sortedRows.enumerated().map { index, row in
        LeagueStandingsPreviewRow(
            rank: row.rank ?? (index + 1),
            rawPlayer: row.player,
            points: row.total
        )
    }

    guard let selectedPlayer, !selectedPlayer.isEmpty else {
        return LeagueStandingsPreviewPayload(
            seasonLabel: seasonLabel,
            topRows: Array(previewRows.prefix(5))
        )
    }

    let normalizedSelected = normalizeLeagueHumanName(selectedPlayer)
    guard let selectedIndex = previewRows.firstIndex(where: {
        normalizeLeagueHumanName($0.rawPlayer) == normalizedSelected
    }) else {
        return LeagueStandingsPreviewPayload(
            seasonLabel: seasonLabel,
            topRows: Array(previewRows.prefix(5))
        )
    }

    return LeagueStandingsPreviewPayload(
        seasonLabel: seasonLabel,
        topRows: Array(previewRows.prefix(5)),
        aroundRows: Array(leagueAroundRowsWindow(rows: previewRows, selectedIndex: selectedIndex)),
        currentPlayerStanding: previewRows[selectedIndex]
    )
}

func buildLeagueStatsPreview(statsCSV: String, preferredPlayer: String?) -> LeagueStatsPreviewPayload {
    let rows = parseLeagueStatsRows(statsCSV)
    guard !rows.isEmpty else {
        return LeagueStatsPreviewPayload()
    }

    let selectedPlayer = resolveLeaguePlayerForStats(preferredPlayer: preferredPlayer, rows: rows)
    let normalizedSelected = normalizeLeagueHumanName(selectedPlayer)
    let selectedRows = rows.filter { normalizeLeagueHumanName($0.player) == normalizedSelected }

    guard !selectedRows.isEmpty else {
        return LeagueStatsPreviewPayload()
    }

    let grouped = Dictionary(grouping: selectedRows, by: { "\($0.season)-\($0.bankNumber)" })
    let mostRecentKey = grouped.keys.max { lhs, rhs in
        guard let lhsRows = grouped[lhs], let rhsRows = grouped[rhs] else { return false }
        return latestLeagueSortValue(lhsRows) < latestLeagueSortValue(rhsRows)
    }

    guard let mostRecentKey,
          let mostRecentRows = grouped[mostRecentKey],
          let sample = mostRecentRows.first else {
        return LeagueStatsPreviewPayload()
    }

    let sortedMostRecentRows = mostRecentRows.sorted { $0.sourceOrder < $1.sourceOrder }
    let rowsForPreview: [LeagueParsedStatsRow] = {
        guard sortedMostRecentRows.count > 5 else { return sortedMostRecentRows }
        let nonZeroScoreRows = sortedMostRecentRows.filter { abs($0.rawScore) > 0.000_001 }
        return nonZeroScoreRows.count >= 5 ? nonZeroScoreRows : sortedMostRecentRows
    }()

    return LeagueStatsPreviewPayload(
        rows: rowsForPreview.prefix(5).enumerated().map { localIndex, row in
            LeagueStatsPreviewRow(
                machine: row.machine,
                score: row.rawScore,
                points: row.points,
                order: localIndex
            )
        },
        bankLabel: "Most Recent • S\(sample.season) B\(sample.bankNumber)",
        playerRawName: sample.player
    )
}

func parseLeagueTargetRows(_ text: String) -> [LeagueTargetPreviewRow] {
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

func parseLeagueStandingsRows(_ text: String) -> [LeagueParsedStandingRow] {
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

        return LeagueParsedStandingRow(season: season, player: player, total: total, rank: rank)
    }
}

func parseLeagueStatsRows(_ text: String) -> [LeagueParsedStatsRow] {
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
            eventDate = leagueEventDateFormatter.date(from: row[eventDateIndex].trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            eventDate = nil
        }

        return LeagueParsedStatsRow(
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

func mergeLeagueTargetsWithLibrary(
    targetRows: [LeagueTargetPreviewRow],
    libraryEntries: [LibraryGameLookupEntry]
) -> [LeagueTargetPreviewRow] {
    return targetRows.map { row in
        let bestMatch = LibraryGameLookup.bestMatch(gameName: row.game, entries: libraryEntries)
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

func resolveLeagueNextBank(statsCSV: String?, availableBanks: Set<Int>, preferredPlayer: String?) -> Int? {
    let sortedBanks = availableBanks.sorted()
    guard !sortedBanks.isEmpty else { return nil }
    guard let statsCSV else { return sortedBanks.first }

    let statsRows = parseLeagueStatsRows(statsCSV)
    guard !statsRows.isEmpty else { return sortedBanks.first }

    let scopedRows = scopedLeagueStatsRows(statsRows, preferredPlayer: preferredPlayer)
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

private func resolveLeaguePlayerForStats(preferredPlayer: String?, rows: [LeagueParsedStatsRow]) -> String {
    if let preferredPlayer, !preferredPlayer.isEmpty {
        let normalized = normalizeLeagueHumanName(preferredPlayer)
        if rows.contains(where: { normalizeLeagueHumanName($0.player) == normalized }) {
            return preferredPlayer
        }
    }

    if let latestRow = rows.max(by: { latestLeagueSortValue($0) < latestLeagueSortValue($1) }) {
        return latestRow.player
    }

    return rows[0].player
}

private func latestLeagueSortValue(_ row: LeagueParsedStatsRow) -> Double {
    let dateValue = row.eventDate?.timeIntervalSince1970 ?? 0
    return (dateValue * 1_000_000) + Double(row.season * 100 + row.bankNumber)
}

private func latestLeagueSortValue(_ rows: [LeagueParsedStatsRow]) -> Double {
    rows.map(latestLeagueSortValue).max() ?? 0
}

private func scopedLeagueStatsRows(_ rows: [LeagueParsedStatsRow], preferredPlayer: String?) -> [LeagueParsedStatsRow] {
    guard let preferredPlayer, !preferredPlayer.isEmpty else { return rows }
    let normalizedPreferred = normalizeLeagueHumanName(preferredPlayer)
    let selectedRows = rows.filter { normalizeLeagueHumanName($0.player) == normalizedPreferred }
    return selectedRows.isEmpty ? rows : selectedRows
}

private func normalizeLeagueHumanName(_ raw: String) -> String {
    raw
        .lowercased()
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

private func leagueAroundRowsWindow(
    rows: [LeagueStandingsPreviewRow],
    selectedIndex: Int,
    windowSize: Int = 5
) -> ArraySlice<LeagueStandingsPreviewRow> {
    guard !rows.isEmpty else { return [] }
    let clampedIndex = max(0, min(selectedIndex, rows.count - 1))
    let edge = windowSize / 2
    let start: Int
    if clampedIndex <= edge {
        start = 0
    } else if clampedIndex >= rows.count - edge - 1 {
        start = max(0, rows.count - windowSize)
    } else {
        start = clampedIndex - edge
    }
    let end = min(rows.count, start + windowSize)
    return rows[start..<end]
}

private let leagueEventDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

struct LeagueParsedStandingRow {
    let season: Int
    let player: String
    let total: Double
    let rank: Int?
}

struct LeagueParsedStatsRow {
    let season: Int
    let bankNumber: Int
    let player: String
    let machine: String
    let rawScore: Double
    let points: Double
    let eventDate: Date?
    let sourceOrder: Int
}
