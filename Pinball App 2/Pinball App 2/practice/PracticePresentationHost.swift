import SwiftUI

extension PracticeScreen {
    @ViewBuilder
    func practiceSheetContent(for sheet: PracticeSheet, context: PracticePresentationContext) -> some View {
        switch sheet {
        case .quickEntry:
            if let kind = context.quickEntryKind {
                PracticeQuickEntrySheet(
                    kind: kind,
                    store: context.store,
                    selectedGameID: context.selectedGameID,
                    onGameSelectionChanged: { sheet, gameID in
                        context.onRememberQuickEntryGame(sheet, gameID)
                    },
                    onEntrySaved: { gameID in
                        context.onMarkGameViewed(gameID)
                    }
                )
                .practiceEntrySheetStyle()
            }
        case .groupEditor:
            NavigationStack {
                GroupEditorScreen(
                    store: context.store,
                    editingGroupID: context.editingGroupID
                ) {
                    context.onDismissGroupEditor()
                }
            }
            .appSheetChrome(detents: [.large], background: .ultraThinMaterial)
        case .groupDateEditor:
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker(
                        context.currentGroupDateEditorTitle,
                        selection: context.currentGroupDateEditorValue,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)

                    HStack {
                        Button("Clear", role: .destructive) {
                            context.onClearEditedGroupDate()
                        }
                        .buttonStyle(.glass)

                        Spacer()

                        Button("Save") {
                            context.onSaveEditedGroupDate()
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppBackground())
                .navigationTitle(context.currentGroupDateEditorTitle == "Start Date" ? "Set Start Date" : "Set End Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            context.onDismissPresentedSheet()
                        }
                    }
                }
            }
            .appSheetChrome(detents: [.medium, .large], background: .ultraThinMaterial)
        case .journalEntryEditor:
            if let entry = context.editingJournalEntry {
                PracticeJournalEntryEditorSheet(
                    entry: entry,
                    store: context.store,
                    onSave: { updated in
                        context.onSaveEditedJournalEntry(updated)
                    }
                )
                .practiceEntrySheetStyle()
            }
        }
    }

    func practiceResetAlert<Content: View>(_ content: Content, context: PracticePresentationContext) -> some View {
        content
            .alert("Reset Practice Log?", isPresented: context.showingResetJournalPrompt) {
                TextField("Type reset", text: context.resetJournalConfirmationText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("No", role: .cancel) {}
                Button("Yes, Reset", role: .destructive) {
                    context.onConfirmResetPracticeLog()
                }
                .disabled(context.resetJournalConfirmationText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "reset")
            } message: {
                Text("This resets the full local Practice JSON log state. Type \"reset\" to enable confirmation.")
            }
    }
}
