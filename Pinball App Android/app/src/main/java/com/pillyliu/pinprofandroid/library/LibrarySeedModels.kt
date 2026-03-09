package com.pillyliu.pinprofandroid.library

internal data class SeedManufacturer(
    val id: String,
    val name: String,
)

internal data class SeedMachine(
    val opdbMachineId: String,
    val practiceIdentity: String,
    val opdbGroupId: String?,
    val slug: String,
    val name: String,
    val variant: String?,
    val manufacturerId: String?,
    val manufacturerName: String?,
    val year: Int?,
    val primaryImageMediumUrl: String?,
    val primaryImageLargeUrl: String?,
    val playfieldMediumUrl: String?,
    val playfieldLargeUrl: String?,
)

internal data class SeedOverride(
    val practiceIdentity: String,
    val nameOverride: String?,
    val variantOverride: String?,
    val manufacturerOverride: String?,
    val yearOverride: Int?,
    val playfieldLocalPath: String?,
    val playfieldSourceUrl: String?,
    val gameinfoLocalPath: String?,
    val rulesheetLocalPath: String?,
)

internal data class SeedBuiltInGameRow(
    val libraryEntryId: String,
    val sourceId: String,
    val sourceName: String,
    val sourceType: LibrarySourceType,
    val practiceIdentity: String,
    val opdbId: String?,
    val area: String?,
    val areaOrder: Int?,
    val group: Int?,
    val position: Int?,
    val bank: Int?,
    val name: String,
    val variant: String?,
    val manufacturer: String?,
    val year: Int?,
    val slug: String,
    val primaryImageUrl: String?,
    val primaryImageLargeUrl: String?,
    val playfieldImageUrl: String?,
    val playfieldLocalPath: String?,
    val playfieldSourceLabel: String?,
    val gameinfoLocalPath: String?,
    val rulesheetLocalPath: String?,
    val rulesheetUrl: String?,
)

internal fun seedMachineHasPrimaryImage(machine: SeedMachine): Boolean =
    machine.primaryImageMediumUrl != null || machine.primaryImageLargeUrl != null

internal fun preferredSeedGroupMachine(group: List<SeedMachine>): SeedMachine? =
    group.minWithOrNull(
        ::compareSeedPreferredMachine,
    )

internal fun compareSeedPreferredMachine(lhs: SeedMachine, rhs: SeedMachine): Int {
    val lhsHasPrimary = seedMachineHasPrimaryImage(lhs)
    val rhsHasPrimary = seedMachineHasPrimaryImage(rhs)
    if (lhsHasPrimary != rhsHasPrimary) return if (lhsHasPrimary) -1 else 1

    val lhsVariant = normalizedOptionalString(lhs.variant)
    val rhsVariant = normalizedOptionalString(rhs.variant)
    if ((lhsVariant == null) != (rhsVariant == null)) return if (lhsVariant == null) -1 else 1

    val lhsYear = lhs.year ?: Int.MAX_VALUE
    val rhsYear = rhs.year ?: Int.MAX_VALUE
    if (lhsYear != rhsYear) return lhsYear.compareTo(rhsYear)

    val lhsName = lhs.name.lowercase()
    val rhsName = rhs.name.lowercase()
    if (lhsName != rhsName) return lhsName.compareTo(rhsName)

    return lhs.opdbMachineId.compareTo(rhs.opdbMachineId)
}

internal fun preferredSeedMachineForVariant(
    candidates: List<SeedMachine>,
    requestedVariant: String?,
): SeedMachine? {
    if (candidates.isEmpty()) return null
    val normalizedRequested = normalizedOptionalString(requestedVariant)
    val ranked = candidates.sortedWith { lhs, rhs ->
        val lhsScore = catalogVariantScore(lhs.variant, normalizedRequested)
        val rhsScore = catalogVariantScore(rhs.variant, normalizedRequested)
        when {
            lhsScore != rhsScore -> rhsScore.compareTo(lhsScore)
            else -> compareSeedPreferredMachine(lhs, rhs)
        }
    }
    val best = ranked.firstOrNull() ?: return null
    if (normalizedRequested != null) {
        val bestScore = catalogVariantScore(best.variant, normalizedRequested)
        if (bestScore <= 0) return null
    }
    return best
}

