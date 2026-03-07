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
    private var onGameViewed: ((String) -> Void)? { context.onGameViewed }
    private var lifecycleContext: PracticeGameLifecycleContext {
        PracticeGameLifecycleContext(
            store: store,
            selectedGameID: context.selectedGameID,
            gameSummaryDraft: $uiState.gameSummaryDraft,
            activeVideoID: $uiState.activeVideoID,
            onGameViewed: onGameViewed,
            currentVideoFallbackID: { playableVideos.first?.id }
        )
    }
    private var presentationContext: PracticeGamePresentationContext {
        PracticeGamePresentationContext(
            store: store,
            selectedGameID: selectedGameID,
            entryTask: $uiState.entryTask,
            showingScoreSheet: $uiState.showingScoreSheet,
            editingLogEntry: $uiState.editingLogEntry,
            pendingDeleteLogEntry: $uiState.pendingDeleteLogEntry,
            saveBanner: uiState.saveBanner,
            onShowSaveBanner: showSaveBanner
        )
    }

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

    var body: some View {
        PracticeGameLifecycleHost(context: lifecycleContext) {
            PracticeGamePresentationHost(context: presentationContext) {
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
            }
        }
        .navigationTitle(selectedGame?.name ?? "Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .appEdgeBackGesture(dismiss: dismiss)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PracticeGameToolbarMenu(store: store, selectedGameID: context.selectedGameID)
            }
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
