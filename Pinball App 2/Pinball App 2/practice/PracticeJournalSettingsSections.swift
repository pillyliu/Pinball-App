import SwiftUI

struct PracticeJournalItem: Identifiable {
    let id: String
    let gameID: String
    let summary: String
    let icon: String
    let timestamp: Date
    let journalEntry: JournalEntry?

    var isEditablePracticeEntry: Bool {
        journalEntry?.action.supportsEditing ?? false
    }
}

struct PracticeJournalDaySection: Identifiable {
    let day: Date
    let items: [PracticeJournalItem]

    var id: Date { day }
}

func groupedPracticeJournalSections(_ items: [PracticeJournalItem], calendar: Calendar = .current) -> [PracticeJournalDaySection] {
    let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.timestamp) }
    return grouped.keys
        .sorted(by: >)
        .map { day in
            PracticeJournalDaySection(day: day, items: grouped[day] ?? [])
        }
}

struct PracticeJournalSectionView: View {
    @Binding var journalFilter: JournalFilter
    let sections: [PracticeJournalDaySection]
    @Binding var isEditingEntries: Bool
    @Binding var selectedItemIDs: Set<String>
    let gameTransition: Namespace.ID
    let onTapItem: (String, String) -> Void
    let onEditJournalEntry: (JournalEntry) -> Void
    let onDeleteJournalEntries: ([JournalEntry]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Filter", selection: $journalFilter) {
                ForEach(JournalFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .appSegmentedControlStyle()

            if isEditingEntries {
                PracticeJournalEditActionBar(
                    canEditSelection: selectedEditableJournalEntries.count == 1,
                    canDeleteSelection: !selectedEditableJournalEntries.isEmpty,
                    onEditSelection: editSelectedJournalEntry,
                    onDeleteSelection: deleteSelectedJournalEntries
                )
            }

            PracticeJournalListPanel(
                sections: sections,
                isEditingEntries: isEditingEntries,
                selectedItemIDs: $selectedItemIDs,
                gameTransition: gameTransition,
                onTapItem: onTapItem,
                onEditJournalEntry: onEditJournalEntry,
                onDeleteJournalEntries: onDeleteJournalEntries
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .appPanelStyle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var selectedJournalEntries: [JournalEntry] {
        allItems
            .filter { selectedItemIDs.contains($0.id) }
            .compactMap(\.journalEntry)
    }

    private var selectedEditableJournalEntries: [JournalEntry] {
        allItems
            .filter { selectedItemIDs.contains($0.id) && $0.isEditablePracticeEntry }
            .compactMap(\.journalEntry)
    }

    private var allItems: [PracticeJournalItem] {
        sections.flatMap(\.items)
    }

    private func editSelectedJournalEntry() {
        guard let entry = selectedJournalEntries.first, selectedJournalEntries.count == 1 else { return }
        onEditJournalEntry(entry)
    }

    private func deleteSelectedJournalEntries() {
        guard !selectedEditableJournalEntries.isEmpty else { return }
        onDeleteJournalEntries(selectedEditableJournalEntries)
    }
}

private struct PracticeJournalEditActionBar: View {
    let canEditSelection: Bool
    let canDeleteSelection: Bool
    let onEditSelection: () -> Void
    let onDeleteSelection: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button("Edit", action: onEditSelection)
                .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                .disabled(!canEditSelection)

            Button("Delete", role: .destructive, action: onDeleteSelection)
                .buttonStyle(AppDestructiveActionButtonStyle(fillsWidth: false))
                .disabled(!canDeleteSelection)
        }
    }
}

private struct PracticeJournalListPanel: View {
    let sections: [PracticeJournalDaySection]
    let isEditingEntries: Bool
    @Binding var selectedItemIDs: Set<String>
    let gameTransition: Namespace.ID
    let onTapItem: (String, String) -> Void
    let onEditJournalEntry: (JournalEntry) -> Void
    let onDeleteJournalEntries: ([JournalEntry]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if sections.isEmpty {
                Text("No matching journal events.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                List {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.items) { entry in
                                PracticeJournalListRow(
                                    entry: entry,
                                    isEditingEntries: isEditingEntries,
                                    selectedItemIDs: $selectedItemIDs,
                                    gameTransition: gameTransition,
                                    onTapItem: onTapItem,
                                    onEditJournalEntry: onEditJournalEntry,
                                    onDeleteJournalEntries: onDeleteJournalEntries
                                )
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        } header: {
                            PracticeJournalDayHeader(day: section.day)
                        }
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(0)
                .contentMargins(.top, 0, for: .scrollContent)
                .contentMargins(.top, 0, for: .scrollIndicators)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 1)
                .environment(\.defaultMinListHeaderHeight, 1)
            }
        }
    }
}

