import SwiftUI

struct PracticePresentationContext {
    let store: PracticeStore
    let selectedGameID: Binding<String>
    let presentedSheet: Binding<PracticeSheet?>
    let quickEntryKind: QuickEntrySheet?
    let editingGroupID: UUID?
    let currentGroupDateEditorTitle: String
    let currentGroupDateEditorValue: Binding<Date>
    let editingJournalEntry: JournalEntry?
    let showingResetJournalPrompt: Binding<Bool>
    let resetJournalConfirmationText: Binding<String>
    let onRememberQuickEntryGame: (QuickEntrySheet, String) -> Void
    let onMarkGameViewed: (String) -> Void
    let onDismissPresentedSheet: () -> Void
    let onDismissGroupEditor: () -> Void
    let onClearEditedGroupDate: () -> Void
    let onSaveEditedGroupDate: () -> Void
    let onSaveEditedJournalEntry: (JournalEntry) -> Void
    let onConfirmResetPracticeLog: () -> Void
    let onPresentedSheetDismissed: () -> Void
}
