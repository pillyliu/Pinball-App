import SwiftUI
import PhotosUI

struct GameRoomLogIssueSheet: View {
    let onSave: (Date, String, MachineIssueSeverity, MachineIssueSubsystem, String?, [GameRoomIssueAttachmentDraft]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = GameRoomIssueLogDraft()
    @State private var mediaImportState = GameRoomMediaImportState()

    var body: some View {
        NavigationStack {
            GameRoomIssueLogFormContent(
                openedAt: $draft.openedAt,
                symptom: $draft.symptom,
                severity: $draft.severity,
                subsystem: $draft.subsystem,
                diagnosis: $draft.diagnosis,
                attachments: draft.attachments,
                mediaImportState: mediaImportState,
                onAddPhoto: { presentPicker(for: .photo) },
                onAddVideo: { presentPicker(for: .video) },
                onDeleteAttachment: deleteAttachment(id:)
            )
            .navigationTitle("Log Issue")
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
                        isDisabled: draft.trimmedSymptom.isEmpty
                    ) {
                        guard !draft.trimmedSymptom.isEmpty else { return }
                        onSave(
                            draft.openedAt,
                            draft.trimmedSymptom,
                            draft.severity,
                            draft.subsystem,
                            draft.normalizedDiagnosis,
                            draft.attachments
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private func presentPicker(for kind: MachineAttachmentKind) {
        mediaImportState.preparePicker(for: kind)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            mediaImportState.showMediaPicker = true
        }
    }

    private func deleteAttachment(id: UUID) {
        draft.deleteAttachment(id: id)
    }

    private func importSelectedMedia(_ item: PhotosPickerItem) {
        let pickerKind = mediaImportState.pickerKind
        mediaImportState.beginImport()
        Task {
            do {
                let importedURL = try await gameRoomImportedMediaURL(from: item, kind: pickerKind)
                await MainActor.run {
                    draft.appendAttachment(kind: pickerKind, url: importedURL)
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
