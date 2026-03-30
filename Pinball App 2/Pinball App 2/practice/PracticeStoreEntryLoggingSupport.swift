import Foundation

extension PracticeStore {
    func addScore(gameID: String, score: Double, context: ScoreContext, tournamentName: String?) {
        let gameID = canonicalPracticeGameID(gameID)
        let entry = ScoreLogEntry(
            gameID: gameID,
            score: score,
            context: context,
            tournamentName: context == .tournament ? tournamentName?.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            leagueImported: false
        )

        state.scoreEntries.append(entry)
        state.journalEntries.append(
            JournalEntry(
                gameID: gameID,
                action: .scoreLogged,
                score: score,
                scoreContext: context,
                tournamentName: entry.tournamentName
            )
        )
        saveState()
    }

    func addNote(gameID: String, category: PracticeCategory, detail: String?, note: String) {
        let gameID = canonicalPracticeGameID(gameID)
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let trimmedDetail = detail?.trimmingCharacters(in: .whitespacesAndNewlines)

        let detected = detectedMechanicsTags(in: [trimmedDetail, trimmed].compactMap { $0 }.joined(separator: " "))
        let autoTagStrings = detected.map { "#\($0.replacingOccurrences(of: " ", with: "").lowercased())" }
        var autoTaggedNote = trimmed
        for tag in autoTagStrings where !autoTaggedNote.localizedCaseInsensitiveContains(tag) {
            autoTaggedNote += " \(tag)"
        }

        let entry = PracticeNoteEntry(
            gameID: gameID,
            category: category,
            detail: trimmedDetail,
            note: autoTaggedNote
        )

        state.noteEntries.append(entry)
        state.journalEntries.append(
            JournalEntry(
                gameID: gameID,
                action: .noteAdded,
                noteCategory: category,
                noteDetail: entry.detail,
                note: autoTaggedNote
            )
        )
        saveState()
    }

    func markGameBrowsed(gameID: String) {
        let gameID = canonicalPracticeGameID(gameID)
        guard !gameID.isEmpty else { return }

        if let latest = state.journalEntries
            .filter({ $0.gameID == gameID && $0.action == .gameBrowse })
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first,
           Date().timeIntervalSince(latest.timestamp) < 45 {
            return
        }

        state.journalEntries.append(
            JournalEntry(
                gameID: gameID,
                action: .gameBrowse
            )
        )
        saveState()
    }
}
