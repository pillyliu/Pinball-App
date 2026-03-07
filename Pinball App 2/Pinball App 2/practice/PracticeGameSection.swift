import SwiftUI

enum PracticeGameSubview: String, CaseIterable, Identifiable {
    case summary
    case input
    case log

    var id: String { rawValue }

    var label: String {
        switch self {
        case .summary: return "Summary"
        case .input: return "Input"
        case .log: return "Log"
        }
    }
}

private func inferPracticeLibrarySourcesForWorkspace(from games: [PinballGame]) -> [PinballLibrarySource] {
    var seen = Set<String>()
    var out: [PinballLibrarySource] = []
    for game in games {
        if seen.insert(game.sourceId).inserted {
            out.append(PinballLibrarySource(id: game.sourceId, name: game.sourceName, type: game.sourceType))
        }
    }
    return out
}

struct PracticeGameSection: View {
    let context: PracticeGameWorkspaceContext

    @State private var uiState = PracticeGameWorkspaceState()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var store: PracticeStore { context.store }
    private var selectedGameID: String {
        get { context.selectedGameID.wrappedValue }
        nonmutating set { context.selectedGameID.wrappedValue = newValue }
    }
    private var selectedGameIDBinding: Binding<String> { context.selectedGameID }
    private var onGameViewed: ((String) -> Void)? { context.onGameViewed }

    private var selectedGame: PinballGame? {
        store.gameForAnyID(selectedGameID)
    }

    private var playableVideos: [PinballGame.PlayableVideo] {
        guard let game = selectedGame else { return [] }
        return game.videos.compactMap { video in
            guard let rawURL = video.url,
                  let id = PinballGame.youtubeID(from: rawURL) else {
                return nil
            }
            return PinballGame.PlayableVideo(id: id, label: video.label ?? "Video")
        }
    }

    private var availableLibrarySources: [PinballLibrarySource] {
        store.librarySources.isEmpty ? inferPracticeLibrarySourcesForWorkspace(from: store.allLibraryGames.isEmpty ? store.games : store.allLibraryGames) : store.librarySources
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PracticeGameScreenshotSection(game: selectedGame)

                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Mode", selection: $uiState.subview) {
                            ForEach(PracticeGameSubview.allCases) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)

