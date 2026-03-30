import SwiftUI
import PhotosUI

struct GameRoomMediaEntrySheet: View {
    let onSave: (MachineAttachmentKind, String, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = GameRoomMediaEntryDraft()
    @State private var mediaImportState = GameRoomMediaImportState()
    @FocusState private var focusedField: GameRoomMediaEntryField?

    var body: some View {
        NavigationStack {
            GameRoomMediaEntryFormContent(
                kind: $draft.kind,
                uri: $draft.uri,
                caption: $draft.caption,
                notes: $draft.notes,
                resolvedMediaURL: draft.resolvedMediaURL,
                mediaImportState: mediaImportState,
                focusedField: $focusedField,
                onPresentPicker: presentPicker(for:)
            )
            .navigationTitle("Add Photo/Video")
            .navigationBarTitleDisplayMode(.inline)
            .photosPicker(
                isPresented: $mediaImportState.showMediaPicker,
                selection: $mediaImportState.selectedMediaItem,
                matching: mediaImportState.pickerKind == .photo ? .images : .videos,
                photoLibrary: .shared()
            )
            .onChange(of: mediaImportState.selectedMediaItem) { _, item in
                guard let item else { return }
                importSelectedMedia(item)
                mediaImportState.clearSelection()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCancelAction { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(
                        title: "Save",
                        isDisabled: draft.trimmedURI.isEmpty
                    ) {
                        guard !draft.trimmedURI.isEmpty else { return }
                        onSave(draft.kind, draft.trimmedURI, draft.normalizedCaption, draft.normalizedNotes)
                        dismiss()
                    }
                }
            }
        }
    }

    private func presentPicker(for kind: MachineAttachmentKind) {
        focusedField = nil
        mediaImportState.preparePicker(for: kind)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            mediaImportState.showMediaPicker = true
        }
    }

    private func importSelectedMedia(_ item: PhotosPickerItem) {
        let pickerKind = mediaImportState.pickerKind
        mediaImportState.beginImport()
        Task {
            do {
                let importedURL = try await gameRoomImportedMediaURL(from: item, kind: pickerKind)
                await MainActor.run {
                    draft.uri = importedURL.path
                    mediaImportState.finishImport()
                }
            } catch {
                await MainActor.run {
                    mediaImportState.failImport(for: pickerKind)
                }
            }
        }
    }
}
