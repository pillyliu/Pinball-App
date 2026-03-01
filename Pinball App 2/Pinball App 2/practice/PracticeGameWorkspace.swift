import SwiftUI

struct PracticeGameWorkspace: View {
    @ObservedObject var store: PracticeStore
    @Binding var selectedGameID: String
    var onGameViewed: ((String) -> Void)? = nil

    var body: some View {
        PracticeGameSection(
            store: store,
            selectedGameID: $selectedGameID,
            onGameViewed: onGameViewed
        )
    }
}
