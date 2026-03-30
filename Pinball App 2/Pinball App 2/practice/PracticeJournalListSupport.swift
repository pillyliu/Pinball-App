import SwiftUI

struct PracticeJournalEditActionBar: View {
    let canEditSelection: Bool
    let canDeleteSelection: Bool
    let onEditSelection: () -> Void
    let onDeleteSelection: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button("Edit", action: onEditSelection)
                .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                .disabled(!canEditSelection)

            Button("Delete", role: .destructive, action: onDeleteSelection)
                .buttonStyle(AppDestructiveActionButtonStyle(fillsWidth: false))
                .disabled(!canDeleteSelection)
        }
    }
}

struct PracticeJournalListPanel: View {
    let sections: [PracticeJournalDaySection]
    let isEditingEntries: Bool
    @Binding var selectedItemIDs: Set<String>
    let gameTransition: Namespace.ID
    let onTapItem: (String, String) -> Void
    let onEditJournalEntry: (JournalEntry) -> Void
    let onDeleteJournalEntries: ([JournalEntry]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if sections.isEmpty {
                Text("No matching journal events.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                List {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.items) { entry in
                                PracticeJournalListRow(
                                    entry: entry,
                                    isEditingEntries: isEditingEntries,
                                    selectedItemIDs: $selectedItemIDs,
                                    gameTransition: gameTransition,
                                    onTapItem: onTapItem,
                                    onEditJournalEntry: onEditJournalEntry,
                                    onDeleteJournalEntries: onDeleteJournalEntries
                                )
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        } header: {
                            PracticeJournalDayHeader(day: section.day)
                        }
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(0)
                .contentMargins(.top, 0, for: .scrollContent)
                .contentMargins(.top, 0, for: .scrollIndicators)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 1)
                .environment(\.defaultMinListHeaderHeight, 1)
            }
        }
    }
}

struct PracticeJournalDayHeader: View {
    let day: Date

    var body: some View {
        HStack {
            Text(day.formatted(date: .abbreviated, time: .omitted))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.cyan.opacity(0.95))
                .textCase(nil)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(AppTheme.panel.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(AppTheme.border.opacity(0.55), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, -16)
        .padding(.top, 1)
        .padding(.bottom, 1)
    }
}

struct PracticeJournalListRow: View {
    let entry: PracticeJournalItem
    let isEditingEntries: Bool
    @Binding var selectedItemIDs: Set<String>
    let gameTransition: Namespace.ID
    let onTapItem: (String, String) -> Void
    let onEditJournalEntry: (JournalEntry) -> Void
    let onDeleteJournalEntries: ([JournalEntry]) -> Void

    var body: some View {
        let rowContent = rowContentView

        if !isEditingEntries, entry.isEditablePracticeEntry, let journal = entry.journalEntry {
            JournalStaticEditableRow {
                rowContent
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    onDeleteJournalEntries([journal])
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)

                Button {
                    onEditJournalEntry(journal)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(AppTheme.statsMeanMedian)
            }
        } else if entry.isEditablePracticeEntry {
            JournalStaticEditableRow {
                rowContent
            }
        } else {
            rowContent
        }
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if entry.isEditablePracticeEntry {
            Image(systemName: selectedItemIDs.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selectedItemIDs.contains(entry.id) ? .orange : .secondary)
                .font(.body)
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.clear)
                .font(.body)
        }
    }

    private var rowContentView: some View {
        HStack(alignment: .top, spacing: 8) {
            if isEditingEntries {
                selectionIndicator
            }

            Image(systemName: entry.icon)
                .font(.caption)
                .frame(width: 14)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                styledPracticeJournalSummary(entry.summary)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: handleTap)
        .matchedTransitionSource(id: transitionSourceID, in: gameTransition)
    }

    private var transitionSourceID: String {
        "\(entry.gameID)-\(entry.id)"
    }

    private func handleTap() {
        if isEditingEntries {
            guard entry.isEditablePracticeEntry else { return }
            if selectedItemIDs.contains(entry.id) {
                selectedItemIDs.remove(entry.id)
            } else {
                selectedItemIDs.insert(entry.id)
            }
            return
        }
        onTapItem(entry.gameID, transitionSourceID)
    }
}

struct JournalStaticEditableRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.6), lineWidth: 1)
            )
            .padding(.vertical, 1)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
