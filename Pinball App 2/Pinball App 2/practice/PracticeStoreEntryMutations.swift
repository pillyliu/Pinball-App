import Foundation

extension PracticeStore {
    func studyProgress(gameID: String, task: StudyTaskKind) -> Int {
        let gameID = canonicalPracticeGameID(gameID)
        return state.studyEvents
            .filter { $0.gameID == gameID && $0.task == task }
            .sorted { $0.timestamp < $1.timestamp }
            .last?
            .progressPercent ?? 0
    }

    func studyHistory(gameID: String, task: StudyTaskKind) -> [StudyProgressEvent] {
        let gameID = canonicalPracticeGameID(gameID)
        return state.studyEvents
            .filter { $0.gameID == gameID && $0.task == task }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func updateStudyProgress(gameID: String, task: StudyTaskKind, progressPercent: Int) {
        addGameTaskEntry(
            gameID: canonicalPracticeGameID(gameID),
            task: task,
            progressPercent: progressPercent,
            note: "Updated \(task.label.lowercased())"
        )
    }

    func addGameTaskEntry(gameID: String, task: StudyTaskKind, progressPercent: Int?, note: String?) {
        let gameID = canonicalPracticeGameID(gameID)
        if let progressPercent {
            let event = StudyProgressEvent(gameID: gameID, task: task, progressPercent: progressPercent)
            state.studyEvents.append(event)
        }

        state.journalEntries.append(
            JournalEntry(
                gameID: gameID,
                action: actionType(for: task),
                task: task,
                progressPercent: progressPercent,
                note: note
            )
        )

        saveState()
    }

    func addManualVideoProgress(
        gameID: String,
        action: JournalActionType,
        kind: VideoProgressInputKind,
        value: String,
        progressPercent: Int? = nil,
        note: String? = nil
    ) {
        let gameID = canonicalPracticeGameID(gameID)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = VideoProgressEntry(gameID: gameID, kind: kind, value: trimmedValue)
        let normalizedProgress = progressPercent.map { min(max($0, 0), 100) }
        let task: StudyTaskKind = action == .gameplayWatch ? .gameplayVideo : .tutorialVideo

        state.videoProgressEntries.append(entry)
        if let normalizedProgress {
            state.studyEvents.append(
                StudyProgressEvent(
                    gameID: gameID,
                    task: task,
                    progressPercent: normalizedProgress
                )
            )
        }
        state.journalEntries.append(
            JournalEntry(
                gameID: gameID,
                action: action,
                task: task,
                progressPercent: normalizedProgress,
                videoKind: kind,
                videoValue: trimmedValue,
                note: (trimmedNote?.isEmpty == true) ? nil : trimmedNote
            )
        )
        saveState()
    }

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

    func updatePracticeSettings(playerName: String, comparisonPlayerName: String? = nil) {
        state.practiceSettings.playerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let comparisonPlayerName {
            state.practiceSettings.comparisonPlayerName = comparisonPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        saveState()
    }

    @discardableResult
    func purgeImportedLeagueScores() -> Int {
        let before = state.scoreEntries.count
        state.scoreEntries.removeAll(where: { $0.leagueImported })
        state.journalEntries.removeAll(where: { entry in
            if entry.action != .scoreLogged { return false }
            if entry.scoreContext == .league { return true }
            return (entry.note ?? "").localizedCaseInsensitiveContains("Imported from LPL stats CSV")
        })
        state.leagueSettings.lastImportAt = nil
        saveState()
        return before - state.scoreEntries.count
    }

    func updateSyncSettings(cloudSyncEnabled: Bool) {
        state.syncSettings.cloudSyncEnabled = cloudSyncEnabled
        state.syncSettings.phaseLabel = cloudSyncEnabled ? "Phase 2: Optional cloud sync" : "Phase 1: On-device"
        saveState()
    }

    func updateAnalyticsSettings(gapMode: ChartGapMode, useMedian: Bool) {
        state.analyticsSettings.gapMode = gapMode
        state.analyticsSettings.useMedian = useMedian
        saveState()
    }

    func resetPracticeState() {
        state = .empty
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        saveState()
    }

    func canEditJournalEntry(_ entry: JournalEntry) -> Bool {
        switch entry.action {
        case .rulesheetRead, .tutorialWatch, .gameplayWatch, .playfieldViewed, .practiceSession, .scoreLogged, .noteAdded:
            return true
        case .gameBrowse:
            return false
        }
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

    private func matchingScoreEntryIndex(for journal: JournalEntry) -> Int? {
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
        if let exactish = candidates.min(by: { abs($0.element.timestamp.timeIntervalSince(journal.timestamp)) < abs($1.element.timestamp.timeIntervalSince(journal.timestamp)) }) {
            return exactish.offset
        }
        return nil
    }

    private func matchingStudyEventIndex(for journal: JournalEntry, task: StudyTaskKind) -> Int? {
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

    private func matchingVideoProgressEntryIndex(for journal: JournalEntry) -> Int? {
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

    private func taskForJournalAction(_ action: JournalActionType) -> StudyTaskKind? {
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

    private func reconcileStudyEvent(originalJournal: JournalEntry, updatedJournal: JournalEntry, task: StudyTaskKind) {
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

    private func matchingNoteEntryIndex(for journal: JournalEntry) -> Int? {
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
        if let nearest = candidates.min(by: { abs($0.element.timestamp.timeIntervalSince(journal.timestamp)) < abs($1.element.timestamp.timeIntervalSince(journal.timestamp)) }) {
            return nearest.offset
        }
        return nil
    }
}
