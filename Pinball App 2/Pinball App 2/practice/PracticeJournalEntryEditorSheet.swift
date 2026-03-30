import SwiftUI

struct PracticeJournalEntryEditorSheet: View {
    let entry: JournalEntry
    @ObservedObject var store: PracticeStore
    let onSave: (JournalEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var gameID: String = ""
    @State private var scoreText: String = ""
    @State private var scoreContext: ScoreContext = .practice
    @State private var tournamentName: String = ""
    @State private var noteCategory: PracticeCategory = .general
    @State private var noteDetail: String = ""
    @State private var noteText: String = ""
    @State private var studyProgressEnabled = false
    @State private var studyProgressPercent: Double = 0
    @State private var journalNoteText: String = ""
    @State private var videoKind: VideoProgressInputKind = .percent
    @State private var videoValue: String = ""
    @State private var validationMessage: String?

    private var gameOptions: [PinballGame] {
        store.practiceGamesDeduped()
    }

    var body: some View {
        NavigationStack {
            Form {
                PracticeJournalEditorGamePickerSection(
                    gameOptions: gameOptions,
                    gameID: $gameID
                )
                editorContentSections
                PracticeJournalEditorValidationSection(validationMessage: validationMessage)
            }
            .navigationTitle("Edit Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCancelAction {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(title: "Save", isDisabled: !store.canEditJournalEntry(entry)) {
                        save()
                    }
                }
            }
            .onAppear {
                seedDraftState()
            }
        }
    }

    @ViewBuilder
    private var editorContentSections: some View {
        switch entry.action {
        case .scoreLogged:
            PracticeJournalEditorScoreEntrySection(
                scoreText: $scoreText,
                scoreContext: $scoreContext,
                tournamentName: $tournamentName
            )
        case .noteAdded:
            PracticeJournalEditorNoteEntrySection(
                noteCategory: $noteCategory,
                noteDetail: $noteDetail,
                noteText: $noteText
            )
        case .rulesheetRead, .playfieldViewed, .practiceSession:
            PracticeJournalEditorStudyEntrySection(
                studyProgressEnabled: $studyProgressEnabled,
                studyProgressPercent: $studyProgressPercent,
                journalNoteText: $journalNoteText
            )
        case .tutorialWatch, .gameplayWatch:
            PracticeJournalEditorVideoProgressSection(
                videoKind: $videoKind,
                videoValue: $videoValue,
                studyProgressEnabled: $studyProgressEnabled,
                studyProgressPercent: $studyProgressPercent,
                journalNoteText: $journalNoteText
            )
        case .gameBrowse:
            PracticeJournalEditorUnsupportedEntrySection()
        }
    }

    private var roundedStudyProgress: Int {
        Int(studyProgressPercent.rounded())
    }

    private var currentStudyProgressPercent: Int? {
        studyProgressEnabled ? roundedStudyProgress : nil
    }

    private func seedDraftState() {
        gameID = store.canonicalPracticeGameID(entry.gameID)
        scoreText = entry.score.map { store.formatScore($0) } ?? ""
        scoreContext = entry.scoreContext ?? .practice
        tournamentName = entry.tournamentName ?? ""
        noteCategory = entry.noteCategory ?? .general
        noteDetail = entry.noteDetail ?? ""
        noteText = entry.note ?? ""
        studyProgressEnabled = entry.progressPercent != nil
        studyProgressPercent = Double(entry.progressPercent ?? 0)
        journalNoteText = entry.note ?? ""
        videoKind = entry.videoKind ?? .percent
        videoValue = entry.videoValue ?? ""
        if gameID.isEmpty {
            gameID = gameOptions.first?.canonicalPracticeKey ?? ""
        }
    }

    private func normalizedSingleLineText(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedMultilineText(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\r\n", with: "\n")
    }

    private func normalizedOptionalMultilineText(_ raw: String) -> String? {
        let normalized = normalizedMultilineText(raw)
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : normalized
    }

    private func save() {
        validationMessage = nil
        let canonicalGameID = store.canonicalPracticeGameID(gameID)
        guard !canonicalGameID.isEmpty else {
            validationMessage = "Select a game."
            return
        }

        switch entry.action {
        case .scoreLogged:
            persist(updatedScoreEntry(canonicalGameID: canonicalGameID))
        case .noteAdded:
            persist(updatedNoteEntry(canonicalGameID: canonicalGameID))
        case .rulesheetRead, .playfieldViewed, .practiceSession:
            persist(updatedStudyEntry(canonicalGameID: canonicalGameID))
        case .tutorialWatch, .gameplayWatch:
            persist(updatedVideoEntry(canonicalGameID: canonicalGameID))
        case .gameBrowse:
            validationMessage = "Editing is not supported for this entry type."
        }
    }

    private func updatedScoreEntry(canonicalGameID: String) -> JournalEntry? {
        let normalized = normalizedSingleLineText(scoreText.replacingOccurrences(of: ",", with: ""))
        guard let score = Double(normalized), score > 0 else {
            validationMessage = "Enter a valid score above 0."
            return nil
        }
        if scoreContext == .tournament,
           normalizedSingleLineText(tournamentName).isEmpty {
            validationMessage = "Enter a tournament name."
            return nil
        }
        return JournalEntry(
            id: entry.id,
            gameID: canonicalGameID,
            action: entry.action,
            task: entry.task,
            progressPercent: entry.progressPercent,
            videoKind: entry.videoKind,
            videoValue: entry.videoValue,
            score: score,
            scoreContext: scoreContext,
            tournamentName: scoreContext == .tournament ? normalizedSingleLineText(tournamentName) : nil,
            noteCategory: entry.noteCategory,
            noteDetail: entry.noteDetail,
            note: entry.note,
            timestamp: entry.timestamp
        )
    }

    private func updatedNoteEntry(canonicalGameID: String) -> JournalEntry? {
        guard let normalizedNote = normalizedOptionalMultilineText(noteText) else {
            validationMessage = "Note cannot be empty."
            return nil
        }
        let trimmedDetail = normalizedSingleLineText(noteDetail)
        return JournalEntry(
            id: entry.id,
            gameID: canonicalGameID,
            action: entry.action,
            task: entry.task,
            progressPercent: entry.progressPercent,
            videoKind: entry.videoKind,
            videoValue: entry.videoValue,
            score: entry.score,
            scoreContext: entry.scoreContext,
            tournamentName: entry.tournamentName,
            noteCategory: noteCategory,
            noteDetail: trimmedDetail.isEmpty ? nil : trimmedDetail,
            note: normalizedNote,
            timestamp: entry.timestamp
        )
    }

    private func updatedStudyEntry(canonicalGameID: String) -> JournalEntry {
        JournalEntry(
            id: entry.id,
            gameID: canonicalGameID,
            action: entry.action,
            task: entry.task,
            progressPercent: currentStudyProgressPercent,
            videoKind: entry.videoKind,
            videoValue: entry.videoValue,
            score: entry.score,
            scoreContext: entry.scoreContext,
            tournamentName: entry.tournamentName,
            noteCategory: entry.noteCategory,
            noteDetail: entry.noteDetail,
            note: normalizedOptionalMultilineText(journalNoteText),
            timestamp: entry.timestamp
        )
    }

    private func updatedVideoEntry(canonicalGameID: String) -> JournalEntry? {
        let trimmedVideoValue = normalizedSingleLineText(videoValue)
        guard !trimmedVideoValue.isEmpty else {
            validationMessage = "Enter a video progress value."
            return nil
        }
        return JournalEntry(
            id: entry.id,
            gameID: canonicalGameID,
            action: entry.action,
            task: entry.task,
            progressPercent: currentStudyProgressPercent,
            videoKind: videoKind,
            videoValue: trimmedVideoValue,
            score: entry.score,
            scoreContext: entry.scoreContext,
            tournamentName: entry.tournamentName,
            noteCategory: entry.noteCategory,
            noteDetail: entry.noteDetail,
            note: normalizedOptionalMultilineText(journalNoteText),
            timestamp: entry.timestamp
        )
    }

    private func persist(_ updatedEntry: JournalEntry?) {
        guard let updatedEntry else { return }
        onSave(updatedEntry)
        dismiss()
    }
}
