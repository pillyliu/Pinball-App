import SwiftUI

struct PracticeGameWorkspace: View {
    @ObservedObject var store: PracticeStore
    @Binding var selectedGameID: String
    var onGameViewed: ((String) -> Void)? = nil
    var onOpenRulesheet: (PinballGame, RulesheetRemoteSource?) -> Void
    var onOpenExternalRulesheet: (PinballGame, URL) -> Void
    var onOpenPlayfield: (PinballGame, [URL]) -> Void
    var onPrepareRulesheet: (PinballGame, RulesheetRemoteSource?) -> Bool
    var onPrepareExternalRulesheet: (PinballGame, URL) -> Void
    var onPreparePlayfield: (PinballGame, [URL]) -> Bool

    var workspaceContext: PracticeGameWorkspaceContext {
        PracticeGameWorkspaceContext(
            store: store,
            selectedGameID: $selectedGameID,
            onGameViewed: onGameViewed,
            onOpenRulesheet: onOpenRulesheet,
            onOpenExternalRulesheet: onOpenExternalRulesheet,
            onOpenPlayfield: onOpenPlayfield,
            onPrepareRulesheet: onPrepareRulesheet,
            onPrepareExternalRulesheet: onPrepareExternalRulesheet,
            onPreparePlayfield: onPreparePlayfield
        )
    }

    var body: some View {
        PracticeGameSection(context: workspaceContext)
    }
}
