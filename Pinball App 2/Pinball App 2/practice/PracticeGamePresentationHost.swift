import SwiftUI

struct PracticeGamePresentationHost<Content: View>: View {
    let context: PracticeGamePresentationContext
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .sheet(item: context.entryTask, content: taskEntrySheet)
            .sheet(isPresented: context.showingScoreSheet) {
                GameScoreEntrySheet(
                    gameID: context.selectedGameID,
                    store: context.store,
                    onSaved: {
                        context.onShowSaveBanner("Score logged")
                    }
                )
                .practiceEntrySheetStyle()
            }
            .sheet(item: context.editingLogEntry) { entry in
                PracticeJournalEntryEditorSheet(entry: entry, store: context.store) { updated in
                    if context.store.updateJournalEntry(updated) {
                        context.onShowSaveBanner("Entry updated")
                    }
                }
                .practiceEntrySheetStyle()
            }
            .alert("Delete entry?", isPresented: deleteAlertIsPresented) {
                Button("Delete", role: .destructive) {
                    if let entry = context.pendingDeleteLogEntry.wrappedValue {
                        _ = context.store.deleteJournalEntry(id: entry.id)
                        context.onShowSaveBanner("Entry deleted")
                    }
                    context.pendingDeleteLogEntry.wrappedValue = nil
                }
                Button("Cancel", role: .cancel) {
                    context.pendingDeleteLogEntry.wrappedValue = nil
                }
            } message: {
                Text("This will remove the selected journal entry and linked practice data.")
            }
            .overlay(alignment: .top) {
                if let saveBanner = context.saveBanner {
                    PracticeGameSaveBanner(message: saveBanner)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: context.saveBanner)
    }

    private var deleteAlertIsPresented: Binding<Bool> {
        Binding(
            get: { context.pendingDeleteLogEntry.wrappedValue != nil },
            set: { if !$0 { context.pendingDeleteLogEntry.wrappedValue = nil } }
        )
    }

    @ViewBuilder
    private func taskEntrySheet(for task: StudyTaskKind) -> some View {
        GameTaskEntrySheet(
            task: task,
            gameID: context.selectedGameID,
            store: context.store,
            onSaved: { message in
                context.onShowSaveBanner(message)
            }
        )
        .practiceEntrySheetStyle()
    }
}

private struct PracticeGameSaveBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.2), in: Capsule())
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
