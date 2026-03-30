import SwiftUI

extension GameRoomMachineInputSheetContent {
    @ViewBuilder
    func installModSheet() -> some View {
        GameRoomPartOrModEntrySheet(
            title: "Install Mod",
            detailsLabel: "Mod",
            detailsPrompt: "Mod Name / Details",
            submitLabel: "Save",
            onSave: { occurredAt, summary, details, notes in
                store.addEvent(
                    machineID: machine.id,
                    type: .modInstalled,
                    category: .mod,
                    occurredAt: occurredAt,
                    summary: summary,
                    notes: notes,
                    partsUsed: details
                )
            }
        )
        .gameRoomEntrySheetStyle()
    }

    @ViewBuilder
    func replacePartSheet() -> some View {
        GameRoomPartOrModEntrySheet(
            title: "Replace Part",
            detailsLabel: "Part",
            detailsPrompt: "Part Replaced",
            submitLabel: "Save",
            onSave: { occurredAt, summary, details, notes in
                store.addEvent(
                    machineID: machine.id,
                    type: .partReplaced,
                    category: .service,
                    occurredAt: occurredAt,
                    summary: summary,
                    notes: notes,
                    partsUsed: details
                )
            }
        )
        .gameRoomEntrySheetStyle()
    }

    @ViewBuilder
    func logPlaysSheet() -> some View {
        GameRoomPlayCountEntrySheet { occurredAt, playTotal, notes in
            store.addEvent(
                machineID: machine.id,
                type: .custom,
                category: .custom,
                occurredAt: occurredAt,
                playCountAtEvent: playTotal,
                summary: "Log Plays (Total \(playTotal))",
                notes: notes
            )
        }
        .gameRoomEntrySheetStyle()
    }
}
