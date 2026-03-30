import Foundation

struct LeagueStatsPreviewPayload {
    var rows: [LeagueStatsPreviewRow] = []
    var bankLabel: String = "Most Recent Bank"
    var playerRawName: String = ""
}

func buildLeagueStatsPreview(statsCSV: String, preferredPlayer: String?) -> LeagueStatsPreviewPayload {
    let rows = parseLeagueStatsRows(statsCSV)
    guard !rows.isEmpty else {
        return LeagueStatsPreviewPayload()
    }

    let selectedPlayer = resolveLeaguePlayerForStats(preferredPlayer: preferredPlayer, rows: rows)
    let selectedRows = rows.filter { leaguePlayerNamesMatch($0.player, selectedPlayer) }

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

private let leagueEventDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()
