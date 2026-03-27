import SwiftUI

struct PracticeGameLifecycleHost<Content: View>: View {
    let context: PracticeGameLifecycleContext
    @ViewBuilder let content: () -> Content
    @State private var browseLogTask: Task<Void, Never>?

    var body: some View {
        content()
            .onAppear {
                let bootstrappedSelection: Bool
                if context.selectedGameID.wrappedValue.isEmpty,
                   let first = orderedGamesForDropdown(context.store.games, collapseByPracticeIdentity: true).first {
                    context.selectedGameID.wrappedValue = first.canonicalPracticeKey
                    bootstrappedSelection = true
                } else {
                    bootstrappedSelection = false
                }

                if !bootstrappedSelection {
                    syncSelectedGame(context.selectedGameID.wrappedValue)
                    scheduleBrowseLog(for: context.selectedGameID.wrappedValue)

                    if context.activeVideoID.wrappedValue == nil {
                        context.activeVideoID.wrappedValue = context.currentVideoFallbackID()
                    }
                }
            }
            .onChange(of: context.selectedGameID.wrappedValue) { _, newValue in
                syncSelectedGame(newValue)
                scheduleBrowseLog(for: newValue)
                context.activeVideoID.wrappedValue = context.currentVideoFallbackID()
            }
            .onDisappear {
                browseLogTask?.cancel()
                browseLogTask = nil
            }
    }

    private func syncSelectedGame(_ gameID: String) {
        guard !gameID.isEmpty else {
            context.gameSummaryDraft.wrappedValue = ""
            return
        }

        context.onGameViewed?(gameID)
        context.gameSummaryDraft.wrappedValue = context.store.gameSummaryNote(for: gameID)
    }

    private func scheduleBrowseLog(for gameID: String) {
        browseLogTask?.cancel()
        browseLogTask = nil

        let canonicalGameID = gameID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !canonicalGameID.isEmpty else { return }

        browseLogTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            context.store.markGameBrowsed(gameID: canonicalGameID)
            browseLogTask = nil
        }
    }
}
