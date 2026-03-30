import SwiftUI

struct GameNoteEntrySheet: View {
    let gameID: String
    @ObservedObject var store: PracticeStore
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var category: PracticeCategory = .general
    @State private var detail: String = ""
    @State private var note: String = ""
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                PracticeEntryGlassCard(maxHeight: 460) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Category", selection: $category) {
                            ForEach(noteCategories) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("Optional detail (mode/shot/skill)", text: $detail)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appControlStyle()

                        TextField("Note", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appControlStyle()

                        let detectedTags = store.detectedMechanicsTags(in: "\(detail) \(note)")
                        if !detectedTags.isEmpty {
                            Text("Detected mechanics: \(detectedTags.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let validationMessage {
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Spacer()
                    }
                    .padding(14)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCancelAction {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(title: "Save", isDisabled: gameID.isEmpty) {
                        if save() {
                            onSaved()
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var noteCategories: [PracticeCategory] {
        [.general, .shots, .modes, .multiball, .strategy]
    }

    private func save() -> Bool {
        validationMessage = nil
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationMessage = "Note cannot be empty."
            return false
        }
        store.addNote(gameID: gameID, category: category, detail: detail, note: trimmed)
        return true
    }
}
