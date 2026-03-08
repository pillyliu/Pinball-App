package com.pillyliu.pinprofandroid.library

internal fun resolveImportedGame(
    machine: CatalogMachineRecord,
    source: ImportedSourceRecord,
    manufacturerById: Map<String, CatalogManufacturerRecord>,
    curatedOverride: LegacyCuratedOverride?,
    opdbRulesheets: List<CatalogRulesheetLinkRecord>,
    opdbVideos: List<CatalogVideoLinkRecord>,
): PinballGame {
    val manufacturerName = curatedOverride?.manufacturerOverride
        ?: machine.manufacturerName
        ?: machine.manufacturerId?.let { manufacturerById[it]?.name }
    val resolvedRulesheet = if (!curatedOverride?.rulesheetLocalPath.isNullOrBlank()) {
        normalizedOptionalString(curatedOverride?.rulesheetLocalPath) to emptyList()
    } else if (!curatedOverride?.rulesheetLinks.isNullOrEmpty()) {
        null to curatedOverride!!.rulesheetLinks
    } else {
        val resolved = resolveRulesheetLinks(opdbRulesheets)
        resolved.localPath to resolved.links
    }
    val resolvedVideos = if (!curatedOverride?.videos.isNullOrEmpty()) curatedOverride!!.videos else resolveVideoLinks(opdbVideos)
    val playfieldLocalPath = curatedOverride?.playfieldLocalPath
    val playfieldSourceUrl = curatedOverride?.playfieldSourceUrl
        ?: normalizedOptionalString(machine.playfieldImageLargeUrl ?: machine.playfieldImageMediumUrl)
    return PinballGame(
        libraryEntryId = "${source.id}:${machine.practiceIdentity}",
        practiceIdentity = machine.practiceIdentity,
        opdbId = machine.opdbMachineId,
        opdbGroupId = machine.opdbGroupId,
        variant = if (source.type == LibrarySourceType.MANUFACTURER) null else (curatedOverride?.variantOverride ?: normalizedOptionalString(machine.variant)),
        sourceId = source.id,
        sourceName = source.name,
        sourceType = source.type,
        area = null,
        areaOrder = null,
        group = null,
        position = null,
        bank = null,
        name = curatedOverride?.nameOverride ?: machine.name,
        manufacturer = normalizedOptionalString(manufacturerName),
        year = curatedOverride?.yearOverride ?: machine.year,
        slug = normalizedOptionalString(machine.slug) ?: machine.practiceIdentity,
        primaryImageUrl = normalizedOptionalString(machine.primaryImageMediumUrl),
        primaryImageLargeUrl = normalizedOptionalString(machine.primaryImageLargeUrl),
        playfieldImageUrl = playfieldSourceUrl,
        playfieldLocalOriginal = normalizeLibraryCachePath(playfieldLocalPath),
        playfieldLocal = normalizeLibraryPlayfieldLocalPath(playfieldLocalPath),
        playfieldSourceLabel = if (playfieldLocalPath == null && (machine.playfieldImageLargeUrl != null || machine.playfieldImageMediumUrl != null)) "Playfield (OPDB)" else null,
        gameinfoLocal = curatedOverride?.gameinfoLocalPath,
        rulesheetLocal = resolvedRulesheet.first,
        rulesheetUrl = resolvedRulesheet.second.firstOrNull()?.url,
        rulesheetLinks = resolvedRulesheet.second,
        videos = resolvedVideos,
    )
}

internal fun preferredMachineForSourceLookup(
    requestedMachineId: String,
    machineByOpdbId: Map<String, CatalogMachineRecord>,
    machineByPracticeIdentity: Map<String, List<CatalogMachineRecord>>,
): CatalogMachineRecord? {
    val normalizedMachineId = normalizedOptionalString(requestedMachineId)
    val preferredGroupMachine = normalizedMachineId
        ?.let { machineByPracticeIdentity[it]?.minWithOrNull(::comparePreferredMachine) }
    val exactMachine = normalizedMachineId?.let { machineByOpdbId[it] } ?: return preferredGroupMachine
    if (catalogMachineHasPrimaryImage(exactMachine)) return exactMachine
    val exactGroupMachine = machineByPracticeIdentity[exactMachine.practiceIdentity]?.minWithOrNull(::comparePreferredMachine)
    return exactGroupMachine ?: preferredGroupMachine ?: exactMachine
}

internal fun comparePreferredMachine(lhs: CatalogMachineRecord, rhs: CatalogMachineRecord): Int {
    val lhsHasPrimary = catalogMachineHasPrimaryImage(lhs)
    val rhsHasPrimary = catalogMachineHasPrimaryImage(rhs)
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

    return (lhs.opdbMachineId ?: lhs.practiceIdentity).compareTo(rhs.opdbMachineId ?: rhs.practiceIdentity)
}

