import SwiftUI

struct PracticeGameWorkspaceContext {
    let store: PracticeStore
    let selectedGameID: Binding<String>
    let navigationTitle: String
    let onGameViewed: ((String) -> Void)?
    let onOpenRulesheet: (PinballGame, RulesheetRemoteSource?) -> Void
    let onOpenExternalRulesheet: (PinballGame, URL) -> Void
    let onOpenPlayfield: (PinballGame, [URL]) -> Void
    let onPrepareRulesheet: (PinballGame, RulesheetRemoteSource?) -> Bool
    let onPrepareExternalRulesheet: (PinballGame, URL) -> Void
    let onPreparePlayfield: (PinballGame, [URL]) -> Bool
}
