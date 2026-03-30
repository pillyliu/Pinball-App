import SwiftUI

extension GameRoomMachineInputSheetContent {
    @ViewBuilder
    func cleanGlassSheet() -> some View {
        GameRoomServiceEntrySheet(
            title: "Clean Glass",
            submitLabel: "Save",
            includesConsumableField: false,
            includesPitchFields: false,
            onSave: { occurredAt, notes, _, _, _ in
                store.addEvent(
                    machineID: machine.id,
                    type: .glassCleaned,
                    category: .service,
                    occurredAt: occurredAt,
                    summary: "Clean Glass",
                    notes: notes
                )
            }
        )
        .gameRoomEntrySheetStyle()
    }

    @ViewBuilder
    func cleanPlayfieldSheet() -> some View {
        GameRoomServiceEntrySheet(
            title: "Clean Playfield",
            submitLabel: "Save",
            includesConsumableField: true,
            includesPitchFields: false,
            onSave: { occurredAt, notes, consumable, _, _ in
                store.addEvent(
                    machineID: machine.id,
                    type: .playfieldCleaned,
                    category: .service,
                    occurredAt: occurredAt,
                    summary: "Clean Playfield",
                    notes: notes,
                    consumablesUsed: consumable
                )
            }
        )
        .gameRoomEntrySheetStyle()
    }

    @ViewBuilder
    func swapBallsSheet() -> some View {
        GameRoomServiceEntrySheet(
            title: "Swap Balls",
            submitLabel: "Save",
            includesConsumableField: false,
            includesPitchFields: false,
            onSave: { occurredAt, notes, _, _, _ in
                store.addEvent(
                    machineID: machine.id,
                    type: .ballsReplaced,
                    category: .service,
                    occurredAt: occurredAt,
                    summary: "Swap Balls",
                    notes: notes
                )
            }
        )
        .gameRoomEntrySheetStyle()
    }

    @ViewBuilder
    func checkPitchSheet() -> some View {
        GameRoomServiceEntrySheet(
            title: "Check Pitch",
            submitLabel: "Save",
            includesConsumableField: false,
            includesPitchFields: true,
            onSave: { occurredAt, notes, _, pitchValue, pitchPoint in
                store.addEvent(
                    machineID: machine.id,
                    type: .pitchChecked,
                    category: .service,
                    occurredAt: occurredAt,
                    summary: "Check Pitch",
                    notes: notes,
                    pitchValue: pitchValue,
                    pitchMeasurementPoint: pitchPoint
                )
            }
        )
        .gameRoomEntrySheetStyle()
    }

    @ViewBuilder
    func levelMachineSheet() -> some View {
        GameRoomServiceEntrySheet(
            title: "Level Machine",
            submitLabel: "Save",
            includesConsumableField: false,
            includesPitchFields: false,
            onSave: { occurredAt, notes, _, _, _ in
                store.addEvent(
                    machineID: machine.id,
                    type: .machineLeveled,
                    category: .service,
                    occurredAt: occurredAt,
                    summary: "Level Machine",
                    notes: notes
                )
            }
        )
        .gameRoomEntrySheetStyle()
    }

    @ViewBuilder
    func generalInspectionSheet() -> some View {
        GameRoomServiceEntrySheet(
            title: "General Inspection",
            submitLabel: "Save",
            includesConsumableField: false,
            includesPitchFields: false,
            onSave: { occurredAt, notes, _, _, _ in
                store.addEvent(
                    machineID: machine.id,
                    type: .generalInspection,
                    category: .service,
                    occurredAt: occurredAt,
                    summary: "General Inspection",
                    notes: notes
                )
            }
        )
        .gameRoomEntrySheetStyle()
    }
}
