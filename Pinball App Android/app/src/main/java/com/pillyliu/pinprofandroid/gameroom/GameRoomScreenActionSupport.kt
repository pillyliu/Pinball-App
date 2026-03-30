package com.pillyliu.pinprofandroid.gameroom

internal data class GameRoomImportFetchResult(
    val sourceURL: String,
    val rows: List<ImportDraftRow>,
)

internal suspend fun fetchGameRoomImportRows(
    input: String,
    pinsideImportService: GameRoomPinsideImportService,
    catalogLoader: GameRoomCatalogLoader,
): GameRoomImportFetchResult {
    val result = pinsideImportService.fetchCollectionMachines(input)
    return GameRoomImportFetchResult(
        sourceURL = result.sourceURL,
        rows = result.machines.map { machine -> makeImportDraftRow(machine, catalogLoader) },
    )
}

internal fun updateImportPurchaseDateRows(
    rows: List<ImportDraftRow>,
    rowID: String,
    updatedRaw: String,
): List<ImportDraftRow> {
    return rows.map { current ->
        if (current.id != rowID) {
            current
        } else {
            current.copy(
                rawPurchaseDateText = updatedRaw.ifBlank { null },
                normalizedPurchaseDateMs = normalizeFirstOfMonthMs(updatedRaw),
            )
        }
    }
}

internal fun updateImportMatchRows(
    rows: List<ImportDraftRow>,
    rowID: String,
    selectedCatalogGameID: String?,
    catalogLoader: GameRoomCatalogLoader,
): List<ImportDraftRow> {
    return rows.map { current ->
        if (current.id != rowID) {
            current
        } else {
            val updatedRow = current.copy(selectedCatalogGameID = selectedCatalogGameID)
            val availableVariants = importVariantOptions(updatedRow, catalogLoader)
            val keepVariant = current.selectedVariant?.takeIf { variant ->
                availableVariants.any { it.equals(variant, ignoreCase = true) }
            }
            updatedRow.copy(
                selectedCatalogGameID = selectedCatalogGameID,
                selectedVariant = keepVariant,
            )
        }
    }
}

internal fun updateImportVariantRows(
    rows: List<ImportDraftRow>,
    rowID: String,
    selectedVariant: String?,
): List<ImportDraftRow> {
    return rows.map { current ->
        if (current.id != rowID) {
            current
        } else {
            current.copy(selectedVariant = selectedVariant)
        }
    }
}

internal fun performGameRoomImport(
    rows: List<ImportDraftRow>,
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    importSourceURL: String,
    importSourceInput: String,
): String {
    var importedCount = 0
    var skippedDuplicates = 0
    var skippedUnmatched = 0
    rows.forEach { row ->
        val selectedCatalogID = row.selectedCatalogGameID
        val game = selectedCatalogID?.let { catalogLoader.game(it) }
        if (game == null) {
            skippedUnmatched += 1
            return@forEach
        }
        val resolvedVariant = row.selectedVariant ?: row.rawVariant
        if (store.hasImportFingerprint(row.fingerprint) || store.hasOwnedMachine(game.catalogGameID, resolvedVariant)) {
            skippedDuplicates += 1
            return@forEach
        }
        store.importOwnedMachine(
            game = game,
            sourceUserOrURL = importSourceURL.ifBlank { importSourceInput.trim() },
            sourceItemKey = row.sourceItemKey,
            rawTitle = row.rawTitle,
            rawVariant = resolvedVariant,
            rawPurchaseDateText = row.rawPurchaseDateText,
            normalizedPurchaseDateMs = row.normalizedPurchaseDateMs,
            matchConfidence = row.matchConfidence,
            fingerprint = row.fingerprint,
        )
        importedCount += 1
    }
    return "Imported $importedCount. Skipped $skippedDuplicates duplicates, $skippedUnmatched unmatched."
}

internal fun saveEditedGameRoomMachine(
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    machine: OwnedMachine,
    draftAreaID: String?,
    draftGroup: String,
    draftPosition: String,
    draftStatus: String,
    draftVariant: String,
    draftPurchaseSource: String,
    draftSerialNumber: String,
    draftOwnershipNotes: String,
    forceStatus: OwnedMachineStatus? = null,
) {
    val editedVariant = draftVariant.takeUnless { it == "None" }
    val resolvedGame = catalogLoader.game(machine.catalogGameID, editedVariant)
    store.updateMachine(
        id = machine.id,
        areaID = draftAreaID,
        groupNumber = draftGroup.toIntOrNull(),
        position = draftPosition.toIntOrNull(),
        status = forceStatus ?: runCatching { OwnedMachineStatus.valueOf(draftStatus) }.getOrDefault(OwnedMachineStatus.active),
        opdbID = resolvedGame?.opdbID ?: machine.opdbID,
        canonicalPracticeIdentity = resolvedGame?.canonicalPracticeIdentity,
        displayTitle = resolvedGame?.displayTitle,
        displayVariant = editedVariant ?: resolvedGame?.displayVariant,
        manufacturer = resolvedGame?.manufacturer,
        year = resolvedGame?.year,
        purchaseSource = draftPurchaseSource,
        serialNumber = draftSerialNumber,
        ownershipNotes = draftOwnershipNotes,
    )
}