                        Group {
                            switch uiState.subview {
                            case .summary:
                                gameSummaryView
                            case .input:
                                gameInputView
                            case .log:
                                gameLogView
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .appPanelStyle()

                    PracticeGameNoteCard(
                        note: $uiState.gameSummaryDraft,
                        isDisabled: selectedGameID.isEmpty,
                        onSave: {
                            store.updateGameSummaryNote(gameID: selectedGameID, note: uiState.gameSummaryDraft)
                            showSaveBanner("Game note saved")
                        }
                    )

                    PracticeGameResourceCard(
                        game: selectedGame,
                        playableVideos: playableVideos,
                        activeVideoID: $uiState.activeVideoID,
                        onOpenURL: openURL
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
        }
        .navigationTitle(selectedGame?.name ?? "Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .appEdgeBackGesture(dismiss: dismiss)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    let applyLibrarySelection: (String?) -> Void = { sourceID in
                        store.selectPracticeLibrarySource(id: sourceID)
                        let canonical = store.canonicalPracticeGameID(selectedGameID)
                        if !canonical.isEmpty,
                           store.games.contains(where: { $0.canonicalPracticeKey == canonical }) {
                            selectedGameID = canonical
                        } else {
                            selectedGameID = orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true).first?.canonicalPracticeKey ?? ""
                        }
                    }

                    if availableLibrarySources.count > 1 {
                        Button((store.defaultPracticeSourceID == nil ? "✓ " : "") + "All games") {
                            applyLibrarySelection(nil)
                        }
                        ForEach(availableLibrarySources) { source in
                            Button((source.id == store.defaultPracticeSourceID ? "✓ " : "") + source.name) {
                                applyLibrarySelection(source.id)
                            }
                        }
                        Divider()
                    }
                    Picker("Game", selection: selectedGameIDBinding) {
                        if store.games.isEmpty {
                            Text("No game data").tag("")
                        } else {
                            ForEach(orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true)) { game in
                                Text(game.name).tag(game.canonicalPracticeKey)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .overlay(alignment: .top) {
            if let saveBanner = uiState.saveBanner {
                Text(saveBanner)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2), in: Capsule())
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: uiState.saveBanner)
        .onAppear {
            if selectedGameID.isEmpty, let first = orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true).first {
                selectedGameID = first.canonicalPracticeKey
            }
            if !selectedGameID.isEmpty {
                store.markGameBrowsed(gameID: selectedGameID)
                onGameViewed?(selectedGameID)
                uiState.gameSummaryDraft = store.gameSummaryNote(for: selectedGameID)
            }
            if uiState.activeVideoID == nil {
                uiState.activeVideoID = playableVideos.first?.id
            }
        }
        .onChange(of: selectedGameID) { _, newValue in
            store.markGameBrowsed(gameID: newValue)
            if !newValue.isEmpty {
                onGameViewed?(newValue)
            }
            uiState.gameSummaryDraft = store.gameSummaryNote(for: newValue)
            uiState.activeVideoID = playableVideos.first?.id
        }
        .sheet(item: $uiState.entryTask, content: taskEntrySheet)
        .sheet(isPresented: $uiState.showingScoreSheet) {
            GameScoreEntrySheet(
                gameID: selectedGameID,
                store: store,
                onSaved: {
                    showSaveBanner("Score logged")
                }
            )
            .practiceEntrySheetStyle()
        }
        .sheet(item: $uiState.editingLogEntry) { entry in
            PracticeJournalEntryEditorSheet(entry: entry, store: store) { updated in
                if store.updateJournalEntry(updated) {
                    showSaveBanner("Entry updated")
                }
            }
            .practiceEntrySheetStyle()
        }
        .alert("Delete entry?", isPresented: Binding(
            get: { uiState.pendingDeleteLogEntry != nil },
            set: { if !$0 { uiState.pendingDeleteLogEntry = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let entry = uiState.pendingDeleteLogEntry {
                    _ = store.deleteJournalEntry(id: entry.id)
                    showSaveBanner("Entry deleted")
                }
                uiState.pendingDeleteLogEntry = nil
            }
            Button("Cancel", role: .cancel) {
                uiState.pendingDeleteLogEntry = nil
            }
        } message: {
            Text("This will remove the selected journal entry and linked practice data.")
        }
    }

    private var gameLogView: some View {
        PracticeGameLogPanel(
            store: store,
            gameID: selectedGameID,
            revealedLogEntryID: $uiState.revealedLogEntryID,
            onEditEntry: { entry in
                uiState.editingLogEntry = entry
            },
            onDeleteEntry: { entry in
                uiState.pendingDeleteLogEntry = entry
            }
        )
    }

    private var gameInputView: some View {
        PracticeGameInputPanel(
            onSelectTask: { task in
                uiState.entryTask = task
            },
            onShowScore: {
                uiState.showingScoreSheet = true
            }
        )
    }

    private var gameSummaryView: some View {
        PracticeGameSummaryPanel(store: store, gameID: selectedGameID)
    }

    @ViewBuilder
    private func taskEntrySheet(for task: StudyTaskKind) -> some View {
        GameTaskEntrySheet(
            task: task,
            gameID: selectedGameID,
            store: store,
            onSaved: { message in showSaveBanner(message) }
        )
        .practiceEntrySheetStyle()
    }

    private func showSaveBanner(_ message: String) {
        uiState.saveBanner = message
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if uiState.saveBanner == message {
                uiState.saveBanner = nil
            }
        }
    }
}

struct GameScoreEntrySheet: View {
    let gameID: String
    @ObservedObject var store: PracticeStore
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var scoreText: String = ""
    @State private var scoreContext: ScoreContext = .practice
    @State private var tournamentName: String = ""
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                PracticeEntryGlassCard(maxHeight: 420) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Score", text: $scoreText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appControlStyle()
                            .onChange(of: scoreText) { _, newValue in
                                let formatted = formatScoreInputWithCommas(newValue)
                                if formatted != newValue { scoreText = formatted }
                            }

                        Picker("Context", selection: $scoreContext) {
                            ForEach(ScoreContext.allCases) { context in
                                Text(context.label).tag(context)
                            }
                        }
                        .pickerStyle(.segmented)

                        if scoreContext == .tournament {
                            TextField("Tournament name", text: $tournamentName)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .appControlStyle()
                        }

                        if let validationMessage {
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Spacer()
                    }
                    .padding(14)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .navigationTitle("Log Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if save() {
                            onSaved()
                            dismiss()
                        }
                    }
                    .disabled(gameID.isEmpty)
                }
            }
        }
    }

    private func save() -> Bool {
        validationMessage = nil
        let normalized = scoreText.replacingOccurrences(of: ",", with: "")
        guard let score = Double(normalized), score > 0 else {
            validationMessage = "Enter a valid score above 0."
            return false
        }
        store.addScore(gameID: gameID, score: score, context: scoreContext, tournamentName: tournamentName)
        return true
    }
}

