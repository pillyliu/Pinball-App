package com.pillyliu.pinprofandroid.gameroom

internal data class GameRoomCatalogResolutionContext(
    val allCatalogGames: List<GameRoomCatalogGame>,
    val gamesByCatalogGameID: Map<String, List<GameRoomCatalogGame>>,
    val gamesByNormalizedCatalogGameID: Map<String, List<GameRoomCatalogGame>>,
    val machineRecordsByCatalogGameID: Map<String, List<GameRoomCatalogMachineRecord>>,
)

internal fun gameRoomCatalogGameForExactOpdbId(
    context: GameRoomCatalogResolutionContext,
    opdbID: String,
): GameRoomCatalogGame? {
    val normalized = normalizedCatalogGameID(opdbID)
    if (normalized.isBlank()) return null
    return context.allCatalogGames.firstOrNull { normalizedCatalogGameID(it.opdbID) == normalized }
}

internal fun resolvedGameRoomCatalogOpdbId(
    context: GameRoomCatalogResolutionContext,
    machine: OwnedMachine,
    groupedGames: List<GameRoomCatalogGame>,
): String? {
    machine.opdbID?.trim()?.takeIf { it.isNotBlank() }?.let { existing ->
        if (gameRoomCatalogGameForExactOpdbId(context, existing) != null) {
            return existing
        }
    }

    val parsedName = parseCatalogName(
        title = machine.displayTitle,
        explicitVariant = machine.displayVariant,
    )
    val normalizedTitle = parsedName.displayTitle.trim().lowercase()
    val normalizedVariant = normalizeVariantLabel(parsedName.displayVariant)

    if (normalizedVariant != null) {
        groupedGames.firstOrNull {
            it.displayTitle.trim().lowercase() == normalizedTitle &&
                normalizeVariantLabel(it.displayVariant) == normalizedVariant
        }?.let { return it.opdbID }
    }

    if (normalizedVariant != null) {
        groupedGames.firstOrNull {
            exactVariantMatchesSelection(it.displayVariant, normalizedVariant)
        }?.let { return it.opdbID }
    }

    if (normalizedVariant != null) {
        groupedGames.firstOrNull {
            variantMatchesSelection(it.displayVariant, normalizedVariant)
        }?.let { return it.opdbID }
    }

    groupedGames.firstOrNull {
        it.displayTitle.trim().lowercase() == normalizedTitle
    }?.let { return it.opdbID }

    context.allCatalogGames.firstOrNull {
        it.canonicalPracticeIdentity == machine.canonicalPracticeIdentity
    }?.let { return it.opdbID }

    return groupedGames.firstOrNull()?.opdbID
}

internal fun gameRoomCatalogImageCandidates(
    context: GameRoomCatalogResolutionContext,
    machine: OwnedMachine,
    resolvedOpdbId: String?,
): List<String> {
    val normalizedExactOPDBID = normalizedCatalogGameID(resolvedOpdbId.orEmpty())
    val grouped = context.gamesByCatalogGameID[machine.catalogGameID]
        ?: context.gamesByNormalizedCatalogGameID[normalizedCatalogGameID(machine.catalogGameID)]
        ?: emptyList()
    val rawCandidates = mutableListOf<String>()
    val normalizedVariant = normalizeVariantLabel(machine.displayVariant)
    val normalizedTitle = parseCatalogName(
        title = machine.displayTitle,
        explicitVariant = machine.displayVariant,
    ).displayTitle.trim().lowercase()

    if (normalizedExactOPDBID.isNotBlank()) {
        val exactMachineMatches = context.allCatalogGames.filter {
            normalizedCatalogGameID(it.opdbID) == normalizedExactOPDBID
        }
        rawCandidates.addAll(exactMachineMatches.mapNotNull { it.primaryImageUrl })
    }

    if (grouped.isEmpty() && rawCandidates.isEmpty()) return emptyList()

    if (normalizedVariant != null) {
        val exactVariantMatches = grouped.filter {
            exactVariantMatchesSelection(it.displayVariant, normalizedVariant)
        }
        rawCandidates.addAll(exactVariantMatches.mapNotNull { it.primaryImageUrl })
    }

    if (normalizedVariant != null) {
        val variantMatches = grouped.filter {
            variantMatchesSelection(it.displayVariant, normalizedVariant)
        }
        rawCandidates.addAll(variantMatches.mapNotNull { it.primaryImageUrl })
    }

    context.allCatalogGames.firstOrNull { it.canonicalPracticeIdentity == machine.canonicalPracticeIdentity }
        ?.primaryImageUrl
        ?.let(rawCandidates::add)

    rawCandidates.addAll(grouped.mapNotNull { it.primaryImageUrl })

    val titleMatches = context.allCatalogGames.filter { it.displayTitle.trim().lowercase() == normalizedTitle }
    rawCandidates.addAll(titleMatches.mapNotNull { it.primaryImageUrl })

    val seen = linkedSetOf<String>()
    return rawCandidates.mapNotNull(::resolveUrl)
        .filter { candidate -> seen.add(candidate.lowercase()) }
}

internal fun resolveGameRoomCatalogArt(
    context: GameRoomCatalogResolutionContext,
    catalogGameID: String,
    opdbID: String?,
    selectedVariant: String?,
    selectedTitle: String?,
    selectedYear: Int?,
): GameRoomCatalogArt? {
    val normalizedExactOPDBID = opdbID?.trim().orEmpty()
    val exactRecords = if (normalizedExactOPDBID.isBlank()) {
        emptyList()
    } else {
        context.machineRecordsByCatalogGameID.values
            .flatten()
            .filter { it.opdbID.equals(normalizedExactOPDBID, ignoreCase = true) }
    }
    val normalizedID = catalogGameID.trim()
    if (normalizedID.isBlank() && exactRecords.isEmpty()) return null
    val records = if (exactRecords.isNotEmpty()) {
        exactRecords
    } else {
        context.machineRecordsByCatalogGameID[normalizedID]
            ?: context.machineRecordsByCatalogGameID.entries.firstOrNull { (key, _) ->
                key.equals(normalizedID, ignoreCase = true)
            }?.value
            ?: emptyList()
    }
    if (records.isEmpty()) return null
    val variantRanked = records.sortedWith { lhs, rhs ->
        val lhsScore = machineContextScore(lhs, selectedVariant, selectedTitle, selectedYear)
        val rhsScore = machineContextScore(rhs, selectedVariant, selectedTitle, selectedYear)
        when {
            lhsScore != rhsScore -> rhsScore.compareTo(lhsScore)
            else -> compareCatalogRecords(lhs, rhs)
        }
    }
    val strictVariantMatch = variantRanked.firstOrNull {
        machineContextScore(it, selectedVariant, selectedTitle, selectedYear) > 0 && hasPrimaryArt(it)
    }
    val preferred = strictVariantMatch
        ?: records.filter(::hasPrimaryArt).minWithOrNull(::compareCatalogRecords)
        ?: variantRanked.first()
    return GameRoomCatalogArt(
        primaryImageUrl = preferred.primaryImageUrl,
        primaryImageLargeUrl = preferred.primaryImageLargeUrl,
        playfieldImageUrl = preferred.playfieldImageUrl,
        playfieldImageLargeUrl = preferred.playfieldImageLargeUrl,
    )
}
