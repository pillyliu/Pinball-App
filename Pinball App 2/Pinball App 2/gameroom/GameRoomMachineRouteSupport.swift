import SwiftUI

enum GameRoomMachineAttachmentOpenTarget {
    case fullscreenPhoto(URL)
    case preview(MachineAttachment)
}

func gameRoomMachine(
    machineID: UUID,
    activeMachines: [OwnedMachine],
    archivedMachines: [OwnedMachine]
) -> OwnedMachine? {
    (activeMachines + archivedMachines).first(where: { $0.id == machineID })
}

func gameRoomOptionalAlertBinding<Value>(for value: Binding<Value?>) -> Binding<Bool> {
    Binding(
        get: { value.wrappedValue != nil },
        set: { isPresented in
            if !isPresented {
                value.wrappedValue = nil
            }
        }
    )
}

func gameRoomAttachmentOpenTarget(
    attachment: MachineAttachment,
    resolvedURL: URL?
) -> GameRoomMachineAttachmentOpenTarget {
    if attachment.kind == .photo, let resolvedURL {
        return .fullscreenPhoto(resolvedURL)
    }
    return .preview(attachment)
}

func gameRoomRecentAttachments(
    for machineID: UUID,
    attachments: [MachineAttachment]
) -> [MachineAttachment] {
    attachments
        .filter { $0.ownedMachineID == machineID }
        .sorted { $0.createdAt > $1.createdAt }
}

func gameRoomMachineHasOpenIssues(
    machineID: UUID,
    issues: [MachineIssue]
) -> Bool {
    issues.contains(where: { $0.ownedMachineID == machineID && $0.status != .resolved })
}

func gameRoomLinkedAttachment(
    for event: MachineEvent,
    attachments: [MachineAttachment]
) -> MachineAttachment? {
    attachments
        .filter { $0.ownerType == .event && $0.ownerID == event.id }
        .sorted { $0.createdAt > $1.createdAt }
        .first
}

func gameRoomLinkedEvent(
    for attachment: MachineAttachment,
    events: [MachineEvent]
) -> MachineEvent? {
    guard attachment.ownerType == .event else { return nil }
    return events.first(where: { $0.id == attachment.ownerID })
}

func gameRoomSortedMachineEvents(
    for machineID: UUID,
    events: [MachineEvent]
) -> [MachineEvent] {
    events
        .filter { $0.ownedMachineID == machineID }
        .sorted { $0.occurredAt > $1.occurredAt }
}