private func formatScoreInputWithCommas(_ raw: String) -> String {
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

struct GameNoteEntrySheet: View {
    let gameID: String
    @ObservedObject var store: PracticeStore
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var category: PracticeCategory = .general
    @State private var detail: String = ""
    @State private var note: String = ""
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                PracticeEntryGlassCard(maxHeight: 460) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Category", selection: $category) {
                            ForEach(noteCategories) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("Optional detail (mode/shot/skill)", text: $detail)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appControlStyle()

                        TextField("Note", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appControlStyle()

                        let detectedTags = store.detectedMechanicsTags(in: "\(detail) \(note)")
                        if !detectedTags.isEmpty {
                            Text("Detected mechanics: \(detectedTags.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let validationMessage {
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Spacer()
                    }
                    .padding(14)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if save() {
                            onSaved()
                            dismiss()
                        }
                    }
                    .disabled(gameID.isEmpty)
                }
            }
        }
    }

    private var noteCategories: [PracticeCategory] {
        [.general, .shots, .modes, .multiball, .strategy]
    }

    private func save() -> Bool {
        validationMessage = nil
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationMessage = "Note cannot be empty."
            return false
        }
        store.addNote(gameID: gameID, category: category, detail: detail, note: trimmed)
        return true
    }
}

struct GameTaskEntrySheet: View {
    let task: StudyTaskKind
    let gameID: String
    @ObservedObject var store: PracticeStore
    let onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var rulesheetProgress: Double = 0
    @State private var videoKind: VideoProgressInputKind = .clock
    @State private var selectedVideoSource: String = ""
    @State private var videoWatchedTime: String = ""
    @State private var videoTotalTime: String = ""
    @State private var videoPercent: Double = 100
    @State private var practiceMinutes: String = ""
    @State private var practiceCategory: PracticeCategory = .general
    @State private var noteText: String = ""
    @State private var validationMessage: String?

    private var selectedGame: PinballGame? {
        store.games.first(where: { $0.id == gameID })
    }

    private var videoSourceOptions: [String] {
        guard task == .tutorialVideo || task == .gameplayVideo else { return [] }
        return practiceVideoSourceOptions(store: store, gameID: gameID, task: task)
    }

    private var quickPracticeCategories: [PracticeCategory] {
        [.general, .modes, .multiball, .shots]
    }

    private var selectedVideoSourceLabel: String {
        let trimmed = selectedVideoSource.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Video" : trimmed
    }