private struct PracticeJournalDayHeader: View {
    let day: Date

    var body: some View {
        HStack {
            Text(day.formatted(date: .abbreviated, time: .omitted))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.cyan.opacity(0.95))
                .textCase(nil)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(AppTheme.panel.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(AppTheme.border.opacity(0.55), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, -16)
        .padding(.top, 1)
        .padding(.bottom, 1)
    }
}

private struct PracticeJournalListRow: View {
    let entry: PracticeJournalItem
    let isEditingEntries: Bool
    @Binding var selectedItemIDs: Set<String>
    let gameTransition: Namespace.ID
    let onTapItem: (String, String) -> Void
    let onEditJournalEntry: (JournalEntry) -> Void
    let onDeleteJournalEntries: ([JournalEntry]) -> Void

    var body: some View {
        let rowContent = rowContentView

        if !isEditingEntries, entry.isEditablePracticeEntry, let journal = entry.journalEntry {
            JournalStaticEditableRow {
                rowContent
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    onDeleteJournalEntries([journal])
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)

                Button {
                    onEditJournalEntry(journal)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(AppTheme.statsMeanMedian)
            }
        } else if entry.isEditablePracticeEntry {
            JournalStaticEditableRow {
                rowContent
            }
        } else {
            rowContent
        }
    }

    private var rowContentView: some View {
        HStack(alignment: .top, spacing: 8) {
            if isEditingEntries {
                selectionIndicator
            }

            Image(systemName: entry.icon)
                .font(.caption)
                .frame(width: 14)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                styledPracticeJournalSummary(entry.summary)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: handleTap)
        .matchedTransitionSource(id: transitionSourceID, in: gameTransition)
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if entry.isEditablePracticeEntry {
            Image(systemName: selectedItemIDs.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selectedItemIDs.contains(entry.id) ? .orange : .secondary)
                .font(.body)
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.clear)
                .font(.body)
        }
    }

    private var transitionSourceID: String {
        "\(entry.gameID)-\(entry.id)"
    }

    private func handleTap() {
        if isEditingEntries {
            guard entry.isEditablePracticeEntry else { return }
            if selectedItemIDs.contains(entry.id) {
                selectedItemIDs.remove(entry.id)
            } else {
                selectedItemIDs.insert(entry.id)
            }
            return
        }
        onTapItem(entry.gameID, transitionSourceID)
    }
}

