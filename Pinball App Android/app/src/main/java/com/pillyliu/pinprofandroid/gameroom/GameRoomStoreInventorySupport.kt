package com.pillyliu.pinprofandroid.gameroom

internal data class GameRoomOwnedMachineMutationResult(
    val state: GameRoomPersistedState,
    val machineId: String,
)

internal fun activeGameRoomMachines(state: GameRoomPersistedState): List<OwnedMachine> {
    val areasById = state.areas.associateBy { it.id }
    return state.ownedMachines
        .filter { it.status.countsAsActiveInventory }
        .sortedWith { lhs, rhs -> compareGameRoomMachines(lhs, rhs, areasById) }
}

internal fun archivedGameRoomMachines(state: GameRoomPersistedState): List<OwnedMachine> {
    val areasById = state.areas.associateBy { it.id }
    return state.ownedMachines
        .filterNot { it.status.countsAsActiveInventory }
        .sortedWith { lhs, rhs -> compareGameRoomMachines(lhs, rhs, areasById) }
}

internal fun defaultOwnedMachineSnapshot(machineID: String): OwnedMachineSnapshot {
    return OwnedMachineSnapshot(
        ownedMachineID = machineID,
        currentPlayCount = 0,
        lastGlassCleanedAtMs = null,
        lastPlayfieldCleanedAtMs = null,
        lastPlayfieldCleanerUsed = null,
        lastBallsServicedAtMs = null,
        lastBallsReplacedAtMs = null,
        currentBallSetNotes = null,
        lastPitchCheckedAtMs = null,
        currentPitchValue = null,
        currentPitchMeasurementPoint = null,
        lastLeveledAtMs = null,
        lastRubberServiceAtMs = null,
        lastFlipperServiceAtMs = null,
        lastGeneralInspectionAtMs = null,
        lastServiceAtMs = null,
        openIssueCount = 0,
        dueTaskCount = 0,
        attentionState = GameRoomAttentionState.gray,
    )
}

internal fun gameRoomStateWithAddedOwnedMachine(
    state: GameRoomPersistedState,
    catalogGameID: String,
    opdbID: String?,
    canonicalPracticeIdentity: String,
    displayTitle: String,
    displayVariant: String?,
    manufacturer: String?,
    year: Int?,
    now: Long,
): GameRoomOwnedMachineMutationResult {
    val machine = OwnedMachine(
        catalogGameID = catalogGameID.trim(),
        opdbID = normalizeOptionalGameRoomString(opdbID),
        canonicalPracticeIdentity = canonicalPracticeIdentity.trim(),
        displayTitle = displayTitle.trim().ifBlank { "Machine" },
        displayVariant = normalizeOptionalGameRoomString(displayVariant),
        manufacturer = normalizeOptionalGameRoomString(manufacturer),
        year = year,
        createdAtMs = now,
        updatedAtMs = now,
    )
    return GameRoomOwnedMachineMutationResult(
        state = state.copy(ownedMachines = state.ownedMachines + machine),
        machineId = machine.id,
    )
}

internal fun gameRoomStateWithUpdatedMachine(
    state: GameRoomPersistedState,
    id: String,
    areaID: String?,
    groupNumber: Int?,
    position: Int?,
    status: OwnedMachineStatus,
    opdbID: String?,
    canonicalPracticeIdentity: String?,
    displayTitle: String?,
    displayVariant: String?,
    manufacturer: String?,
    year: Int?,
    purchaseSource: String?,
    serialNumber: String?,
    ownershipNotes: String?,
    now: Long,
): GameRoomPersistedState {
    return state.copy(
        ownedMachines = state.ownedMachines.map { machine ->
            if (machine.id != id) return@map machine
            machine.copy(
                gameRoomAreaID = normalizeOptionalGameRoomString(areaID),
                groupNumber = groupNumber,
                position = position,
                status = status,
                opdbID = normalizeOptionalGameRoomString(opdbID),
                canonicalPracticeIdentity = normalizeOptionalGameRoomString(canonicalPracticeIdentity) ?: machine.canonicalPracticeIdentity,
                displayTitle = normalizeOptionalGameRoomString(displayTitle) ?: machine.displayTitle,
                displayVariant = normalizeOptionalGameRoomString(displayVariant),
                manufacturer = normalizeOptionalGameRoomString(manufacturer) ?: machine.manufacturer,
                year = year ?: machine.year,
                purchaseSource = normalizeOptionalGameRoomString(purchaseSource),
                serialNumber = normalizeOptionalGameRoomString(serialNumber),
                ownershipNotes = normalizeOptionalGameRoomString(ownershipNotes),
                updatedAtMs = now,
            )
        },
    )
}

