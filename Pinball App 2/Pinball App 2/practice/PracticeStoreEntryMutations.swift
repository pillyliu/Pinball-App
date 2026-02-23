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
}
