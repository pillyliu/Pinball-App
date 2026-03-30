import SwiftUI

struct GameRoomIssueLogFormContent: View {
    @Binding var openedAt: Date
    @Binding var symptom: String
    @Binding var severity: MachineIssueSeverity
    @Binding var subsystem: MachineIssueSubsystem
    @Binding var diagnosis: String
    let attachments: [GameRoomIssueAttachmentDraft]
    let mediaImportState: GameRoomMediaImportState
    let onAddPhoto: () -> Void
    let onAddVideo: () -> Void
    let onDeleteAttachment: (UUID) -> Void

    var body: some View {
        Form {
            DatePicker("Opened", selection: $openedAt)
            TextField("Symptom", text: $symptom)

            Picker("Severity", selection: $severity) {
                ForEach(MachineIssueSeverity.allCases) { level in
                    Text(level.rawValue.capitalized).tag(level)
                }
            }
            .pickerStyle(.menu)

            Picker("Subsystem", selection: $subsystem) {
                ForEach(MachineIssueSubsystem.allCases) { value in
                    Text(value.displayTitle).tag(value)
                }
            }
            .pickerStyle(.menu)

            TextField("Diagnosis / Notes", text: $diagnosis, axis: .vertical)
                .lineLimit(3, reservesSpace: true)

            GameRoomIssueAttachmentButtonRow(
                onAddPhoto: onAddPhoto,
                onAddVideo: onAddVideo
            )

            GameRoomMediaImportStatusSection(mediaImportState: mediaImportState)

            GameRoomIssueAttachmentList(
                attachments: attachments,
                onDeleteAttachment: onDeleteAttachment
            )
        }
    }
}
