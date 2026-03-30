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
}
