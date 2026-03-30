import Foundation

extension PracticeStore {
    func isDuplicateLeagueScore(gameID: String, score: Double, eventDate: Date) -> Bool {
        let gameID = canonicalPracticeGameID(gameID)
        return state.scoreEntries.contains { existing in
            guard existing.gameID == gameID, existing.context == .league else { return false }
            guard abs(existing.score - score) < 0.5 else { return false }
            return Calendar.current.isDate(existing.timestamp, inSameDayAs: eventDate)
        }
    }

    func repairImportedLeagueScore(gameID: String, score: Double, eventDate: Date) -> Bool {
        let calendar = Calendar.autoupdatingCurrent
        let canonicalGameID = canonicalPracticeGameID(gameID)
        let matchingScores = state.scoreEntries.enumerated().filter { _, existing in
            guard existing.leagueImported, existing.context == .league else { return false }
            guard abs(existing.score - score) < 0.5 else { return false }
            return calendar.isDate(existing.timestamp, inSameDayAs: eventDate)
        }
        guard matchingScores.count == 1 else { return false }

        let (scoreIndex, existingScore) = matchingScores[0]
        var didChange = false
        if existingScore.gameID != canonicalGameID || existingScore.timestamp != eventDate {
            state.scoreEntries[scoreIndex] = ScoreLogEntry(
                id: existingScore.id,
                gameID: canonicalGameID,
                score: existingScore.score,
                context: existingScore.context,
                tournamentName: existingScore.tournamentName,
                timestamp: eventDate,
                leagueImported: existingScore.leagueImported
            )
            didChange = true
        }

        let matchingJournal = state.journalEntries.enumerated().filter { _, existing in
            guard existing.action == .scoreLogged, existing.scoreContext == .league else { return false }
            guard let existingScore = existing.score, abs(existingScore - score) < 0.5 else { return false }
            return calendar.isDate(existing.timestamp, inSameDayAs: eventDate)
        }
        if matchingJournal.count == 1 {
            let (journalIndex, existingJournal) = matchingJournal[0]
            if existingJournal.gameID != canonicalGameID || existingJournal.timestamp != eventDate {
                state.journalEntries[journalIndex] = JournalEntry(
                    id: existingJournal.id,
                    gameID: canonicalGameID,
                    action: existingJournal.action,
                    task: existingJournal.task,
                    progressPercent: existingJournal.progressPercent,
                    videoKind: existingJournal.videoKind,
                    videoValue: existingJournal.videoValue,
                    score: existingJournal.score,
                    scoreContext: existingJournal.scoreContext,
                    tournamentName: existingJournal.tournamentName,
                    noteCategory: existingJournal.noteCategory,
                    noteDetail: existingJournal.noteDetail,
                    note: existingJournal.note,
                    timestamp: eventDate
                )
                didChange = true
            }
        }

        return didChange
    }
}
