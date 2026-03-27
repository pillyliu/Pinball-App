import SwiftUI

extension PracticeScreen {
    var practiceRootContent: some View {
        practiceHomeContent
    }

    func practiceDialogHost<Content: View>(_ content: Content) -> some View {
        let presentationContext = practicePresentationContext

        return practiceLifecycleHost(
            content
                .navigationDestination(for: PracticeRoute.self) { route in
                    switch route {
                    case let .game(gameID, transitionSourceID, navigationTitle):
                        practiceGameWorkspace(gameID: gameID, navigationTitle: navigationTitle)
                            .appCardZoomTransition(sourceID: transitionSourceID, in: gameTransition, reduceMotion: reduceMotion)
                    case .search, .rulesheet, .playfield, .ifpaProfile, .groupDashboard, .groupEditor, .journal, .insights, .mechanics, .settings:
                        routeView(for: route)
                    }
                }
                .sheet(item: presentationContext.presentedSheet) { sheet in
                    practiceSheetContent(for: sheet, context: presentationContext)
                }
                .overlay {
                    if uiState.isNavigationInteractionShieldActive {
                        Rectangle()
                            .fill(Color.black.opacity(0.001))
                            .ignoresSafeArea()
                    }
                }
        )
    }

    private func practiceGameWorkspace(gameID: String, navigationTitle: String) -> some View {
        PracticeGameWorkspace(store: store, selectedGameID: $uiState.selectedGameID, navigationTitle: navigationTitle, onGameViewed: { viewedGameID in
            markPracticeGameViewed(viewedGameID)
        }, onOpenRulesheet: { game, source in
            openRulesheet(source: source, for: game)
        }, onOpenExternalRulesheet: { game, url in
            openExternalRulesheet(url: url, for: game)
        })
    }
}