internal fun dedupeRulesheetLinks(links: List<ReferenceLink>): List<ReferenceLink> {
    val grouped = linkedMapOf<String, MutableList<ReferenceLink>>()
    links.forEach { link ->
        grouped.getOrPut(link.label) { mutableListOf() }.add(link)
    }
    return grouped.values.mapNotNull { group ->
        group.minWithOrNull(
            compareBy<ReferenceLink> { if (isCanonicalTiltForumsLink(it.url)) 0 else 1 }
                .thenBy { if (it.url?.startsWith("https://") == true) 0 else 1 }
                .thenBy { it.url ?: "" },
        )
    }
}

private fun isCanonicalTiltForumsLink(url: String?): Boolean {
    val normalized = url?.lowercase() ?: return false
    return normalized.contains("tiltforums.com/t/") && !normalized.contains(".json")
}

internal fun SeedManufacturer.toCatalogManufacturerRecord(): CatalogManufacturerRecord =
    CatalogManufacturerRecord(
        id = id,
        name = name,
        isModern = null,
        featuredRank = null,
        gameCount = null,
    )

internal fun SeedMachine.toCatalogMachineRecord(): CatalogMachineRecord =
    CatalogMachineRecord(
        practiceIdentity = practiceIdentity,
        opdbMachineId = opdbMachineId,
        opdbGroupId = opdbGroupId,
        slug = slug,
        name = name,
        variant = resolvedCatalogVariantLabel(title = name, explicitVariant = variant),
        manufacturerId = manufacturerId,
        manufacturerName = manufacturerName,
        year = year,
        primaryImageMediumUrl = primaryImageMediumUrl,
        primaryImageLargeUrl = primaryImageLargeUrl,
        playfieldImageMediumUrl = playfieldMediumUrl,
        playfieldImageLargeUrl = playfieldLargeUrl,
    )

internal fun SeedOverride.toLegacyCuratedOverride(
    rulesheetLinks: List<ReferenceLink>,
    videos: List<Video>,
): LegacyCuratedOverride =
    LegacyCuratedOverride(
        practiceIdentity = practiceIdentity,
        nameOverride = nameOverride,
        variantOverride = variantOverride,
        manufacturerOverride = manufacturerOverride,
        yearOverride = yearOverride,
        playfieldLocalPath = playfieldLocalPath,
        playfieldSourceUrl = playfieldSourceUrl,
        gameinfoLocalPath = gameinfoLocalPath,
        rulesheetLocalPath = rulesheetLocalPath,
        rulesheetLinks = rulesheetLinks,
        videos = videos,
    )

internal fun SeedBuiltInGameRow.toPinballGame(
    resolvedMachine: SeedMachine?,
    rulesheetLinks: List<ReferenceLink>,
    videos: List<Video>,
): PinballGame =
    PinballGame(
        libraryEntryId = libraryEntryId,
        practiceIdentity = practiceIdentity,
        opdbId = opdbId,
        opdbGroupId = practiceIdentity,
        variant = variant,
        sourceId = sourceId,
        sourceName = sourceName,
        sourceType = sourceType,
        area = area,
        areaOrder = areaOrder,
        group = group,
        position = position,
        bank = bank,
        name = name,
        manufacturer = manufacturer,
        year = year,
        slug = slug,
        primaryImageUrl = primaryImageUrl ?: resolvedMachine?.primaryImageMediumUrl,
        primaryImageLargeUrl = primaryImageLargeUrl ?: resolvedMachine?.primaryImageLargeUrl,
        playfieldImageUrl = playfieldImageUrl,
        playfieldLocalOriginal = normalizeLibraryCachePath(playfieldLocalPath),
        playfieldLocal = normalizeLibraryPlayfieldLocalPath(playfieldLocalPath),
        playfieldSourceLabel = playfieldSourceLabel,
        gameinfoLocal = gameinfoLocalPath,
        rulesheetLocal = rulesheetLocalPath,
        rulesheetUrl = rulesheetUrl,
        rulesheetLinks = rulesheetLinks,
        videos = videos,
    )

internal fun android.database.Cursor.getNullableString(index: Int): String? =
    if (isNull(index)) null else getString(index)?.trim()?.ifBlank { null }

internal fun android.database.Cursor.getIntOrNull(index: Int): Int? =
    if (isNull(index)) null else getInt(index)