    private var selectedPracticeCategoryLabel: String {
        switch practiceCategory {
        case .general: return "General"
        case .modes: return "Modes"
        case .multiball: return "Multiball"
        case .shots: return "Shots"
        case .strategy: return "Strategy"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                PracticeEntryGlassCard {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            switch task {
                            case .rulesheet:
                                sliderRow(title: "Rulesheet progress", value: $rulesheetProgress)
                                styledMultilineTextEditor("Optional notes", text: $noteText)
                            case .tutorialVideo, .gameplayVideo:
                                Menu {
                                    ForEach(videoSourceOptions, id: \.self) { source in
                                        Button {
                                            selectedVideoSource = source
                                        } label: {
                                            if selectedVideoSource == source {
                                                Label(source, systemImage: "checkmark")
                                            } else {
                                                Text(source)
                                            }
                                        }
                                    }
                                } label: {
                                    compactDropdownLabel(text: selectedVideoSourceLabel)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel("Video")

                                Picker("Input mode", selection: $videoKind) {
                                    ForEach(VideoProgressInputKind.allCases) { kind in
                                        Text(kind.label).tag(kind)
                                    }
                                }
                                .pickerStyle(.segmented)

                                if videoKind == .clock {
                                    HStack(alignment: .top, spacing: 10) {
                                        PracticeTimePopoverField(title: "Watched", value: $videoWatchedTime)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        PracticeTimePopoverField(title: "Duration", value: $videoTotalTime)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                } else {
                                    sliderRow(title: "Percent watched", value: $videoPercent)
                                }

                                styledMultilineTextEditor("Optional notes", text: $noteText)
                            case .playfield:
                                styledMultilineTextEditor("Optional notes", text: $noteText)
                            case .practice:
                                Menu {
                                    ForEach(quickPracticeCategories) { category in
                                        Button {
                                            practiceCategory = category
                                        } label: {
                                            if practiceCategory == category {
                                                Label(
                                                    category == .general ? "General" : category.label,
                                                    systemImage: "checkmark"
                                                )
                                            } else {
                                                Text(category == .general ? "General" : category.label)
                                            }
                                        }
                                    }
                                } label: {
                                    compactDropdownLabel(text: selectedPracticeCategoryLabel)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel("Practice type")

                                styledTextField("Practice minutes (optional)", text: $practiceMinutes, keyboard: .numberPad)
                                styledMultilineTextEditor("Optional notes", text: $noteText)
                            }

                            if let validationMessage {
                                Text(validationMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .navigationTitle("Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if save() {
                            onSaved("\(task.label) saved")
                            dismiss()
                        }
                    }
                    .disabled(gameID.isEmpty)
                }
            }
        }
        .onAppear {
            if selectedVideoSource.isEmpty || !videoSourceOptions.contains(selectedVideoSource) {
                selectedVideoSource = videoSourceOptions.first ?? ""
            }
        }
        .onChange(of: task) { _, _ in
            if selectedVideoSource.isEmpty || !videoSourceOptions.contains(selectedVideoSource) {
                selectedVideoSource = videoSourceOptions.first ?? ""
            }
        }
        .onChange(of: gameID) { _, _ in
            if selectedVideoSource.isEmpty || !videoSourceOptions.contains(selectedVideoSource) {
                selectedVideoSource = videoSourceOptions.first ?? ""
            }
        }
    }

    @ViewBuilder
    private func styledTextField(
        _ placeholder: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        keyboard: UIKeyboardType = .default,
        textAlignment: TextAlignment = .leading,
        monospacedDigits: Bool = false
    ) -> some View {
        let field = TextField(placeholder, text: text, axis: axis)
            .font(.subheadline)
            .keyboardType(keyboard)
            .lineLimit(axis == .vertical ? 2 ... 4 : 1 ... 1)
            .multilineTextAlignment(textAlignment)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()
        if monospacedDigits { field.monospacedDigit() } else { field }
    }

    @ViewBuilder
    private func styledMultilineTextEditor(_ placeholder: String, text: Binding<String>) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
            TextEditor(text: text)
                .font(.subheadline)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .frame(minHeight: 88, maxHeight: 96)
        .appControlStyle()
    }

    private func compactDropdownLabel(text: String) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appControlStyle()
    }

    private func sliderRow(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            Slider(value: value, in: 0...100, step: 1)
                .tint(.white.opacity(0.92))
                .padding(.horizontal, 2)
        }
    }

    @discardableResult
    private func save() -> Bool {
        validationMessage = nil
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = trimmedNote.isEmpty ? nil : trimmedNote

        switch task {
        case .rulesheet:
            store.addGameTaskEntry(
                gameID: gameID,
                task: .rulesheet,
                progressPercent: Int(rulesheetProgress.rounded()),
                note: note
            )
            return true

        case .tutorialVideo, .gameplayVideo:
            guard let videoDraft = buildVideoLogDraft(
                inputKind: videoKind,
                sourceLabel: selectedVideoSource,
                watchedTime: videoWatchedTime,
                totalTime: videoTotalTime,
                percentValue: videoPercent
            ) else {
                validationMessage = "Use valid hh:mm:ss watched/total values (or leave both blank for 100%)."
                return false
            }

            let action: JournalActionType = task == .tutorialVideo ? .tutorialWatch : .gameplayWatch
            store.addManualVideoProgress(
                gameID: gameID,
                action: action,
                kind: videoDraft.kind,
                value: videoDraft.value,
                progressPercent: videoDraft.progressPercent,
                note: note
            )
            return true

        case .playfield:
            store.addGameTaskEntry(
                gameID: gameID,
                task: .playfield,
                progressPercent: nil,
                note: note ?? "Reviewed playfield image"
            )
            return true

        case .practice:
            let trimmedMinutes = practiceMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedMinutes.isEmpty,
               (Int(trimmedMinutes) == nil || Int(trimmedMinutes) ?? 0 <= 0) {
                validationMessage = "Practice minutes must be a whole number greater than 0 when entered."
                return false
            }

            let practiceTypeLabel: String = switch practiceCategory {
            case .general: "General"
            case .modes: "Modes"
            case .multiball: "Multiball"
            case .shots: "Shots"
            case .strategy: "Strategy"
            }
            let focusLine: String? = practiceCategory == .general ? nil : "Focus: \(practiceTypeLabel)"

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
                gameID: gameID,
                task: .practice,
                progressPercent: nil,
                note: composedNote
            )
            return true
        }
    }
}
