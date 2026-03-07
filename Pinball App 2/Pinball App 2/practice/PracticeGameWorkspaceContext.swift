import SwiftUI

struct PracticeGameWorkspaceContext {
    let store: PracticeStore
    let selectedGameID: Binding<String>
    let onGameViewed: ((String) -> Void)?
}