internal fun gameRoomStateWithDeletedMachine(
    state: GameRoomPersistedState,
    id: String,
): GameRoomPersistedState {
    return state.copy(
        ownedMachines = state.ownedMachines.filterNot { it.id == id },
        events = state.events.filterNot { it.ownedMachineID == id },
        issues = state.issues.filterNot { it.ownedMachineID == id },
        attachments = state.attachments.filterNot { it.ownedMachineID == id },
        reminderConfigs = state.reminderConfigs.filterNot { it.ownedMachineID == id },
        importRecords = state.importRecords.filterNot { it.createdOwnedMachineID == id },
    )
}

internal fun gameRoomStateHasImportFingerprint(
    state: GameRoomPersistedState,
    fingerprint: String,
): Boolean {
    val normalizedFingerprint = fingerprint.trim().lowercase()
    if (normalizedFingerprint.isBlank()) return false
    return state.importRecords.any { record ->
        record.fingerprint?.trim()?.lowercase() == normalizedFingerprint
    }
}

internal fun gameRoomStateExistingOwnedMachine(
    state: GameRoomPersistedState,
    catalogGameID: String,
    displayVariant: String?,
): OwnedMachine? {
    val normalizedCatalogID = catalogGameID.trim().lowercase()
    if (normalizedCatalogID.isBlank()) return null
    val normalizedVariant = normalizeGameRoomVariantKey(displayVariant)
    return state.ownedMachines.firstOrNull { machine ->
        machine.catalogGameID.trim().lowercase() == normalizedCatalogID &&
            normalizeGameRoomVariantKey(machine.displayVariant) == normalizedVariant
    }
}

internal fun gameRoomStateWithImportedMachine(
    state: GameRoomPersistedState,
    game: GameRoomCatalogGame,
    sourceUserOrURL: String,
    sourceItemKey: String?,
    rawTitle: String,
    rawVariant: String?,
    rawPurchaseDateText: String?,
    normalizedPurchaseDateMs: Long?,
    matchConfidence: MachineImportMatchConfidence,
    fingerprint: String?,
    now: Long,
): GameRoomOwnedMachineMutationResult {
    val machine = OwnedMachine(
        catalogGameID = game.catalogGameID,
        opdbID = game.opdbID,
        canonicalPracticeIdentity = game.canonicalPracticeIdentity,
        displayTitle = game.displayTitle,
        displayVariant = normalizeOptionalGameRoomString(rawVariant),
        importedSourceTitle = rawTitle.trim().ifBlank { null },
        manufacturer = game.manufacturer,
        year = game.year,
        purchaseDateMs = normalizedPurchaseDateMs,
        purchaseDateRawText = normalizeOptionalGameRoomString(rawPurchaseDateText),
        status = OwnedMachineStatus.active,
        createdAtMs = now,
        updatedAtMs = now,
    )
    val importRecord = MachineImportRecord(
        source = MachineImportSource.pinside,
        sourceUserOrURL = sourceUserOrURL.trim().ifBlank { "pinside" },
        sourceItemKey = normalizeOptionalGameRoomString(sourceItemKey),
        rawTitle = rawTitle.trim().ifBlank { game.displayTitle },
        rawVariant = normalizeOptionalGameRoomString(rawVariant),
        rawPurchaseDateText = normalizeOptionalGameRoomString(rawPurchaseDateText),
        normalizedPurchaseDateMs = normalizedPurchaseDateMs,
        matchedCatalogGameID = game.catalogGameID,
        matchConfidence = matchConfidence,
        createdOwnedMachineID = machine.id,
        importedAtMs = now,
        fingerprint = normalizeOptionalGameRoomString(fingerprint),
    )
    return GameRoomOwnedMachineMutationResult(
        state = state.copy(
            ownedMachines = state.ownedMachines + machine,
            importRecords = state.importRecords + importRecord,
        ),
        machineId = machine.id,
    )
}

