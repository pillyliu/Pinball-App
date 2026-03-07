import SwiftUI

extension PracticeScreen {
    var practiceRootContent: some View {
        practiceHomeContent
    }

    func practiceDialogHost<Content: View>(_ content: Content) -> some View {
        let presentationContext = practicePresentationContext

        return practiceLifecycleHost(
            practiceResetAlert(
                content
                    .navigationDestination(for: PracticeRoute.self) { route in
                        switch route {
                        case .game(let gameID):
                            PracticeGameWorkspace(store: store, selectedGameID: $uiState.selectedGameID, onGameViewed: { viewedGameID in
                                markPracticeGameViewed(viewedGameID)
                            })
                            .onAppear { uiState.selectedGameID = gameID }
                            .navigationTransition(.zoom(sourceID: uiState.gameTransitionSourceID ?? gameID, in: gameTransition))
                        case .ifpaProfile, .groupDashboard, .journal, .insights, .mechanics, .settings:
                            routeView(for: route)
                        }
                    }
                    .sheet(item: presentationContext.presentedSheet) { sheet in
                        practiceSheetContent(for: sheet, context: presentationContext)
                    },
                context: presentationContext
            )
        )
    }
}
