import SwiftUI

struct GameRoomMediaEntryFormContent: View {
    @Binding var kind: MachineAttachmentKind
    @Binding var uri: String
    @Binding var caption: String
    @Binding var notes: String
    let resolvedMediaURL: URL?
    let mediaImportState: GameRoomMediaImportState
    let focusedField: FocusState<GameRoomMediaEntryField?>.Binding
    let onPresentPicker: (MachineAttachmentKind) -> Void

    var body: some View {
        Form {
            Picker("Type", selection: $kind) {
                Text("Photo").tag(MachineAttachmentKind.photo)
                Text("Video").tag(MachineAttachmentKind.video)
            }
            .appSegmentedControlStyle()

            Button {
                onPresentPicker(kind)
            } label: {
                Label(
                    kind == .photo ? "Pick Photo" : "Pick Video",
                    systemImage: kind == .photo ? "photo.on.rectangle" : "video"
                )
            }
            .buttonStyle(.borderless)
            .contentShape(Rectangle())

            GameRoomMediaImportStatusSection(mediaImportState: mediaImportState)

            if kind == .photo, let resolvedMediaURL {
                ConstrainedAsyncImagePreview(
                    candidates: [resolvedMediaURL],
                    emptyMessage: "No image",
                    maxAspectRatio: 4.0 / 3.0,
                    imagePadding: 0
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            TextField("Media URL / URI", text: $uri)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(focusedField, equals: .uri)
            TextField("Caption", text: $caption)
                .focused(focusedField, equals: .caption)
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .focused(focusedField, equals: .notes)
        }
    }
}
