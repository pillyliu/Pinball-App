import SwiftUI

struct PracticeJournalItem: Identifiable {
    let id: String
    let gameID: String
    let summary: String
    let icon: String
    let timestamp: Date
    let journalEntry: JournalEntry?

    var isEditablePracticeEntry: Bool {
        journalEntry?.action.supportsEditing ?? false
    }
}

struct PracticeJournalDaySection: Identifiable {
    let day: Date
    let items: [PracticeJournalItem]

    var id: Date { day }
}

func groupedPracticeJournalSections(_ items: [PracticeJournalItem], calendar: Calendar = .current) -> [PracticeJournalDaySection] {
    let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.timestamp) }
    return grouped.keys
        .sorted(by: >)
        .map { day in
            PracticeJournalDaySection(day: day, items: grouped[day] ?? [])
        }
}

struct PracticeJournalSectionView: View {
    @Binding var journalFilter: JournalFilter
    let sections: [PracticeJournalDaySection]
    @Binding var isEditingEntries: Bool
    @Binding var selectedItemIDs: Set<String>
    let gameTransition: Namespace.ID
    let onTapItem: (String, String) -> Void
    let onEditJournalEntry: (JournalEntry) -> Void
    let onDeleteJournalEntries: ([JournalEntry]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Filter", selection: $journalFilter) {
                ForEach(JournalFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .appSegmentedControlStyle()

            if isEditingEntries {
                PracticeJournalEditActionBar(
                    canEditSelection: selectedEditableJournalEntries.count == 1,
                    canDeleteSelection: !selectedEditableJournalEntries.isEmpty,
                    onEditSelection: editSelectedJournalEntry,
                    onDeleteSelection: deleteSelectedJournalEntries
                )
            }

            PracticeJournalListPanel(
                sections: sections,
                isEditingEntries: isEditingEntries,
                selectedItemIDs: $selectedItemIDs,
                gameTransition: gameTransition,
                onTapItem: onTapItem,
                onEditJournalEntry: onEditJournalEntry,
                onDeleteJournalEntries: onDeleteJournalEntries
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .appPanelStyle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var selectedJournalEntries: [JournalEntry] {
        allItems
            .filter { selectedItemIDs.contains($0.id) }
            .compactMap(\.journalEntry)
    }

    private var selectedEditableJournalEntries: [JournalEntry] {
        allItems
            .filter { selectedItemIDs.contains($0.id) && $0.isEditablePracticeEntry }
            .compactMap(\.journalEntry)
    }

    private var allItems: [PracticeJournalItem] {
        sections.flatMap(\.items)
    }

    private func editSelectedJournalEntry() {
        guard let entry = selectedJournalEntries.first, selectedJournalEntries.count == 1 else { return }
        onEditJournalEntry(entry)
    }

    private func deleteSelectedJournalEntries() {
        guard !selectedEditableJournalEntries.isEmpty else { return }
        onDeleteJournalEntries(selectedEditableJournalEntries)
    }
}
