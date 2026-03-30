import SwiftUI

struct GameRoomCollectionCard: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let gameTransition: Namespace.ID
    let selectedMachineID: UUID?
    let collectionLayout: GameRoomCollectionLayout
    let onChangeLayout: (GameRoomCollectionLayout) -> Void
    let onMachineTap: (OwnedMachine) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppCardTitle(text: "Collection")

                Spacer()

                Picker("Layout", selection: Binding(
                    get: { collectionLayout },
                    set: { onChangeLayout($0) }
                )) {
                    ForEach(GameRoomCollectionLayout.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .appSegmentedControlStyle()
                .frame(maxWidth: 160)
            }

            Text("Tracked active machines: \(store.activeMachines.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if store.activeMachines.isEmpty {
                AppPanelEmptyCard(text: "No active machines yet. Add one in GameRoom Settings > Edit.")
            } else if collectionLayout == .tiles {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(store.activeMachines) { machine in
                        GameRoomMiniCard(
                            machine: machine,
                            imageCandidates: catalogLoader.imageCandidates(for: machine),
                            transitionSourceID: gameRoomMachineTransitionSourceID(machineID: machine.id, surface: "home-card"),
                            transitionNamespace: gameTransition,
                            snapshot: store.snapshot(for: machine.id),
                            isSelected: machine.id == selectedMachineID,
                            onTap: { onMachineTap(machine) }
                        )
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(store.activeMachines) { machine in
                        GameRoomListRow(
                            machine: machine,
                            imageCandidates: catalogLoader.imageCandidates(for: machine),
                            transitionSourceID: gameRoomMachineTransitionSourceID(machineID: machine.id, surface: "home-list"),
                            transitionNamespace: gameTransition,
                            snapshot: store.snapshot(for: machine.id),
                            areaName: store.area(for: machine.gameRoomAreaID)?.name,
                            isSelected: machine.id == selectedMachineID,
                            onTap: { onMachineTap(machine) }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }
}
