import SwiftUI

struct PracticeGameWorkspace: View {
    @ObservedObject var store: PracticeStore
    @Binding var selectedGameID: String
    let navigationTitle: String
    var onGameViewed: ((String) -> Void)? = nil
    var onOpenRulesheet: (PinballGame, RulesheetRemoteSource?) -> Void
    var onOpenExternalRulesheet: (PinballGame, URL) -> Void

    var workspaceContext: PracticeGameWorkspaceContext {
        PracticeGameWorkspaceContext(
            store: store,
            selectedGameID: $selectedGameID,
            navigationTitle: navigationTitle,
            onGameViewed: onGameViewed,
            onOpenRulesheet: onOpenRulesheet,
            onOpenExternalRulesheet: onOpenExternalRulesheet
        )
    }

    var body: some View {
        PracticeGameSection(context: workspaceContext)
    }
}
