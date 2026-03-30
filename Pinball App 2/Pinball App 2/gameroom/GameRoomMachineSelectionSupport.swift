import SwiftUI

struct GameRoomMachineMenuGroup: Identifiable {
    var id: String { key }
    let key: String
    let title: String
    let machines: [OwnedMachine]
}

struct GameRoomMachineSelectionRow: View {
    let machineMenuGroups: [GameRoomMachineMenuGroup]
    let selectedMachineTitle: String
    let currentVariantLabel: String
    let variantOptions: [String]
    let machineMenuLabel: (OwnedMachine) -> String
    let onSelectMachine: (UUID) -> Void
    let onClearVariant: () -> Void
    let onSelectVariant: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(machineMenuGroups) { group in
                    Section(group.title) {
                        ForEach(group.machines) { machine in
                            Button(machineMenuLabel(machine)) {
                                onSelectMachine(machine.id)
                            }
                        }
                    }
                }
            } label: {
                AppCompactDropdownLabel(text: selectedMachineTitle)
            }
            .buttonStyle(.plain)

            Spacer()

            Menu {
                Button("None") {
                    onClearVariant()
                }

                if !variantOptions.isEmpty {
                    Divider()
                    ForEach(variantOptions, id: \.self) { variant in
                        Button(variant) {
                            onSelectVariant(variant)
                        }
                    }
                }
            } label: {
                GameRoomVariantPill(label: currentVariantLabel, style: .editSelector)
            }
        }
        .padding(.bottom, 2)
    }
}
