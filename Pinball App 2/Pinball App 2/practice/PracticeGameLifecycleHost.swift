import SwiftUI

struct PracticeGameLifecycleHost<Content: View>: View {
    let context: PracticeGameLifecycleContext
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .onAppear {
                if context.selectedGameID.wrappedValue.isEmpty,
                   let first = orderedGamesForDropdown(context.store.games, collapseByPracticeIdentity: true).first {
                    context.selectedGameID.wrappedValue = first.canonicalPracticeKey
                }

                syncSelectedGame(context.selectedGameID.wrappedValue)

                if context.activeVideoID.wrappedValue == nil {
                    context.activeVideoID.wrappedValue = context.currentVideoFallbackID()
                }
            }
            .onChange(of: context.selectedGameID.wrappedValue) { _, newValue in
                syncSelectedGame(newValue)
                context.activeVideoID.wrappedValue = context.currentVideoFallbackID()
            }
    }

    private func syncSelectedGame(_ gameID: String) {
        guard !gameID.isEmpty else {
            context.gameSummaryDraft.wrappedValue = ""
            return
        }

        context.store.markGameBrowsed(gameID: gameID)
        context.onGameViewed?(gameID)
        context.gameSummaryDraft.wrappedValue = context.store.gameSummaryNote(for: gameID)
    }
}
