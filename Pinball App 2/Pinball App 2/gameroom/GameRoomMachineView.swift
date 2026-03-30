import SwiftUI

struct GameRoomMachineView: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let machineID: UUID
    let navigationTitle: String
    @State private var selectedSubview: GameRoomMachineSubview = .summary
    @State private var editingEvent: MachineEvent?
    @State private var pendingDeleteEvent: MachineEvent?
    @State private var activeInputSheet: GameRoomMachineInputSheet?
    @State private var selectedLogEventID: UUID?
    @State private var previewAttachment: MachineAttachment?
    @State private var editingAttachment: MachineAttachment?
    @State private var pendingDeleteAttachment: MachineAttachment?
    @State private var fullscreenPhotoItem: GameRoomMachineFullscreenPhotoItem?

    private var machine: OwnedMachine? {
        gameRoomMachine(
            machineID: machineID,
            activeMachines: store.activeMachines,
            archivedMachines: store.archivedMachines
        )
    }

    var body: some View {
        GameRoomMachineContentView(
            store: store,
            catalogLoader: catalogLoader,
            machine: machine,
            selectedSubview: $selectedSubview,
            selectedLogEventID: $selectedLogEventID,
            linkedAttachment: linkedAttachment(for:),
            linkedEvent: linkedEvent(for:),
            attachmentURL: urlForAttachmentURI(_:),
            onOpenAttachment: openAttachment(_:),
            onEditAttachment: { editingAttachment = $0 },
            onDeleteAttachment: { pendingDeleteAttachment = $0 },
            onSelectInputSheet: { activeInputSheet = $0 },
            onEditEvent: { editingEvent = $0 },
            onDeleteEvent: { pendingDeleteEvent = $0 }
        )
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .appEdgeBackGesture()
            .sheet(item: $editingEvent) { event in
                GameRoomEventEditSheet(
                    event: event,
                    onSave: { occurredAt, summary, notes in
                        store.updateEvent(id: event.id, occurredAt: occurredAt, summary: summary, notes: notes)
                    }
                )
                .gameRoomEntrySheetStyle()
            }
            .sheet(item: $activeInputSheet) { sheet in
                if let machine {
                    GameRoomMachineInputSheetContent(
                        sheet: sheet,
                        machine: machine,
                        store: store
                    )
                } else {
                    EmptyView()
                }
            }
            .sheet(item: $previewAttachment) { attachment in
                GameRoomAttachmentPreviewSheet(attachment: attachment)
            }
            .sheet(item: $editingAttachment) { attachment in
                GameRoomMediaEditSheet(
                    attachment: attachment,
                    initialNotes: linkedEvent(for: attachment)?.notes,
                    onSave: { caption, notes in
                        store.updateAttachment(id: attachment.id, caption: caption, notes: notes)
                    }
                )
                .gameRoomEntrySheetStyle()
            }
            .navigationDestination(item: $fullscreenPhotoItem) { item in
                HostedImageView(imageCandidates: [item.url])
            }
            .alert("Delete Log Entry?", isPresented: pendingDeleteEventAlertIsPresented) {
                Button("Delete", role: .destructive) {
                    guard let event = pendingDeleteEvent else { return }
                    store.deleteEvent(id: event.id)
                    pendingDeleteEvent = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteEvent = nil
                }
            } message: {
                Text("This cannot be undone.")
            }
            .alert("Delete Media?", isPresented: pendingDeleteAttachmentAlertIsPresented) {
                Button("Delete", role: .destructive) {
                    guard let attachment = pendingDeleteAttachment else { return }
                    store.deleteAttachmentAndLinkedEvent(id: attachment.id)
                    pendingDeleteAttachment = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteAttachment = nil
                }
            } message: {
                Text("This removes the media and linked log event.")
            }
    }

    private var pendingDeleteEventAlertIsPresented: Binding<Bool> {
        gameRoomOptionalAlertBinding(for: $pendingDeleteEvent)
    }

    private var pendingDeleteAttachmentAlertIsPresented: Binding<Bool> {
        gameRoomOptionalAlertBinding(for: $pendingDeleteAttachment)
    }

    private func linkedAttachment(for event: MachineEvent) -> MachineAttachment? {
        gameRoomLinkedAttachment(for: event, attachments: store.state.attachments)
    }

    private func linkedEvent(for attachment: MachineAttachment) -> MachineEvent? {
        gameRoomLinkedEvent(for: attachment, events: store.state.events)
    }

    private func openAttachment(_ attachment: MachineAttachment) {
        switch gameRoomAttachmentOpenTarget(
            attachment: attachment,
            resolvedURL: urlForAttachmentURI(attachment.uri)
        ) {
        case .fullscreenPhoto(let url):
            fullscreenPhotoItem = GameRoomMachineFullscreenPhotoItem(url: url)
        case .preview(let attachment):
            previewAttachment = attachment
        }
    }

    private func urlForAttachmentURI(_ uri: String) -> URL? {
        gameRoomResolvedMediaURL(from: uri)
    }
}
