import Foundation

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

func resolveLeaguePlayerForStats(preferredPlayer: String?, rows: [LeagueParsedStatsRow]) -> String {
    if let preferredPlayer, !preferredPlayer.isEmpty {
        if rows.contains(where: { leaguePlayerNamesMatch($0.player, preferredPlayer) }) {
            return preferredPlayer
        }
    }

    if let latestRow = rows.max(by: { latestLeagueSortValue($0) < latestLeagueSortValue($1) }) {
        return latestRow.player
    }

    return rows[0].player
}

func latestLeagueSortValue(_ row: LeagueParsedStatsRow) -> Double {
    let dateValue = row.eventDate?.timeIntervalSince1970 ?? 0
    return (dateValue * 1_000_000) + Double(row.season * 100 + row.bankNumber)
}

func latestLeagueSortValue(_ rows: [LeagueParsedStatsRow]) -> Double {
    rows.map(latestLeagueSortValue).max() ?? 0
}

func scopedLeagueStatsRows(_ rows: [LeagueParsedStatsRow], preferredPlayer: String?) -> [LeagueParsedStatsRow] {
    guard let preferredPlayer, !preferredPlayer.isEmpty else { return rows }
    let selectedRows = rows.filter { leaguePlayerNamesMatch($0.player, preferredPlayer) }
    return selectedRows.isEmpty ? rows : selectedRows
}

func leagueAroundRowsWindow(
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
