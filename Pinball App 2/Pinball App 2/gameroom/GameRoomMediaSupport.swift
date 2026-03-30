import SwiftUI
import AVKit
import UIKit

struct GameRoomAttachmentPreviewSheet: View {
    let attachment: MachineAttachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if attachment.kind == .photo, let url = resolvedURL {
                    HostedImageView(imageCandidates: [url])
                } else if attachment.kind == .video, let url = resolvedURL {
                    VideoPlayer(player: AVPlayer(url: url))
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                } else {
                    AppFullscreenStatusOverlay(text: "Media unavailable")
                }
            }
            .padding(14)
            .navigationTitle(attachment.kind == .photo ? "Photo" : "Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarDoneAction { dismiss() }
                }
            }
        }
    }

    private var resolvedURL: URL? {
        gameRoomResolvedMediaURL(from: attachment.uri)
    }
}

struct GameRoomMediaEditSheet: View {
    let attachment: MachineAttachment
    let initialNotes: String?
    let onSave: (String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Caption", text: $caption)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Edit Media")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                caption = attachment.caption ?? ""
                notes = initialNotes ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCancelAction { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(title: "Save") {
                        onSave(gameRoomNormalizedOptional(caption), gameRoomNormalizedOptional(notes))
                        dismiss()
                    }
                }
            }
        }
    }
}
