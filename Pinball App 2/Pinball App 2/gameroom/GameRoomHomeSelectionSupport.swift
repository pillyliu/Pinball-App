import Foundation

func gameRoomSelectedHomeMachine(
    activeMachines: [OwnedMachine],
    selectedMachineID: UUID?
) -> OwnedMachine? {
    guard let selectedMachineID else { return activeMachines.first }
    return activeMachines.first(where: { $0.id == selectedMachineID }) ?? activeMachines.first
}

func gameRoomSyncedHomeSelectionID(
    activeMachines: [OwnedMachine],
    selectedMachineID: UUID?
) -> UUID? {
    guard !activeMachines.isEmpty else { return nil }
    guard let selectedMachineID,
          activeMachines.contains(where: { $0.id == selectedMachineID }) else {
        return activeMachines.first?.id
    }
    return selectedMachineID
}

func gameRoomHomeTransitionSourceID(
    machineID: UUID,
    layout: GameRoomCollectionLayout
) -> String {
    gameRoomMachineTransitionSourceID(
        machineID: machineID,
        surface: layout == .tiles ? "home-card" : "home-list"
    )
}
