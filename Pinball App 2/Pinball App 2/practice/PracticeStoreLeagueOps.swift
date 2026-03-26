import Foundation

extension PracticeStore {
    func importLeagueScoresFromCSV(
        forceRefresh: Bool = false,
        recordImportSummaryInJournal: Bool = true
    ) async -> LeagueImportResult {
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
            let rows = try await loadLeagueStatsSnapshot(forceRefresh: forceRefresh).rows
            let machineMappings = try await loadLeagueMachineMappings(forceRefresh: forceRefresh)
            let normalizedSelectedPlayer = normalizeHumanName(playerName)
            let matchedRows = rows.filter { normalizeHumanName($0.player) == normalizedSelectedPlayer }

            var imported = 0
            var repaired = 0
            var duplicates = 0
            var unmatched = 0
            var importedEventDates: [Date] = []

            for row in matchedRows {
                guard let gameID = resolveLeagueGameID(for: row, machineMappings: machineMappings) else {
                    unmatched += 1
                    continue
                }

                guard let baseEventDate = row.eventDate else {
                    unmatched += 1
                    continue
                }
                let eventDate = leagueEventTimestamp(for: baseEventDate)

                if isDuplicateLeagueScore(gameID: gameID, score: row.rawScore, eventDate: eventDate) {
                    duplicates += 1
                    continue
                }

                if repairImportedLeagueScore(gameID: gameID, score: row.rawScore, eventDate: eventDate) {
                    importedEventDates.append(eventDate)
                    repaired += 1
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
            state.leagueSettings.lastRepairVersion = Self.leagueScoreRepairVersion
            let result = LeagueImportResult(
                imported: imported,
                duplicatesSkipped: duplicates,
                unmatchedRows: unmatched,
                selectedPlayer: playerName,
                sourcePath: Self.leagueStatsPath,
                repaired: repaired
            )
            if recordImportSummaryInJournal {
                state.journalEntries.append(
                    JournalEntry(
                        gameID: practiceGamesDeduped().first?.canonicalPracticeKey ?? "library",
                        action: .scoreLogged,
                        scoreContext: .league,
                        note: result.summaryLine,
                        timestamp: importedEventDates.max() ?? Date()
                    )
                )
            }
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

    func autoImportLeagueScoresIfNeeded(forceRefresh: Bool = true) async -> LeagueImportResult? {
        let playerName = state.leagueSettings.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state.leagueSettings.csvAutoFillEnabled, !playerName.isEmpty else {
            return nil
        }

        let now = Date()
        if let lastAttempt = lastLeagueAutoImportAttemptAt,
           now.timeIntervalSince(lastAttempt) < leagueAutoImportCooldown {
            return nil
        }
        guard !isAutoImportingLeagueScores else { return nil }

        isAutoImportingLeagueScores = true
        lastLeagueAutoImportAttemptAt = now
        defer { isAutoImportingLeagueScores = false }

        let hasRemoteUpdate = (try? await PinballDataCache.shared.hasRemoteUpdate(path: Self.leagueStatsPath)) == true
        let snapshot = try? await loadLeagueStatsSnapshot(forceRefresh: forceRefresh && hasRemoteUpdate)
        let csvIsNewerThanLastImport: Bool
        if let lastImportAt = state.leagueSettings.lastImportAt,
           let csvUpdatedAt = snapshot?.updatedAt {
            csvIsNewerThanLastImport = csvUpdatedAt > lastImportAt
        } else {
            csvIsNewerThanLastImport = false
        }
        let needsRepairPass = state.leagueSettings.lastRepairVersion != Self.leagueScoreRepairVersion
        let shouldImport = state.leagueSettings.lastImportAt == nil || hasRemoteUpdate || csvIsNewerThanLastImport || needsRepairPass
        guard shouldImport else { return nil }

        let result = await importLeagueScoresFromCSV(
            forceRefresh: false,
            recordImportSummaryInJournal: false
        )
        return result.hasChanges ? result : nil
    }
}
