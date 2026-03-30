import SwiftUI

struct GameRoomOwnershipEntrySheet: View {
    private let ownershipTypes: [MachineEventType] = [
        .purchased,
        .moved,
        .loanedOut,
        .returned,
        .listedForSale,
        .sold,
        .traded,
        .reacquired
    ]

    let onSave: (Date, MachineEventType, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt = Date()
    @State private var eventType: MachineEventType = .moved
    @State private var summary = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)
                Picker("Event", selection: $eventType) {
                    ForEach(ownershipTypes) { type in
                        Text(type.displayTitle).tag(type)
                    }
                }
                .pickerStyle(.menu)

                TextField("Summary", text: $summary)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Ownership Update")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    summary = eventType.displayTitle
                }
            }
            .onChange(of: eventType) { _, next in
                if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ownershipTypes.contains(where: { $0.displayTitle == summary }) {
                    summary = next.displayTitle
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCancelAction { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(
                        title: "Save",
                        isDisabled: summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedSummary.isEmpty else { return }
                        onSave(occurredAt, eventType, trimmedSummary, gameRoomNormalizedOptional(notes))
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GameRoomPartOrModEntrySheet: View {
    let title: String
    let detailsLabel: String
    let detailsPrompt: String
    let submitLabel: String
    let onSave: (Date, String, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt = Date()
    @State private var summary = ""
    @State private var details = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)
                TextField("Summary", text: $summary)
                TextField(detailsLabel, text: $details, prompt: Text(detailsPrompt))
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    summary = title
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCancelAction { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(
                        title: LocalizedStringKey(submitLabel),
                        isDisabled: summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedSummary.isEmpty else { return }
                        onSave(
                            occurredAt,
                            trimmedSummary,
                            gameRoomNormalizedOptional(details),
                            gameRoomNormalizedOptional(notes)
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}
