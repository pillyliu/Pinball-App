import Foundation

extension PracticeStore {
    func importLeagueScoresFromCSV() async -> LeagueImportResult {
        let playerName = state.leagueSettings.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !playerName.isEmpty else {
            return LeagueImportResult(
                imported: 0,
                duplicatesSkipped: 0,
                unmatchedRows: 0,
                selectedPlayer: "(none)",
                sourcePath: Self.leagueStatsPath
            )
        }

        do {
            let cached = try await PinballDataCache.shared.loadText(path: Self.leagueStatsPath)
            guard let text = cached.text else {
                throw URLError(.cannotDecodeRawData)
            }

            let rows = parseLeagueRows(text: text)
            let normalizedSelectedPlayer = normalizeHumanName(playerName)
            let matchedRows = rows.filter { normalizeHumanName($0.player) == normalizedSelectedPlayer }

            var imported = 0
            var duplicates = 0
            var unmatched = 0
            var importedEventDates: [Date] = []

            for row in matchedRows {
                guard let gameID = matchGameID(fromMachine: row.machine) else {
                    unmatched += 1
                    continue
                }

                guard let eventDate = row.eventDate else {
                    unmatched += 1
                    continue
                }

                if isDuplicateLeagueScore(gameID: gameID, score: row.rawScore, eventDate: eventDate) {
                    duplicates += 1
                    continue
                }

                let entry = ScoreLogEntry(
                    gameID: gameID,
                    score: row.rawScore,
                    context: .league,
                    tournamentName: nil,
                    timestamp: eventDate,
                    leagueImported: true
                )
                state.scoreEntries.append(entry)
                state.journalEntries.append(
                    JournalEntry(
                        gameID: gameID,
                        action: .scoreLogged,
                        score: row.rawScore,
                        scoreContext: .league,
                        note: "Imported from LPL stats CSV",
                        timestamp: eventDate
                    )
                )
                importedEventDates.append(eventDate)
                imported += 1
            }

            state.leagueSettings.lastImportAt = Date()
            let result = LeagueImportResult(
                imported: imported,
                duplicatesSkipped: duplicates,
                unmatchedRows: unmatched,
                selectedPlayer: playerName,
                sourcePath: Self.leagueStatsPath
            )
            state.journalEntries.append(
                JournalEntry(
                    gameID: games.first?.id ?? "library",
                    action: .scoreLogged,
                    scoreContext: .league,
                    note: result.summaryLine,
                    timestamp: importedEventDates.max() ?? Date()
                )
            )
            saveState()
            return result
        } catch {
            lastErrorMessage = "League CSV import failed: \(error.localizedDescription)"
            return LeagueImportResult(
                imported: 0,
                duplicatesSkipped: 0,
                unmatchedRows: 0,
                selectedPlayer: playerName,
                sourcePath: Self.leagueStatsPath
            )
        }
    }
}