struct JournalStaticEditableRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.6), lineWidth: 1)
            )
            .padding(.vertical, 1)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct PracticeJournalEntryEditorSheet: View {
    private struct GamePickerSection: View {
        let gameOptions: [PinballGame]
        @Binding var gameID: String

        var body: some View {
            Section("Game") {
                Picker("Title", selection: $gameID) {
                    ForEach(gameOptions) { game in
                        Text(game.name).tag(game.canonicalPracticeKey)
                    }
                }
            }
        }
    }

    private struct ScoreEntrySection: View {
        @Binding var scoreText: String
        @Binding var scoreContext: ScoreContext
        @Binding var tournamentName: String

        var body: some View {
            Section("Score") {
                TextField("Score", text: $scoreText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .onChange(of: scoreText) { _, newValue in
                        let formatted = formatJournalScoreInputWithCommas(newValue)
                        if formatted != newValue {
                            scoreText = formatted
                        }
                    }
                Picker("Context", selection: $scoreContext) {
                    ForEach(ScoreContext.allCases) { context in
                        Text(context.label).tag(context)
                    }
                }
                if scoreContext == .tournament {
                    TextField("Tournament name", text: $tournamentName)
                }
            }
        }
    }

    private struct NoteEntrySection: View {
        @Binding var noteCategory: PracticeCategory
        @Binding var noteDetail: String
        @Binding var noteText: String

        var body: some View {
            Section("Note") {
                Picker("Category", selection: $noteCategory) {
                    ForEach(PracticeCategory.allCases) { category in
                        Text(category.label).tag(category)
                    }
                }
                TextField("Detail (optional)", text: $noteDetail)
                PracticeJournalStyledNoteEditor(text: $noteText)
            }
        }
    }

    private struct StudyEntrySection: View {
        @Binding var studyProgressEnabled: Bool
        @Binding var studyProgressPercent: Double
        @Binding var journalNoteText: String

        var body: some View {
            Section("Entry") {
                PracticeJournalProgressFields(
                    studyProgressEnabled: $studyProgressEnabled,
                    studyProgressPercent: $studyProgressPercent
                )
                PracticeJournalOptionalNoteSection(text: $journalNoteText)
            }
        }
    }

    private struct VideoProgressSection: View {
        @Binding var videoKind: VideoProgressInputKind
        @Binding var videoValue: String
        @Binding var studyProgressEnabled: Bool
        @Binding var studyProgressPercent: Double
        @Binding var journalNoteText: String

        var body: some View {
            Section("Video Progress") {
                Picker("Format", selection: $videoKind) {
                    ForEach(VideoProgressInputKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                TextField(
                    videoKind == .clock ? "Value (e.g. 00:12:34 / 00:45:00)" : "Value (e.g. 60%)",
                    text: $videoValue,
                    axis: .vertical
                )
                .lineLimit(1...3)

                PracticeJournalProgressFields(
                    studyProgressEnabled: $studyProgressEnabled,
                    studyProgressPercent: $studyProgressPercent
                )
                PracticeJournalOptionalNoteSection(text: $journalNoteText)
            }
        }
    }

    private struct UnsupportedEntrySection: View {
        var body: some View {
            Section {
                Text("Editing is only supported for score and note entries right now.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct ValidationSection: View {
        let validationMessage: String?

        var body: some View {
            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                }
            }
        }
    }

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
                GamePickerSection(
                    gameOptions: gameOptions,
                    gameID: $gameID
                )
                editorContentSections
                ValidationSection(validationMessage: validationMessage)
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
            ScoreEntrySection(
                scoreText: $scoreText,
                scoreContext: $scoreContext,
                tournamentName: $tournamentName
            )
        case .noteAdded:
            NoteEntrySection(
                noteCategory: $noteCategory,
                noteDetail: $noteDetail,
                noteText: $noteText
            )
        case .rulesheetRead, .playfieldViewed, .practiceSession:
            StudyEntrySection(
                studyProgressEnabled: $studyProgressEnabled,
                studyProgressPercent: $studyProgressPercent,
                journalNoteText: $journalNoteText
            )
        case .tutorialWatch, .gameplayWatch:
            VideoProgressSection(
                videoKind: $videoKind,
                videoValue: $videoValue,
                studyProgressEnabled: $studyProgressEnabled,
                studyProgressPercent: $studyProgressPercent,
                journalNoteText: $journalNoteText
            )
        case .gameBrowse:
            UnsupportedEntrySection()
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

private struct PracticeJournalProgressFields: View {
    @Binding var studyProgressEnabled: Bool
    @Binding var studyProgressPercent: Double

    var body: some View {
        Group {
            Toggle("Track progress", isOn: $studyProgressEnabled)
            if studyProgressEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progress")
                        Spacer()
                        Text("\(roundedStudyProgress)%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $studyProgressPercent, in: 0...100, step: 1)
                }
            }
        }
    }

    private var roundedStudyProgress: Int {
        Int(studyProgressPercent.rounded())
    }
}

private struct PracticeJournalOptionalNoteSection: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note (optional)")
                .font(.caption)
                .foregroundStyle(.secondary)
            PracticeJournalStyledNoteEditor(text: $text)
        }
    }
}

private struct PracticeJournalStyledNoteEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: 88, maxHeight: 96)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .appControlStyle()
    }
}

