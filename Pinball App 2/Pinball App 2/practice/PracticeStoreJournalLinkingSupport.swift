import Foundation

extension PracticeStore {
    func matchingScoreEntryIndex(for journal: JournalEntry) -> Int? {
        let gameID = canonicalPracticeGameID(journal.gameID)
        let expectedScore = journal.score
        let expectedContext = journal.scoreContext
        let expectedTournament = journal.tournamentName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let candidates = state.scoreEntries.enumerated().filter { _, score in
            guard score.gameID == gameID else { return false }
            if let expectedContext, score.context != expectedContext { return false }
            if let expectedScore, abs(score.score - expectedScore) > 0.5 { return false }
            let scoreTournament = score.tournamentName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !expectedTournament.isEmpty || !scoreTournament.isEmpty {
                return scoreTournament.caseInsensitiveCompare(expectedTournament) == .orderedSame
            }
            return true
        }
        return candidates.min(by: {
            abs($0.element.timestamp.timeIntervalSince(journal.timestamp)) < abs($1.element.timestamp.timeIntervalSince(journal.timestamp))
        })?.offset
    }

    func matchingStudyEventIndex(for journal: JournalEntry, task: StudyTaskKind) -> Int? {
        let gameID = canonicalPracticeGameID(journal.gameID)
        let expectedProgress = journal.progressPercent
        let candidates = state.studyEvents.enumerated().filter { _, event in
            guard event.gameID == gameID, event.task == task else { return false }
            if let expectedProgress, event.progressPercent != expectedProgress { return false }
            return true
        }
        return candidates.min(by: {
            abs($0.element.timestamp.timeIntervalSince(journal.timestamp)) < abs($1.element.timestamp.timeIntervalSince(journal.timestamp))
        })?.offset
    }

    func matchingVideoProgressEntryIndex(for journal: JournalEntry) -> Int? {
        let gameID = canonicalPracticeGameID(journal.gameID)
        let expectedKind = journal.videoKind
        let expectedValue = journal.videoValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let candidates = state.videoProgressEntries.enumerated().filter { _, video in
            guard video.gameID == gameID else { return false }
            if let expectedKind, video.kind != expectedKind { return false }
            if !expectedValue.isEmpty && video.value.trimmingCharacters(in: .whitespacesAndNewlines) != expectedValue { return false }
            return true
        }
        return candidates.min(by: {
            abs($0.element.timestamp.timeIntervalSince(journal.timestamp)) < abs($1.element.timestamp.timeIntervalSince(journal.timestamp))
        })?.offset
    }

    func matchingNoteEntryIndex(for journal: JournalEntry) -> Int? {
        let gameID = canonicalPracticeGameID(journal.gameID)
        let expectedCategory = journal.noteCategory
        let expectedDetail = journal.noteDetail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let expectedNote = journal.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let candidates = state.noteEntries.enumerated().filter { _, note in
            guard note.gameID == gameID else { return false }
            if let expectedCategory, note.category != expectedCategory { return false }
            let noteDetail = note.detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !expectedDetail.isEmpty || !noteDetail.isEmpty {
                guard noteDetail.caseInsensitiveCompare(expectedDetail) == .orderedSame else { return false }
            }
            if !expectedNote.isEmpty, note.note.trimmingCharacters(in: .whitespacesAndNewlines) != expectedNote {
                return false
            }
            return true
        }
        return candidates.min(by: {
            abs($0.element.timestamp.timeIntervalSince(journal.timestamp)) < abs($1.element.timestamp.timeIntervalSince(journal.timestamp))
        })?.offset
    }

    func taskForJournalAction(_ action: JournalActionType) -> StudyTaskKind? {
        switch action {
        case .rulesheetRead:
            return .rulesheet
        case .tutorialWatch:
            return .tutorialVideo
        case .gameplayWatch:
            return .gameplayVideo
        case .playfieldViewed:
            return .playfield
        case .practiceSession:
            return .practice
        case .gameBrowse, .scoreLogged, .noteAdded:
            return nil
        }
    }

    func reconcileStudyEvent(originalJournal: JournalEntry, updatedJournal: JournalEntry, task: StudyTaskKind) {
        let updatedGameID = canonicalPracticeGameID(updatedJournal.gameID)
        let existingIndex = matchingStudyEventIndex(for: originalJournal, task: task)
        let updatedProgress = updatedJournal.progressPercent

        if let existingIndex {
            if let updatedProgress {
                let existing = state.studyEvents[existingIndex]
                state.studyEvents[existingIndex] = StudyProgressEvent(
                    id: existing.id,
                    gameID: updatedGameID,
                    task: task,
                    progressPercent: updatedProgress,
                    timestamp: existing.timestamp
                )
            } else {
                state.studyEvents.remove(at: existingIndex)
            }
            return
        }

        guard let updatedProgress else { return }
        state.studyEvents.append(
            StudyProgressEvent(
                gameID: updatedGameID,
                task: task,
                progressPercent: updatedProgress,
                timestamp: originalJournal.timestamp
            )
        )
    }
}
