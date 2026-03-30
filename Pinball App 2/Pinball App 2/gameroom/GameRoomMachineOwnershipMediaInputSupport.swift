import SwiftUI

extension GameRoomMachineInputSheetContent {
    @ViewBuilder
    func ownershipUpdateSheet() -> some View {
        GameRoomOwnershipEntrySheet { occurredAt, eventType, summary, notes in
            store.addEvent(
                machineID: machine.id,
                type: eventType,
                category: .ownership,
                occurredAt: occurredAt,
                summary: summary,
                notes: notes
            )
        }
        .gameRoomEntrySheetStyle()
    }

    @ViewBuilder
    func addMediaSheet() -> some View {
        GameRoomMediaEntrySheet { kind, uri, caption, notes in
            let eventType: MachineEventType = kind == .photo ? .photoAdded : .videoAdded
            let summary = kind == .photo ? "Photo Added" : "Video Added"
            let eventID = store.addEvent(
                machineID: machine.id,
                type: eventType,
                category: .media,
                summary: summary,
                notes: notes
            )
            store.addAttachment(
                machineID: machine.id,
                ownerType: .event,
                ownerID: eventID,
                kind: kind,
                uri: uri,
                caption: caption
            )
        }
        .gameRoomMediaSheetStyle()
    }
}