private func formatJournalScoreInputWithCommas(_ raw: String) -> String {
    let digits = raw.filter(\.isNumber)
    guard !digits.isEmpty else { return "" }
    var grouped: [String] = []
    var remaining = String(digits)
    while remaining.count > 3 {
        let cut = remaining.index(remaining.endIndex, offsetBy: -3)
        grouped.insert(String(remaining[cut...]), at: 0)
        remaining = String(remaining[..<cut])
    }
    grouped.insert(remaining, at: 0)
    return grouped.joined(separator: ",")
}

struct PracticeSettingsSectionView: View {
    @Binding var playerName: String
    @Binding var ifpaPlayerID: String
    @Binding var leaguePlayerName: String
    let leaguePlayerOptions: [String]
    let leagueImportStatus: String
    let importedLeagueScoreCount: Int
    let onSaveProfile: () -> Void
    let onSaveIFPAID: () -> Void
    let onImportLeagueCSV: () -> Void
    let onLeaguePlayerSelected: (String) -> Void
    let onClearImportedLeagueScores: () -> Void
    let onResetPracticeLog: () -> Void
    @AppStorage(LPLNamePrivacySettings.showFullLastNameDefaultsKey) private var showFullLPLLastNames = false
    @State private var showingResetPracticeLogPrompt = false
    @State private var resetPracticeLogConfirmationText = ""
    @State private var showingClearImportedLeagueScoresPrompt = false

    var body: some View {
        settingsCards
            .frame(maxWidth: .infinity, alignment: .leading)
            .alert("Clear Imported League Scores?", isPresented: $showingClearImportedLeagueScoresPrompt) {
                Button("Cancel", role: .cancel) {}
                Button(clearImportedLeagueScoresButtonTitle(importedLeagueScoreCount), role: .destructive) {
                    onClearImportedLeagueScores()
                }
            } message: {
                Text(clearImportedLeagueScoresAlertMessage(importedLeagueScoreCount))
            }
            .alert("Reset Practice Log?", isPresented: $showingResetPracticeLogPrompt) {
                TextField("Type reset", text: $resetPracticeLogConfirmationText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("No", role: .cancel) {}
                Button("Yes, Reset", role: .destructive) {
                    onResetPracticeLog()
                }
                .disabled(!canConfirmResetPracticeLog)
            } message: {
                Text("This resets the full local Practice JSON log state. Type \"reset\" to enable confirmation.")
            }
    }

    private var settingsCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            PracticeProfileSettingsCard(
                playerName: $playerName,
                onSaveProfile: onSaveProfile
            )
            PracticeIFPASettingsCard(
                ifpaPlayerID: $ifpaPlayerID,
                onSaveIFPAID: onSaveIFPAID
            )
            PracticeLeagueImportSettingsCard(
                leaguePlayerName: leaguePlayerName,
                leaguePlayerOptions: leaguePlayerOptions,
                leagueImportStatus: leagueImportStatus,
                onImportLeagueCSV: onImportLeagueCSV,
                onLeaguePlayerSelected: onLeaguePlayerSelected,
                displayLPLPlayerName: displayLPLPlayerName
            )
            PracticeRecoverySettingsCard(
                importedLeagueScoreCount: importedLeagueScoreCount,
                onClearImportedLeagueScoresRequested: presentClearImportedLeagueScoresPrompt,
                onResetPracticeLogRequested: presentResetPracticeLogPrompt
            )
        }
    }

    private var canConfirmResetPracticeLog: Bool {
        resetPracticeLogConfirmationText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "reset"
    }

    private func presentClearImportedLeagueScoresPrompt() {
        showingClearImportedLeagueScoresPrompt = true
    }

    private func presentResetPracticeLogPrompt() {
        resetPracticeLogConfirmationText = ""
        showingResetPracticeLogPrompt = true
    }

    private func displayLPLPlayerName(_ raw: String) -> String {
        formatLPLPlayerNameForDisplay(raw, showFullLastNames: showFullLPLLastNames)
    }
}

