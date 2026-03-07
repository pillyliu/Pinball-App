import SwiftUI

struct PracticeJournalContext {
    let journalFilter: Binding<JournalFilter>
    let items: [PracticeJournalItem]
    let isEditingEntries: Binding<Bool>
    let selectedItemIDs: Binding<Set<String>>
    let gameTransition: Namespace.ID
    let onToggleEditing: () -> Void
    let onOpenGame: (String, String) -> Void
    let onEditJournalEntry: (JournalEntry) -> Void
    let onDeleteJournalEntries: ([JournalEntry]) -> Void
}
