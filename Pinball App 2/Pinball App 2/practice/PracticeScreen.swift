import SwiftUI

struct PracticeScreen: View {
    @StateObject var store = PracticeStore()
    @EnvironmentObject var appNavigation: AppNavigationModel
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Namespace var gameTransition

    @State var uiState = PracticeScreenState()

    @AppStorage("practice-journal-filter") var journalFilterRaw: String = JournalFilter.all.rawValue
    @AppStorage("practice-quick-game-score") var quickScoreGameID: String = ""
    @AppStorage("practice-quick-game-study") var quickStudyGameID: String = ""
    @AppStorage("practice-quick-game-practice") var quickPracticeGameID: String = ""
    @AppStorage("practice-quick-game-mechanics") var quickMechanicsGameID: String = ""
    @AppStorage("practice-last-viewed-game-id") var practiceLastViewedGameID: String = ""
    @AppStorage("practice-last-viewed-game-ts") var practiceLastViewedGameTS: Double = 0
    @AppStorage("library-last-viewed-game-ts") var libraryLastViewedGameTS: Double = 0
    @AppStorage("practice-name-prompted") var practiceNamePrompted = false

    @State var hasRunInitialPracticeLoad = false

    var body: some View {
        NavigationStack(path: $uiState.gameNavigationPath) {
            AppScreen(dismissesKeyboardOnTap: false) {
                practiceDialogHost(practiceRootContent)
            }
        }
    }
}


#Preview {
    PracticeScreen()
}
