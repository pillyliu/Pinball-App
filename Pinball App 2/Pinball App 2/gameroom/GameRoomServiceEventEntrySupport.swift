import SwiftUI

struct GameRoomServiceEntrySheet: View {
    let title: String
    let submitLabel: String
    let includesConsumableField: Bool
    let includesPitchFields: Bool
    let onSave: (Date, String?, String?, Double?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt = Date()
    @State private var notes = ""
    @State private var consumable = ""
    @State private var pitchValueText = ""
    @State private var pitchMeasurementPoint = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)

                if includesConsumableField {
                    TextField("Cleaner / Consumable", text: $consumable)
                }

                if includesPitchFields {
                    TextField("Pitch Value", text: $pitchValueText)
                        .keyboardType(.decimalPad)
                    TextField("Measurement Point", text: $pitchMeasurementPoint)
                }

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCancelAction { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(title: LocalizedStringKey(submitLabel)) {
                        onSave(
                            occurredAt,
                            gameRoomNormalizedOptional(notes),
                            gameRoomNormalizedOptional(consumable),
                            parsedPitchValue,
                            gameRoomNormalizedOptional(pitchMeasurementPoint)
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private var parsedPitchValue: Double? {
        Double(pitchValueText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct GameRoomPlayCountEntrySheet: View {
    let onSave: (Date, Int, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt = Date()
    @State private var playTotalText = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)
                TextField("Total Plays", text: $playTotalText)
                    .keyboardType(.numberPad)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Log Plays")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCancelAction { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(title: "Save", isDisabled: parsedPlayTotal == nil) {
                        guard let playTotal = parsedPlayTotal else { return }
                        onSave(occurredAt, playTotal, gameRoomNormalizedOptional(notes))
                        dismiss()
                    }
                }
            }
        }
    }

    private var parsedPlayTotal: Int? {
        guard let value = Int(playTotalText.trimmingCharacters(in: .whitespacesAndNewlines)), value >= 0 else {
            return nil
        }
        return value
    }
}
