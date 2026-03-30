import Foundation

extension GameRoomStore {
    func hasImportFingerprint(_ fingerprint: String) -> Bool {
        let normalized = fingerprint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return state.importRecords.contains {
            $0.fingerprint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
    }

    func hasOwnedMachine(catalogGameID: String, displayVariant: String?) -> Bool {
        existingOwnedMachine(catalogGameID: catalogGameID, displayVariant: displayVariant) != nil
    }

    func existingOwnedMachine(catalogGameID: String, displayVariant: String?) -> OwnedMachine? {
        let normalizedCatalogID = catalogGameID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedCatalogID.isEmpty else { return nil }
        let normalizedVariant = normalizedOptionalString(displayVariant)?.lowercased()
        return state.ownedMachines.first { machine in
            guard machine.catalogGameID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedCatalogID else {
                return false
            }
            let machineVariant = normalizedOptionalString(machine.displayVariant)?.lowercased()
            return machineVariant == normalizedVariant
        }
    }

    @discardableResult
    func importOwnedMachine(
        game: GameRoomCatalogGame,
        sourceUserOrURL: String,
        sourceItemKey: String?,
        rawTitle: String,
        rawVariant: String?,
        rawPurchaseDateText: String?,
        normalizedPurchaseDate: Date?,
        matchConfidence: MachineImportMatchConfidence,
        fingerprint: String?
    ) -> UUID {
        let now = Date()
        let machine = OwnedMachine(
            catalogGameID: game.catalogGameID,
            opdbID: game.opdbID,
            canonicalPracticeIdentity: game.canonicalPracticeIdentity,
            displayTitle: game.displayTitle,
            displayVariant: normalizedOptionalString(rawVariant) ?? game.displayVariant,
            importedSourceTitle: normalizedOptionalString(rawTitle),
            manufacturer: game.manufacturer,
            year: game.year,
            purchaseDate: normalizedPurchaseDate,
            purchaseDateRawText: normalizedOptionalString(rawPurchaseDateText),
            createdAt: now,
            updatedAt: now
        )
        state.ownedMachines.append(machine)

        let importRecord = MachineImportRecord(
            source: .pinside,
            sourceUserOrURL: sourceUserOrURL,
            sourceItemKey: normalizedOptionalString(sourceItemKey),
            rawTitle: normalizedOptionalString(rawTitle) ?? game.displayTitle,
            rawVariant: normalizedOptionalString(rawVariant),
            rawPurchaseDateText: normalizedOptionalString(rawPurchaseDateText),
            normalizedPurchaseDate: normalizedPurchaseDate,
            matchedCatalogGameID: game.catalogGameID,
            matchConfidence: matchConfidence,
            createdOwnedMachineID: machine.id,
            importedAt: now,
            fingerprint: normalizedOptionalString(fingerprint)
        )
        state.importRecords.append(importRecord)
        saveAndRecompute()
        return machine.id
    }

    func migrateOwnedMachineOPDBIDs(using catalogLoader: GameRoomCatalogLoader) {
        var didChange = false
        for index in state.ownedMachines.indices {
            guard let normalizedGame = catalogLoader.normalizedCatalogGame(for: state.ownedMachines[index]) else {
                continue
            }
            let normalizedOPDBID = normalizedGame.opdbID.trimmingCharacters(in: .whitespacesAndNewlines)
            let currentOPDBID = state.ownedMachines[index].opdbID?.trimmingCharacters(in: .whitespacesAndNewlines)
            let currentTitle = state.ownedMachines[index].displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let currentVariant = state.ownedMachines[index].displayVariant?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedTitle = normalizedGame.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedVariant = normalizedOptionalString(normalizedGame.displayVariant)

            guard currentOPDBID != normalizedOPDBID ||
                    currentTitle != normalizedTitle ||
                    currentVariant != normalizedVariant else {
                continue
            }

            state.ownedMachines[index].opdbID = normalizedOPDBID
            state.ownedMachines[index].displayTitle = normalizedTitle
            state.ownedMachines[index].displayVariant = normalizedVariant
            state.ownedMachines[index].updatedAt = Date()
            didChange = true
        }
        if didChange {
            saveAndRecompute()
        }
    }
}
