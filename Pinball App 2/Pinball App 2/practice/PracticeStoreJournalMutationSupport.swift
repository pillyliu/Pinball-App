import Foundation

extension PracticeStore {
    func canEditJournalEntry(_ entry: JournalEntry) -> Bool {
        entry.action.supportsEditing
    }

    @discardableResult
    func updateJournalEntry(_ updatedEntry: JournalEntry) -> Bool {
        guard let journalIndex = state.journalEntries.firstIndex(where: { $0.id == updatedEntry.id }) else { return false }
        let original = state.journalEntries[journalIndex]
        let canonicalGameID = canonicalPracticeGameID(updatedEntry.gameID)

        let sanitized = JournalEntry(
            id: original.id,
            gameID: canonicalGameID,
            action: original.action,
            task: updatedEntry.task ?? original.task,
            progressPercent: updatedEntry.progressPercent ?? original.progressPercent,
            videoKind: updatedEntry.videoKind ?? original.videoKind,
            videoValue: updatedEntry.videoValue ?? original.videoValue,
            score: updatedEntry.score ?? original.score,
            scoreContext: updatedEntry.scoreContext ?? original.scoreContext,
            tournamentName: updatedEntry.scoreContext == .tournament ? updatedEntry.tournamentName : nil,
            noteCategory: updatedEntry.noteCategory ?? original.noteCategory,
            noteDetail: updatedEntry.noteDetail ?? original.noteDetail,
            note: updatedEntry.note ?? original.note,
            timestamp: original.timestamp
        )

        switch original.action {
        case .rulesheetRead, .playfieldViewed, .practiceSession:
            if let task = original.task ?? taskForJournalAction(original.action) {
                reconcileStudyEvent(
                    originalJournal: original,
                    updatedJournal: sanitized,
                    task: task
                )
            }
            state.journalEntries[journalIndex] = sanitized

        case .tutorialWatch, .gameplayWatch:
            let task = original.task ?? taskForJournalAction(original.action)
            if let videoIndex = matchingVideoProgressEntryIndex(for: original) {
                let existing = state.videoProgressEntries[videoIndex]
                if let kind = sanitized.videoKind,
                   let value = sanitized.videoValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !value.isEmpty {
                    state.videoProgressEntries[videoIndex] = VideoProgressEntry(
                        id: existing.id,
                        gameID: canonicalGameID,
                        kind: kind,
                        value: value,
                        timestamp: existing.timestamp
                    )
                } else {
                    state.videoProgressEntries.remove(at: videoIndex)
                }
            }
            if let task {
                reconcileStudyEvent(
                    originalJournal: original,
                    updatedJournal: sanitized,
                    task: task
                )
            }
            state.journalEntries[journalIndex] = sanitized

        case .scoreLogged:
            guard let score = sanitized.score,
                  let context = sanitized.scoreContext else { return false }
            if let scoreIndex = matchingScoreEntryIndex(for: original) {
                let existing = state.scoreEntries[scoreIndex]
                state.scoreEntries[scoreIndex] = ScoreLogEntry(
                    id: existing.id,
                    gameID: canonicalGameID,
                    score: score,
                    context: context,
                    tournamentName: context == .tournament ? sanitized.tournamentName?.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    timestamp: existing.timestamp,
                    leagueImported: existing.leagueImported
                )
            }
            state.journalEntries[journalIndex] = sanitized

        case .noteAdded:
            guard let category = sanitized.noteCategory,
                  let note = sanitized.note?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !note.isEmpty else { return false }
            if let noteIndex = matchingNoteEntryIndex(for: original) {
                let existing = state.noteEntries[noteIndex]
                state.noteEntries[noteIndex] = PracticeNoteEntry(
                    id: existing.id,
                    gameID: canonicalGameID,
                    category: category,
                    detail: sanitized.noteDetail?.trimmingCharacters(in: .whitespacesAndNewlines),
                    note: note,
                    timestamp: existing.timestamp
                )
            }
            state.journalEntries[journalIndex] = JournalEntry(
                id: sanitized.id,
                gameID: sanitized.gameID,
                action: sanitized.action,
                task: sanitized.task,
                progressPercent: sanitized.progressPercent,
                videoKind: sanitized.videoKind,
                videoValue: sanitized.videoValue,
                score: sanitized.score,
                scoreContext: sanitized.scoreContext,
                tournamentName: sanitized.tournamentName,
                noteCategory: category,
                noteDetail: sanitized.noteDetail?.trimmingCharacters(in: .whitespacesAndNewlines),
                note: note,
                timestamp: sanitized.timestamp
            )

        case .gameBrowse:
            return false
        }

        saveState()
        return true
    }

    @discardableResult
    func deleteJournalEntry(id: UUID) -> Bool {
        guard let journalIndex = state.journalEntries.firstIndex(where: { $0.id == id }) else { return false }
        let entry = state.journalEntries[journalIndex]

        switch entry.action {
        case .rulesheetRead, .playfieldViewed, .practiceSession:
            if let task = entry.task ?? taskForJournalAction(entry.action),
               let studyIndex = matchingStudyEventIndex(for: entry, task: task) {
                state.studyEvents.remove(at: studyIndex)
            }
        case .tutorialWatch, .gameplayWatch:
            if let videoIndex = matchingVideoProgressEntryIndex(for: entry) {
                state.videoProgressEntries.remove(at: videoIndex)
            }
            if let task = entry.task ?? taskForJournalAction(entry.action),
               let studyIndex = matchingStudyEventIndex(for: entry, task: task) {
                state.studyEvents.remove(at: studyIndex)
            }
        case .scoreLogged:
            if let scoreIndex = matchingScoreEntryIndex(for: entry) {
                state.scoreEntries.remove(at: scoreIndex)
            }
        case .noteAdded:
            if let noteIndex = matchingNoteEntryIndex(for: entry) {
                state.noteEntries.remove(at: noteIndex)
            }
        case .gameBrowse:
            return false
        }

        state.journalEntries.remove(at: journalIndex)
        saveState()
        return true
    }
}
