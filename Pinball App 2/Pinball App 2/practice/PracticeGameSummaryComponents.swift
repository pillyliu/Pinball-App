import SwiftUI

struct PracticeGameScreenshotSection: View {
    let game: PinballGame?

    var body: some View {
        Group {
            if let game {
                ConstrainedAsyncImagePreview(
                    candidates: game.gamePlayfieldCandidates,
                    emptyMessage: "No image",
                    maxAspectRatio: 4.0 / 3.0,
                    imagePadding: 0
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .overlay {
                        Text("Select a game")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}

struct PracticeGameNoteCard: View {
    @Binding var note: String
    let isDisabled: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game Note")
                .font(.headline)

            TextEditor(text: $note)
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .appControlStyle()

            HStack {
                Spacer()
                Button("Save Note", action: onSave)
                    .buttonStyle(.glass)
                    .disabled(isDisabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }
}