internal fun migratedGameRoomOwnedMachines(
    state: GameRoomPersistedState,
    catalogLoader: GameRoomCatalogLoader,
    now: Long,
): List<OwnedMachine>? {
    var didChange = false
    val migratedMachines = state.ownedMachines.map { machine ->
        val normalizedGame = catalogLoader.normalizedCatalogGame(machine)
        if (normalizedGame == null) {
            machine
        } else {
            val normalizedOPDBID = normalizeOptionalGameRoomString(normalizedGame.opdbID)
            val normalizedTitle = normalizedGame.displayTitle.trim().ifBlank { "Machine" }
            val normalizedVariant = normalizeOptionalGameRoomString(normalizedGame.displayVariant)
            val currentOPDBID = normalizeOptionalGameRoomString(machine.opdbID)
            val currentTitle = machine.displayTitle.trim()
            val currentVariant = normalizeOptionalGameRoomString(machine.displayVariant)
            if (
                normalizedOPDBID == currentOPDBID &&
                normalizedTitle == currentTitle &&
                normalizedVariant == currentVariant
            ) {
                machine
            } else {
                didChange = true
                machine.copy(
                    opdbID = normalizedOPDBID,
                    displayTitle = normalizedTitle,
                    displayVariant = normalizedVariant,
                    updatedAtMs = now,
                )
            }
        }
    }
    return migratedMachines.takeIf { didChange }
}

internal fun gameRoomStateWithUpsertedArea(
    state: GameRoomPersistedState,
    id: String?,
    name: String,
    areaOrder: Int,
    now: Long,
): GameRoomPersistedState {
    val normalizedName = name.trim().ifBlank { "Area" }
    val normalizedOrder = areaOrder.coerceAtLeast(1)
    val existing = state.areas.toMutableList()
    val explicitIndex = id?.let { explicitID ->
        existing.indexOfFirst { it.id == explicitID }
    } ?: -1
    when {
        explicitIndex >= 0 -> {
            existing[explicitIndex] = existing[explicitIndex].copy(
                name = normalizedName,
                areaOrder = normalizedOrder,
                updatedAtMs = now,
            )
        }

        else -> {
            val sameNameIndex = existing.indexOfFirst { it.name.equals(normalizedName, ignoreCase = true) }
            if (sameNameIndex >= 0) {
                existing[sameNameIndex] = existing[sameNameIndex].copy(
                    name = normalizedName,
                    areaOrder = normalizedOrder,
                    updatedAtMs = now,
                )
            } else {
                existing += GameRoomArea(
                    name = normalizedName,
                    areaOrder = normalizedOrder,
                    createdAtMs = now,
                    updatedAtMs = now,
                )
            }
        }
    }
    return state.copy(
        areas = existing.sortedWith(compareBy<GameRoomArea> { it.areaOrder }.thenBy { it.name.lowercase() }),
    )
}

internal fun gameRoomStateWithDeletedArea(
    state: GameRoomPersistedState,
    id: String,
    now: Long,
): GameRoomPersistedState {
    val nextMachines = state.ownedMachines.map { machine ->
        if (machine.gameRoomAreaID != id) return@map machine
        machine.copy(gameRoomAreaID = null, updatedAtMs = now)
    }
    return state.copy(
        areas = state.areas.filterNot { it.id == id },
        ownedMachines = nextMachines,
    )
}

internal fun normalizedGameRoomVenueName(rawName: String): String {
    val trimmed = rawName.trim()
    return if (trimmed.isBlank()) GameRoomPersistedState.DEFAULT_VENUE_NAME else trimmed
}

internal fun normalizeGameRoomVariantKey(value: String?): String {
    return value?.trim()?.lowercase().orEmpty()
}

internal fun normalizeOptionalGameRoomString(value: String?): String? {
    return value?.trim()?.ifBlank { null }
}
