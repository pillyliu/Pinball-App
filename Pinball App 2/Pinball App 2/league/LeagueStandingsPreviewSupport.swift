import Foundation

struct LeagueStandingsPreviewPayload {
    var seasonLabel: String = "Season"
    var topRows: [LeagueStandingsPreviewRow] = []
    var aroundRows: [LeagueStandingsPreviewRow] = []
    var currentPlayerStanding: LeagueStandingsPreviewRow?
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

    guard let selectedIndex = previewRows.firstIndex(where: {
        leaguePlayerNamesMatch($0.rawPlayer, selectedPlayer)
    }) else {
        return LeagueStandingsPreviewPayload(
            seasonLabel: seasonLabel,
            topRows: Array(previewRows.prefix(5))
        )
    }

    let currentPlayerStanding = previewRows[selectedIndex]
    let aroundRowsWindowSize = currentPlayerStanding.rank > 5 ? 6 : 5

    return LeagueStandingsPreviewPayload(
        seasonLabel: seasonLabel,
        topRows: Array(previewRows.prefix(5)),
        aroundRows: Array(
            leagueAroundRowsWindow(
                rows: previewRows,
                selectedIndex: selectedIndex,
                windowSize: aroundRowsWindowSize
            )
        ),
        currentPlayerStanding: currentPlayerStanding
    )
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