private struct PracticeSettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }
}

private struct PracticeProfileSettingsCard: View {
    @Binding var playerName: String
    let onSaveProfile: () -> Void

    var body: some View {
        PracticeSettingsCard {
            AppSectionTitle(text: "Practice Profile")

            TextField("Player name", text: $playerName)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()

            Button("Save Profile", action: onSaveProfile)
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(AppPrimaryActionButtonStyle())
        }
    }
}

private struct PracticeIFPASettingsCard: View {
    @Binding var ifpaPlayerID: String
    let onSaveIFPAID: () -> Void

    var body: some View {
        PracticeSettingsCard {
            AppSectionTitle(text: "IFPA")

            TextField("IFPA number", text: $ifpaPlayerID)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()

            Text("Save your IFPA player number to unlock a quick stats profile from the Practice home header.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Save IFPA ID", action: onSaveIFPAID)
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(AppPrimaryActionButtonStyle())
        }
    }
}

private struct PracticeLeagueImportSettingsCard: View {
    let leaguePlayerName: String
    let leaguePlayerOptions: [String]
    let leagueImportStatus: String
    let onImportLeagueCSV: () -> Void
    let onLeaguePlayerSelected: (String) -> Void
    let displayLPLPlayerName: (String) -> String

    var body: some View {
        PracticeSettingsCard {
            AppSectionTitle(text: "League Import")

            Menu {
                Button("Select league player") {
                    onLeaguePlayerSelected("")
                }
                if leaguePlayerOptions.isEmpty {
                    AppSelectableMenuRow(text: "No player names found", isSelected: false)
                } else {
                    ForEach(leaguePlayerOptions, id: \.self) { name in
                        Button(displayLPLPlayerName(name)) {
                            onLeaguePlayerSelected(name)
                        }
                    }
                }
            } label: {
                AppCompactDropdownLabel(text: leaguePlayerMenuLabel)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(practiceLeagueImportDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Import LPL CSV", action: onImportLeagueCSV)
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(AppPrimaryActionButtonStyle())
                .disabled(!hasSelectedLeaguePlayer)

            if !leagueImportStatus.isEmpty {
                Text(leagueImportStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var leaguePlayerMenuLabel: String {
        leaguePlayerName.isEmpty ? "Select league player" : displayLPLPlayerName(leaguePlayerName)
    }

    private var hasSelectedLeaguePlayer: Bool {
        !leaguePlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct PracticeRecoverySettingsCard: View {
    let importedLeagueScoreCount: Int
    let onClearImportedLeagueScoresRequested: () -> Void
    let onResetPracticeLogRequested: () -> Void

    var body: some View {
        PracticeSettingsCard {
            AppSectionTitle(text: "Recovery")

            Text(importedLeagueScoreSummary(importedLeagueScoreCount))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(clearImportedLeagueScoresButtonTitle(importedLeagueScoreCount), role: .destructive) {
                onClearImportedLeagueScoresRequested()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(AppDestructiveActionButtonStyle())
            .disabled(importedLeagueScoreCount == 0)

            Text("Erase the full local Practice log state.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Reset Practice Log", role: .destructive) {
                onResetPracticeLogRequested()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(AppDestructiveActionButtonStyle())
        }
    }
}
