import SwiftUI

struct PracticeGameWorkspace: View {
    @ObservedObject var store: PracticeStore
    @Binding var selectedGameID: String
    var onGameViewed: ((String) -> Void)? = nil
    var onOpenRulesheet: (PinballGame, RulesheetRemoteSource?) -> Void
    var onOpenExternalRulesheet: (PinballGame, URL) -> Void
    var onOpenPlayfield: (PinballGame) -> Void

    var workspaceContext: PracticeGameWorkspaceContext {
        PracticeGameWorkspaceContext(
            store: store,
            selectedGameID: $selectedGameID,
            onGameViewed: onGameViewed,
            onOpenRulesheet: onOpenRulesheet,
            onOpenExternalRulesheet: onOpenExternalRulesheet,
            onOpenPlayfield: onOpenPlayfield
        )
    }

    var body: some View {
        PracticeGameSection(context: workspaceContext)
    }
}
