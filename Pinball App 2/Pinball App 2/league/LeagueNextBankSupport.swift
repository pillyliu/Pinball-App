import Foundation

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
