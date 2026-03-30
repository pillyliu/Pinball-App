import SwiftUI

enum GameRoomCollectionLayout: String, CaseIterable, Identifiable {
    case tiles
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiles: return "Cards"
        case .list: return "List"
        }
    }
}

struct GameRoomHomeView: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let gameTransition: Namespace.ID
    let onOpenSettings: () -> Void
    let onOpenMachineView: (UUID, String?, String) -> Void
    @State private var selectedMachineID: UUID?
    @State private var collectionLayout: GameRoomCollectionLayout = .tiles

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(store.venueName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.brandInk)
                        .lineLimit(1)

                    Spacer()

                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(AppCompactIconActionButtonStyle())
                }
                .padding(.leading, 8)

                if let lastErrorMessage = store.lastErrorMessage, !lastErrorMessage.isEmpty {
                    AppInlineTaskStatus(text: lastErrorMessage, isError: true)
                }

                GameRoomSelectedSummaryCard(
                    store: store,
                    selectedMachine: selectedMachine
                )
                GameRoomCollectionCard(
                    store: store,
                    catalogLoader: catalogLoader,
                    gameTransition: gameTransition,
                    selectedMachineID: selectedMachineID,
                    collectionLayout: collectionLayout,
                    onChangeLayout: { collectionLayout = $0 },
                    onMachineTap: handleMachineTap
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            seedSelectionIfNeeded()
        }
        .onChange(of: store.activeMachines.map(\.id)) { _, _ in
            seedSelectionIfNeeded()
        }
    }

    private var selectedMachine: OwnedMachine? {
        gameRoomSelectedHomeMachine(
            activeMachines: store.activeMachines,
            selectedMachineID: selectedMachineID
        )
    }

    private func seedSelectionIfNeeded() {
        selectedMachineID = gameRoomSyncedHomeSelectionID(
            activeMachines: store.activeMachines,
            selectedMachineID: selectedMachineID
        )
    }

    private func handleMachineTap(_ machine: OwnedMachine) {
        let sourceID = gameRoomHomeTransitionSourceID(
            machineID: machine.id,
            layout: collectionLayout
        )
        if selectedMachineID == machine.id {
            onOpenMachineView(machine.id, sourceID, machine.displayTitle)
            return
        }
        selectedMachineID = machine.id
    }
}
