import SwiftUI

extension GameRoomMachineInputSheetContent {
    @ViewBuilder
    func logIssueSheet() -> some View {
        GameRoomLogIssueSheet { occurredAt, symptom, severity, subsystem, diagnosis, attachments in
            let issueID = store.openIssue(
                machineID: machine.id,
                openedAt: occurredAt,
                symptom: symptom,
                severity: severity,
                subsystem: subsystem,
                diagnosis: diagnosis
            )
            store.addEvent(
                machineID: machine.id,
                type: .issueOpened,
                category: .issue,
                occurredAt: occurredAt,
                summary: symptom,
                notes: diagnosis,
                linkedIssueID: issueID
            )
            for attachment in attachments {
                store.addAttachment(
                    machineID: machine.id,
                    ownerType: .issue,
                    ownerID: issueID,
                    kind: attachment.kind,
                    uri: attachment.uri,
                    caption: attachment.caption
                )
                store.addEvent(
                    machineID: machine.id,
                    type: attachment.kind == .photo ? .photoAdded : .videoAdded,
                    category: .media,
                    occurredAt: occurredAt,
                    summary: attachment.kind == .photo ? "Issue photo added" : "Issue video added",
                    linkedIssueID: issueID
                )
            }
        }
        .gameRoomEntrySheetStyle()
    }

    @ViewBuilder
    func resolveIssueSheet() -> some View {
        GameRoomResolveIssueSheet(
            openIssues: store.state.issues
                .filter { $0.ownedMachineID == machine.id && $0.status != .resolved }
                .sorted { $0.openedAt > $1.openedAt },
            onSave: { issueID, resolvedAt, resolution in
                store.resolveIssue(id: issueID, resolvedAt: resolvedAt, resolution: resolution)
                store.addEvent(
                    machineID: machine.id,
                    type: .issueResolved,
                    category: .issue,
                    occurredAt: resolvedAt,
                    summary: "Resolve Issue",
                    notes: resolution,
                    linkedIssueID: issueID
                )
            }
        )
        .gameRoomEntrySheetStyle()
    }
}
