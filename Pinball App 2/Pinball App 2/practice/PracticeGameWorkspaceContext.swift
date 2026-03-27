import SwiftUI

struct PracticeGameWorkspaceContext {
    let store: PracticeStore
    let selectedGameID: Binding<String>
    let navigationTitle: String
    let onGameViewed: ((String) -> Void)?
    let onOpenRulesheet: (PinballGame, RulesheetRemoteSource?) -> Void
    let onOpenExternalRulesheet: (PinballGame, URL) -> Void
}
