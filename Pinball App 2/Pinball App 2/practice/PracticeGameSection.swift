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
