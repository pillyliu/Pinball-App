import SwiftUI

struct GameRoomMachineEditorFields: View {
    let selectedMachine: OwnedMachine
    let areas: [GameRoomArea]
    @Binding var draftAreaID: UUID?
    @Binding var draftStatus: OwnedMachineStatus
    @Binding var draftGroup: String
    @Binding var draftPosition: String
    @Binding var draftPurchaseSource: String
    @Binding var draftSerialNumber: String
    @Binding var draftOwnershipNotes: String
    let onSaveMachine: (OwnedMachine) -> Void
    let onDeleteMachine: (OwnedMachine) -> Void
    let onArchiveMachine: (OwnedMachine) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            areaAndStatusRow
            numericFields
            metadataFields
            actionRow
        }
    }

    private var areaAndStatusRow: some View {
        HStack(spacing: 10) {
            Menu {
                Button("No Area") {
                    draftAreaID = nil
                }

                if !areas.isEmpty {
                    Divider()
                }

                ForEach(areas) { area in
                    Button(area.name) {
                        draftAreaID = area.id
                    }
                }
            } label: {
                AppCompactIconMenuLabel(text: selectedAreaLabel, systemName: "map")
            }
            .buttonStyle(.plain)

            Picker("Status", selection: $draftStatus) {
                ForEach(OwnedMachineStatus.allCases) { status in
                    Text(status.rawValue.capitalized).tag(status)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var numericFields: some View {
        HStack(spacing: 10) {
            TextField("Group", text: $draftGroup)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)

            TextField("Position", text: $draftPosition)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
        }
    }

    private var metadataFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Purchase Source", text: $draftPurchaseSource)
                .textFieldStyle(.roundedBorder)
            TextField("Serial Number", text: $draftSerialNumber)
                .textFieldStyle(.roundedBorder)

            TextField("Ownership Notes", text: $draftOwnershipNotes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3, reservesSpace: true)
        }
    }

    private var actionRow: some View {
        HStack {
            Button("Save") {
                onSaveMachine(selectedMachine)
            }
            .buttonStyle(AppPrimaryActionButtonStyle())

            Button(role: .destructive) {
                onDeleteMachine(selectedMachine)
            } label: {
                Text("Delete")
            }
            .buttonStyle(AppDestructiveActionButtonStyle())

            Spacer()

            if selectedMachine.status != .archived {
                Button("Archive") {
                    onArchiveMachine(selectedMachine)
                }
                .buttonStyle(AppSecondaryActionButtonStyle())
            }
        }
    }

    private var selectedAreaLabel: String {
        guard let draftAreaID,
              let area = areas.first(where: { $0.id == draftAreaID }) else {
            return "No Area"
        }
        return area.name
    }
}
