import Foundation

struct PracticeQuickEntrySaveResult {
    let savedGameID: String?
    let validationMessage: String?
}

func savePracticeQuickEntry(
    store: PracticeStore,
    activity: QuickEntryActivity,
    selectedGameID: String,
    scoreText: String,
    scoreContext: ScoreContext,
    tournamentName: String,
    rulesheetProgress: Double,
    videoKind: VideoProgressInputKind,
    selectedVideoSource: String,
    videoWatchedTime: String,
    videoTotalTime: String,
    videoPercent: Double,
    practiceMinutes: String,
    practiceCategory: PracticeCategory,
    mechanicsSkill: String,
    mechanicsCompetency: Double,
    mechanicsNote: String,
    noteText: String
) -> PracticeQuickEntrySaveResult {
    let normalizedNoteText = noteText.replacingOccurrences(of: "\r\n", with: "\n")
    let trimmedNote = normalizedNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
    let note = trimmedNote.isEmpty ? nil : normalizedNoteText

    switch activity {
    case .score:
        let normalized = scoreText.replacingOccurrences(of: ",", with: "")
        guard let score = Double(normalized), score > 0 else {
            return PracticeQuickEntrySaveResult(savedGameID: nil, validationMessage: "Enter a valid score above 0.")
        }
        store.addScore(gameID: selectedGameID, score: score, context: scoreContext, tournamentName: tournamentName)
        return PracticeQuickEntrySaveResult(savedGameID: selectedGameID, validationMessage: nil)

    case .rulesheet:
        store.addGameTaskEntry(
            gameID: selectedGameID,
            task: .rulesheet,
            progressPercent: Int(rulesheetProgress.rounded()),
            note: note
        )
        return PracticeQuickEntrySaveResult(savedGameID: selectedGameID, validationMessage: nil)

    case .tutorialVideo, .gameplayVideo:
        guard let videoDraft = buildVideoLogDraft(
            inputKind: videoKind,
            sourceLabel: selectedVideoSource,
            watchedTime: videoWatchedTime,
            totalTime: videoTotalTime,
            percentValue: videoPercent
        ) else {
            return PracticeQuickEntrySaveResult(
                savedGameID: nil,
                validationMessage: "Use valid hh:mm:ss watched/total values (or leave both blank for 100%)."
            )
        }

        let action: JournalActionType = activity == .tutorialVideo ? .tutorialWatch : .gameplayWatch
        store.addManualVideoProgress(
            gameID: selectedGameID,
            action: action,
            kind: videoDraft.kind,
            value: videoDraft.value,
            progressPercent: videoDraft.progressPercent,
            note: note
        )
        return PracticeQuickEntrySaveResult(savedGameID: selectedGameID, validationMessage: nil)

    case .playfield:
        store.addGameTaskEntry(
            gameID: selectedGameID,
            task: .playfield,
            progressPercent: nil,
            note: note ?? "Reviewed playfield image"
        )
        return PracticeQuickEntrySaveResult(savedGameID: selectedGameID, validationMessage: nil)

    case .practice:
        let trimmedMinutes = practiceMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMinutes.isEmpty,
           (Int(trimmedMinutes) == nil || Int(trimmedMinutes) ?? 0 <= 0) {
            return PracticeQuickEntrySaveResult(
                savedGameID: nil,
                validationMessage: "Practice minutes must be a whole number greater than 0 when entered."
            )
        }

        let focusLine: String? = practiceCategory == .general ? nil : "Focus: \(practiceQuickEntryCategoryLabel(practiceCategory))"
        let composedNote: String?
        if let minutes = Int(trimmedMinutes), minutes > 0 {
            let prefix = "Practice session: \(minutes) minute\(minutes == 1 ? "" : "s")"
            let tail = [focusLine, note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". ")
            composedNote = tail.isEmpty ? prefix : "\(prefix). \(tail)"
        } else {
            let base = "Practice session"
            let tail = [focusLine, note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". ")
            composedNote = tail.isEmpty ? base : "\(base). \(tail)"
        }

        store.addGameTaskEntry(
            gameID: selectedGameID,
            task: .practice,
            progressPercent: nil,
            note: composedNote
        )
        return PracticeQuickEntrySaveResult(savedGameID: selectedGameID, validationMessage: nil)

    case .mechanics:
        let skill = mechanicsSkill.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMechanicsNote = mechanicsNote.replacingOccurrences(of: "\r\n", with: "\n")
        let rawNote = normalizedMechanicsNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = skill.isEmpty ? "#mechanics" : "#\(skill.replacingOccurrences(of: " ", with: ""))"
        let composed = rawNote.isEmpty
            ? "\(prefix) competency \(Int(mechanicsCompetency))/5."
            : "\(prefix) competency \(Int(mechanicsCompetency))/5. \(rawNote)"
        let targetGameID = store.canonicalPracticeGameID(selectedGameID)
        store.addNote(gameID: targetGameID, category: .general, detail: skill.isEmpty ? nil : skill, note: composed)
        return PracticeQuickEntrySaveResult(savedGameID: targetGameID, validationMessage: nil)
    }
}
