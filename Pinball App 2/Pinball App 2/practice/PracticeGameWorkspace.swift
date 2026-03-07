import SwiftUI

struct PracticeGameWorkspace: View {
    @ObservedObject var store: PracticeStore
    @Binding var selectedGameID: String
    var onGameViewed: ((String) -> Void)? = nil

    var workspaceContext: PracticeGameWorkspaceContext {
        PracticeGameWorkspaceContext(
            store: store,
            selectedGameID: $selectedGameID,
            onGameViewed: onGameViewed
        )
    }

    var body: some View {
        PracticeGameSection(context: workspaceContext)
    }
}
