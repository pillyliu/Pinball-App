import Foundation

extension GameRoomStore {
    func area(for id: UUID?) -> GameRoomArea? {
        guard let id else { return nil }
        return state.areas.first(where: { $0.id == id })
    }

    func addOwnedMachine(from game: GameRoomCatalogGame, displayVariant: String? = nil) {
        let machine = OwnedMachine(
            catalogGameID: game.catalogGameID,
            opdbID: game.opdbID,
            canonicalPracticeIdentity: game.canonicalPracticeIdentity,
            displayTitle: game.displayTitle,
            displayVariant: normalizedOptionalString(displayVariant) ?? game.displayVariant,
            manufacturer: game.manufacturer,
            year: game.year
        )
        state.ownedMachines.append(machine)
        saveAndRecompute()
    }

    func updateMachine(
        id: UUID,
        areaID: UUID?,
        groupNumber: Int?,
        position: Int?,
        status: OwnedMachineStatus,
        opdbID: String?,
        canonicalPracticeIdentity: String? = nil,
        displayTitle: String? = nil,
        displayVariant: String?,
        manufacturer: String? = nil,
        year: Int? = nil,
        purchaseSource: String?,
        serialNumber: String?,
        ownershipNotes: String?
    ) {
        guard let index = state.ownedMachines.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        state.ownedMachines[index].gameRoomAreaID = areaID
        state.ownedMachines[index].groupNumber = groupNumber
        state.ownedMachines[index].position = position
        state.ownedMachines[index].status = status
        state.ownedMachines[index].opdbID = normalizedOptionalString(opdbID)
        if let canonicalPracticeIdentity = normalizedOptionalString(canonicalPracticeIdentity) {
            state.ownedMachines[index].canonicalPracticeIdentity = canonicalPracticeIdentity
        }
        if let displayTitle = normalizedOptionalString(displayTitle) {
            state.ownedMachines[index].displayTitle = displayTitle
        }
        state.ownedMachines[index].displayVariant = normalizedOptionalString(displayVariant)
        if let manufacturer = normalizedOptionalString(manufacturer) {
            state.ownedMachines[index].manufacturer = manufacturer
        }
        if let year {
            state.ownedMachines[index].year = year
        }
        state.ownedMachines[index].purchaseSource = normalizedOptionalString(purchaseSource)
        state.ownedMachines[index].serialNumber = normalizedOptionalString(serialNumber)
        state.ownedMachines[index].ownershipNotes = normalizedOptionalString(ownershipNotes)
        state.ownedMachines[index].updatedAt = now
        saveAndRecompute()
    }

    func deleteMachine(id: UUID) {
        state.ownedMachines.removeAll { $0.id == id }
        state.events.removeAll { $0.ownedMachineID == id }
        state.issues.removeAll { $0.ownedMachineID == id }
        state.attachments.removeAll { $0.ownedMachineID == id }
        state.reminderConfigs.removeAll { $0.ownedMachineID == id }
        state.importRecords.removeAll { $0.createdOwnedMachineID == id }
        saveAndRecompute()
    }

    func upsertArea(id: UUID? = nil, name: String, areaOrder: Int) {
        let normalizedName = normalizedOptionalString(name) ?? "Area"
        let normalizedOrder = max(1, areaOrder)
        let now = Date()

        if let id, let index = state.areas.firstIndex(where: { $0.id == id }) {
            state.areas[index].name = normalizedName
            state.areas[index].areaOrder = normalizedOrder
            state.areas[index].updatedAt = now
        } else if let index = state.areas.firstIndex(where: { $0.name.caseInsensitiveCompare(normalizedName) == .orderedSame }) {
            state.areas[index].name = normalizedName
            state.areas[index].areaOrder = normalizedOrder
            state.areas[index].updatedAt = now
        } else {
            state.areas.append(
                GameRoomArea(
                    name: normalizedName,
                    areaOrder: normalizedOrder,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        state.areas.sort {
            if $0.areaOrder != $1.areaOrder { return $0.areaOrder < $1.areaOrder }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        saveAndRecompute()
    }

    func deleteArea(id: UUID) {
        state.areas.removeAll { $0.id == id }
        for index in state.ownedMachines.indices where state.ownedMachines[index].gameRoomAreaID == id {
            state.ownedMachines[index].gameRoomAreaID = nil
            state.ownedMachines[index].updatedAt = Date()
        }
        saveAndRecompute()
    }

    func updateVenueName(_ rawName: String) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        state.venueName = trimmed.isEmpty ? GameRoomPersistedState.defaultVenueName : trimmed
        saveAndRecompute()
    }
}
