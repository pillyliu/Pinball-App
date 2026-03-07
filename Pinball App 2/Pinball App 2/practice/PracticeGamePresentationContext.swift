import SwiftUI

struct PracticeGamePresentationContext {
    let store: PracticeStore
    let selectedGameID: String
    let entryTask: Binding<StudyTaskKind?>
    let showingScoreSheet: Binding<Bool>
    let editingLogEntry: Binding<JournalEntry?>
    let pendingDeleteLogEntry: Binding<JournalEntry?>
    let saveBanner: String?
    let onShowSaveBanner: (String) -> Void
}
