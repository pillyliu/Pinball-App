import SwiftUI

struct GameRoomIssueAttachmentDraft: Identifiable {
    let id = UUID()
    let kind: MachineAttachmentKind
    let uri: String
    let caption: String?
}

struct GameRoomIssueAttachmentButtonRow: View {
    let onAddPhoto: () -> Void
    let onAddVideo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onAddPhoto) {
                Label("Add Photo", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppSecondaryActionButtonStyle())

            Button(action: onAddVideo) {
                Label("Add Video", systemImage: "video")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppSecondaryActionButtonStyle())
        }
    }
}

struct GameRoomIssueAttachmentList: View {
    let attachments: [GameRoomIssueAttachmentDraft]
    let onDeleteAttachment: (UUID) -> Void

    var body: some View {
        if attachments.isEmpty {
            AppPanelEmptyCard(text: "No media selected.")
        } else {
            ForEach(attachments) { attachment in
                GameRoomIssueAttachmentRow(
                    attachment: attachment,
                    onDelete: { onDeleteAttachment(attachment.id) }
                )
            }
        }
    }
}

struct GameRoomIssueAttachmentRow: View {
    let attachment: GameRoomIssueAttachmentDraft
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: attachment.kind == .photo ? "photo" : "video")
                .foregroundStyle(.secondary)
            Text(attachment.caption ?? attachment.uri)
                .font(.footnote)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}
