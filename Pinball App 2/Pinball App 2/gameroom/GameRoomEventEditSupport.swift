import SwiftUI

struct GameRoomEventEditSheet: View {
    let event: MachineEvent
    let onSave: (Date, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt: Date
    @State private var summary: String
    @State private var notes: String

    init(event: MachineEvent, onSave: @escaping (Date, String, String?) -> Void) {
        self.event = event
        self.onSave = onSave
        _occurredAt = State(initialValue: event.occurredAt)
        _summary = State(initialValue: event.summary)
        _notes = State(initialValue: event.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)
                TextField("Summary", text: $summary)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Edit Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCancelAction { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(
                        title: "Save",
                        isDisabled: summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        onSave(occurredAt, summary, gameRoomNormalizedOptional(notes))
                        dismiss()
                    }
                }
            }
        }
    }
}
