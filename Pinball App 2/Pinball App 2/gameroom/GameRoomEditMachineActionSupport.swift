import Foundation

struct GameRoomEditMachineSelectionState {
    let venueNameDraft: String
    let selectedMachineID: UUID?
}

struct GameRoomAreaDraftState {
    var selectedAreaID: UUID?
    var name: String
    var areaOrder: Int

    static let empty = GameRoomAreaDraftState(
        selectedAreaID: nil,
        name: "",
        areaOrder: 1
    )
}

struct GameRoomCatalogSearchIndexState {
    let entries: [GameRoomCatalogSearchEntry]
    let manufacturers: [String]
}

enum GameRoomAddMachineSelectionAction {
    case presentVariantPicker(GameRoomPendingVariantPicker)
    case complete(catalogGameID: String, variant: String?)
}

enum GameRoomAddMachineCompletionResult {
    case unresolved
    case duplicate(message: String)
    case added(selectedMachineID: UUID?)
}

func gameRoomSyncedEditMachineSelectionState(
    currentVenueNameDraft: String,
    venueName: String,
    allMachines: [OwnedMachine],
    selectedMachineID: UUID?
) -> GameRoomEditMachineSelectionState {
    GameRoomEditMachineSelectionState(
        venueNameDraft: gameRoomSyncedVenueNameDraft(
            currentDraft: currentVenueNameDraft,
            venueName: venueName
        ),
        selectedMachineID: gameRoomEnsuredSelectedMachineID(
            allMachines: allMachines,
            selectedMachineID: selectedMachineID
        )
    )
}

func gameRoomMachineEditDraft(for selectedMachine: OwnedMachine?) -> GameRoomMachineEditDraft {
    guard let selectedMachine else { return GameRoomMachineEditDraft() }
    var draft = GameRoomMachineEditDraft()
    draft.apply(selectedMachine)
    return draft
}

func gameRoomAreaDraftState(for area: GameRoomArea?) -> GameRoomAreaDraftState {
    guard let area else { return .empty }
    return GameRoomAreaDraftState(
        selectedAreaID: area.id,
        name: area.name,
        areaOrder: area.areaOrder
    )
}

func gameRoomCatalogSearchIndexState(
    games: [GameRoomCatalogGame],
    variantOptions: (String) -> [String]
) -> GameRoomCatalogSearchIndexState {
    let entries = buildGameRoomCatalogSearchEntries(
        games: games,
        variantOptions: variantOptions
    )
    return GameRoomCatalogSearchIndexState(
        entries: entries,
        manufacturers: gameRoomIndexedManufacturers(from: entries)
    )
}

func gameRoomAddMachineSelectionAction(
    for game: GameRoomCatalogGame,
    catalogLoader: GameRoomCatalogLoader
) -> GameRoomAddMachineSelectionAction {
    let distinctVariants = gameRoomDistinctVariants(
        catalogLoader.variantOptions(for: game.catalogGameID)
    )
    if distinctVariants.count > 1 {
        var picker = GameRoomPendingVariantPicker()
        picker.present(
            gameID: game.catalogGameID,
            title: game.displayTitle,
            options: distinctVariants
        )
        return .presentVariantPicker(picker)
    }

    return .complete(
        catalogGameID: game.catalogGameID,
        variant: distinctVariants.first
    )
}

func gameRoomCompleteAddMachineSelection(
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    catalogGameID: String?,
    variant: String?
) -> GameRoomAddMachineCompletionResult {
    guard let catalogGameID,
          let resolvedGame = catalogLoader.game(for: catalogGameID, variant: variant) else {
        return .unresolved
    }

    let resolvedVariant = gameRoomParsedOptionalString(variant) ?? resolvedGame.displayVariant
    if let existing = store.existingOwnedMachine(
        catalogGameID: resolvedGame.catalogGameID,
        displayVariant: resolvedVariant
    ) {
        let label = existing.displayVariant.map { "\(existing.displayTitle) (\($0))" } ?? existing.displayTitle
        return .duplicate(message: "\(label) is already in GameRoom")
    }

    store.addOwnedMachine(from: resolvedGame, displayVariant: resolvedVariant)
    return .added(selectedMachineID: store.state.ownedMachines.last?.id)
}

func gameRoomResolvedEditedMachine(
    machine: OwnedMachine,
    draft: GameRoomMachineEditDraft,
    catalogLoader: GameRoomCatalogLoader
) -> GameRoomCatalogGame? {
    let editedVariant = gameRoomParsedOptionalString(draft.displayVariant)
    return catalogLoader.game(for: machine.catalogGameID, variant: editedVariant)
}

func gameRoomPersistMachineEdits(
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    machine: OwnedMachine,
    draft: GameRoomMachineEditDraft,
    status: OwnedMachineStatus? = nil
) {
    let resolvedGame = gameRoomResolvedEditedMachine(
        machine: machine,
        draft: draft,
        catalogLoader: catalogLoader
    )

    store.updateMachine(
        id: machine.id,
        areaID: draft.areaID,
        groupNumber: gameRoomParsedOptionalInt(draft.group),
        position: gameRoomParsedOptionalInt(draft.position),
        status: status ?? draft.status,
        opdbID: resolvedGame?.opdbID ?? machine.opdbID,
        canonicalPracticeIdentity: resolvedGame?.canonicalPracticeIdentity,
        displayTitle: resolvedGame?.displayTitle,
        displayVariant: gameRoomParsedOptionalString(draft.displayVariant) ?? resolvedGame?.displayVariant,
        manufacturer: resolvedGame?.manufacturer,
        year: resolvedGame?.year,
        purchaseSource: draft.purchaseSource,
        serialNumber: draft.serialNumber,
        ownershipNotes: draft.ownershipNotes
    )
}
