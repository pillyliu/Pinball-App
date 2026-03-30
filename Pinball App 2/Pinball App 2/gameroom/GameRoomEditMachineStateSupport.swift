import Foundation

struct GameRoomAddMachineFilters {
    var searchText = ""
    var manufacturerQuery = ""
    var yearQuery = ""
    var selectedType: GameRoomAddMachineTypeFilter?
    var isAdvancedExpanded = false

    mutating func clear() {
        searchText = ""
        manufacturerQuery = ""
        yearQuery = ""
        selectedType = nil
    }
}

struct GameRoomMachineEditDraft {
    var areaID: UUID?
    var group = ""
    var position = ""
    var status: OwnedMachineStatus = .active
    var displayVariant = ""
    var purchaseSource = ""
    var serialNumber = ""
    var ownershipNotes = ""

    var currentVariantLabel: String {
        gameRoomCurrentVariantLabel(displayVariant)
    }

    mutating func apply(_ machine: OwnedMachine) {
        areaID = machine.gameRoomAreaID
        group = machine.groupNumber.map(String.init) ?? ""
        position = machine.position.map(String.init) ?? ""
        status = machine.status
        displayVariant = machine.displayVariant ?? ""
        purchaseSource = machine.purchaseSource ?? ""
        serialNumber = machine.serialNumber ?? ""
        ownershipNotes = machine.ownershipNotes ?? ""
    }

    mutating func clear() {
        areaID = nil
        group = ""
        position = ""
        status = .active
        displayVariant = ""
        purchaseSource = ""
        serialNumber = ""
        ownershipNotes = ""
    }
}

struct GameRoomEditMachinePanelExpansionState {
    var isNameExpanded = false
    var isAddMachineExpanded = false
    var isAreasExpanded = false
    var isEditMachinesExpanded = false
}

struct GameRoomEditMachinesViewState {
    var addMachineFilters = GameRoomAddMachineFilters()
    var selectedMachineID: UUID?
    var areaDraft = GameRoomAreaDraftState.empty
    var machineDraft = GameRoomMachineEditDraft()
    var venueNameDraft = ""
    var panelExpansion = GameRoomEditMachinePanelExpansionState()
    var pendingVariantPicker = GameRoomPendingVariantPicker()
    var indexedCatalogSearchEntries: [GameRoomCatalogSearchEntry] = []
    var indexedManufacturers: [String] = []
}

struct GameRoomPendingVariantPicker {
    var gameID: String?
    var title = ""
    var options: [String] = []

    mutating func present(gameID: String, title: String, options: [String]) {
        self.gameID = gameID
        self.title = title
        self.options = options
    }

    mutating func clear() {
        gameID = nil
        title = ""
        options = []
    }
}