internal fun compareGroupDefaultMachine(lhs: CatalogMachineRecord, rhs: CatalogMachineRecord): Int {
    val lhsVariant = normalizedOptionalString(lhs.variant)
    val rhsVariant = normalizedOptionalString(rhs.variant)
    if ((lhsVariant == null) != (rhsVariant == null)) return if (lhsVariant == null) -1 else 1

    val lhsYear = lhs.year ?: Int.MAX_VALUE
    val rhsYear = rhs.year ?: Int.MAX_VALUE
    if (lhsYear != rhsYear) return lhsYear.compareTo(rhsYear)

    val lhsName = lhs.name.lowercase()
    val rhsName = rhs.name.lowercase()
    if (lhsName != rhsName) return lhsName.compareTo(rhsName)

    return (lhs.opdbMachineId ?: lhs.practiceIdentity).compareTo(rhs.opdbMachineId ?: rhs.practiceIdentity)
}

internal fun preferredMachineForVariant(
    candidates: List<CatalogMachineRecord>,
    requestedVariant: String?,
): CatalogMachineRecord? {
    if (candidates.isEmpty()) return null
    val ranked = candidates.sortedWith { lhs, rhs ->
        val lhsScore = catalogVariantScore(lhs.variant, requestedVariant)
        val rhsScore = catalogVariantScore(rhs.variant, requestedVariant)
        when {
            lhsScore != rhsScore -> rhsScore.compareTo(lhsScore)
            else -> comparePreferredMachine(lhs, rhs)
        }
    }
    val best = ranked.firstOrNull() ?: return null
    val normalizedRequested = normalizedOptionalString(requestedVariant)
    if (normalizedRequested != null) {
        val bestScore = catalogVariantScore(best.variant, normalizedRequested)
        if (bestScore <= 0) return null
    }
    return best
}

internal fun catalogMachineHasPrimaryImage(machine: CatalogMachineRecord): Boolean =
    machine.primaryImageMediumUrl != null || machine.primaryImageLargeUrl != null

internal fun catalogVariantScore(machineVariant: String?, requestedVariant: String?): Int {
    val normalizedMachineVariant = normalizedOptionalString(machineVariant)?.lowercase()
    if (requestedVariant.isNullOrBlank()) return 0
    if (normalizedMachineVariant == requestedVariant) return 200
    if (!normalizedMachineVariant.isNullOrBlank() && normalizedMachineVariant.contains(requestedVariant)) return 120
    if (requestedVariant.contains("premium") && normalizedMachineVariant == "le") return 80
    if (requestedVariant == "le" && normalizedMachineVariant?.contains("anniversary") == true) return 40
    return 0
}

internal fun resolveRulesheetLinks(rulesheetLinks: List<CatalogRulesheetLinkRecord>): ResolvedRulesheetLinks {
    val sortedLinks = rulesheetLinks.sortedWith(compareBy<CatalogRulesheetLinkRecord> { it.priority ?: Int.MAX_VALUE }.thenBy { it.label })
    val links = sortedLinks.mapNotNull { link ->
        val url = normalizedOptionalString(link.url) ?: return@mapNotNull null
        ReferenceLink(label = catalogRulesheetLabel(link.provider, link.label), url = url)
    }
    return ResolvedRulesheetLinks(
        localPath = normalizedOptionalString(sortedLinks.firstOrNull()?.localPath),
        links = links,
    )
}

internal fun resolveVideoLinks(videoLinks: List<CatalogVideoLinkRecord>): List<Video> {
    val groupedByProvider = videoLinks.groupBy { it.provider.lowercase() }
    val preferred = groupedByProvider["local"]?.sortedWith(compareVideoLinks())
        ?: groupedByProvider["matchplay"]?.sortedWith(compareVideoLinks())
        ?: emptyList()
    return preferred.map { link -> Video(kind = link.kind, label = link.label, url = link.url) }
}

internal fun compareVideoLinks(): Comparator<CatalogVideoLinkRecord> =
    compareBy<CatalogVideoLinkRecord> { it.priority ?: Int.MAX_VALUE }.thenBy { it.label.lowercase() }

internal fun catalogRulesheetLabel(providerRawValue: String, fallback: String): String {
    return when (providerRawValue.lowercase()) {
        "tf" -> "Rulesheet (TF)"
        "pp" -> "Rulesheet (PP)"
        "bob" -> "Rulesheet (Bob)"
        "papa" -> "Rulesheet (PAPA)"
        "opdb" -> "Rulesheet (OPDB)"
        "local" -> "Rulesheet"
        else -> fallback
    }
}

internal data class ResolvedRulesheetLinks(
    val localPath: String?,
    val links: List<ReferenceLink>,
)

internal fun normalizedOptionalString(value: String?): String? =
    value?.trim()?.takeIf { it.isNotEmpty() }
