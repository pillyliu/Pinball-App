package com.pillyliu.pinprofandroid.library

internal fun resolveImportedGame(
    machine: CatalogMachineRecord,
    source: ImportedSourceRecord,
    manufacturerById: Map<String, CatalogManufacturerRecord>,
    curatedOverride: LegacyCuratedOverride?,
    opdbRulesheets: List<CatalogRulesheetLinkRecord>,
    opdbVideos: List<CatalogVideoLinkRecord>,
    venueMetadata: ResolvedImportedVenueMetadata?,
): PinballGame {
    val manufacturerName = curatedOverride?.manufacturerOverride
        ?: machine.manufacturerName
        ?: machine.manufacturerId?.let { manufacturerById[it]?.name }
    val resolvedCatalogRulesheet = resolveRulesheetLinks(opdbRulesheets)
    val resolvedRulesheet = if (!curatedOverride?.rulesheetLocalPath.isNullOrBlank()) {
        val primaryLinks = curatedOverride?.rulesheetLinks.orEmpty()
            .filterNot(::shouldSuppressLocalMarkdownRulesheetLink)
        val mergedLinks = mergeRulesheetLinks(
            primaryLinks,
            resolvedCatalogRulesheet.links,
        )
        normalizedOptionalString(curatedOverride?.rulesheetLocalPath)
            ?.takeUnless { shouldSuppressLocalRulesheetPath(mergedLinks) } to mergedLinks
    } else if (!curatedOverride?.rulesheetLinks.isNullOrEmpty()) {
        null to mergeRulesheetLinks(curatedOverride!!.rulesheetLinks, resolvedCatalogRulesheet.links)
    } else {
        resolvedCatalogRulesheet.localPath to resolvedCatalogRulesheet.links
    }
    val resolvedVideos = mergeResolvedVideos(
        primary = curatedOverride?.videos.orEmpty(),
        secondary = resolveVideoLinks(opdbVideos),
    )
    val playfieldLocalPath = curatedOverride?.playfieldLocalPath
    val opdbPlayfieldSourceUrl = normalizedOptionalString(machine.playfieldImageLargeUrl ?: machine.playfieldImageMediumUrl)
    val hasCuratedPlayfield = playfieldLocalPath != null || !curatedOverride?.playfieldSourceUrl.isNullOrBlank()
    val playfieldSourceUrl = curatedOverride?.playfieldSourceUrl ?: opdbPlayfieldSourceUrl
    return PinballGame(
        libraryEntryId = "${source.id}:${machine.practiceIdentity}",
        practiceIdentity = machine.practiceIdentity,
        opdbId = machine.opdbMachineId,
        opdbGroupId = machine.opdbGroupId,
        opdbMachineId = machine.opdbMachineId,
        variant = curatedOverride?.variantOverride ?: normalizedOptionalString(machine.variant),
        sourceId = source.id,
        sourceName = source.name,
        sourceType = source.type,
        area = venueMetadata?.area,
        areaOrder = venueMetadata?.areaOrder,
        group = venueMetadata?.group,
        position = venueMetadata?.position,
        bank = venueMetadata?.bank,
        name = curatedOverride?.nameOverride ?: resolvedCatalogDisplayTitle(
            title = machine.name,
            explicitVariant = machine.variant,
        ),
        manufacturer = normalizedOptionalString(manufacturerName),
        year = curatedOverride?.yearOverride ?: machine.year,
        slug = normalizedOptionalString(machine.slug) ?: machine.practiceIdentity,
        opdbName = normalizedOptionalString(machine.opdbName),
        opdbCommonName = normalizedOptionalString(machine.opdbCommonName),
        opdbShortname = normalizedOptionalString(machine.opdbShortname),
        opdbDescription = normalizedOptionalString(machine.opdbDescription),
        opdbType = normalizedOptionalString(machine.opdbType),
        opdbDisplay = normalizedOptionalString(machine.opdbDisplay),
        opdbPlayerCount = machine.opdbPlayerCount,
        opdbManufactureDate = normalizedOptionalString(machine.opdbManufactureDate),
        opdbIpdbId = machine.opdbIpdbId,
        opdbGroupShortname = normalizedOptionalString(machine.opdbGroupShortname),
        opdbGroupDescription = normalizedOptionalString(machine.opdbGroupDescription),
        primaryImageUrl = normalizedOptionalString(machine.primaryImageMediumUrl),
        primaryImageLargeUrl = normalizedOptionalString(machine.primaryImageLargeUrl),
        playfieldImageUrl = playfieldSourceUrl,
        alternatePlayfieldImageUrl = if (hasCuratedPlayfield) opdbPlayfieldSourceUrl else null,
        playfieldLocalOriginal = normalizeLibraryCachePath(playfieldLocalPath),
        playfieldLocal = normalizeLibraryPlayfieldLocalPath(playfieldLocalPath),
        playfieldSourceLabel = if (hasCuratedPlayfield) null else if (machine.playfieldImageLargeUrl != null || machine.playfieldImageMediumUrl != null) "Playfield (OPDB)" else null,
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
    val normalizedRequested = normalizedOptionalString(requestedVariant)?.lowercase()
    if (normalizedRequested == null) {
        return candidates.minWithOrNull(::comparePreferredMachine)
    }
    val ranked = candidates.sortedWith { lhs, rhs ->
        val lhsScore = catalogVariantScore(lhs.variant, normalizedRequested)
        val rhsScore = catalogVariantScore(rhs.variant, normalizedRequested)
        when {
            lhsScore != rhsScore -> rhsScore.compareTo(lhsScore)
            catalogMachineHasPrimaryImage(lhs) != catalogMachineHasPrimaryImage(rhs) ->
                if (catalogMachineHasPrimaryImage(lhs)) -1 else 1
            (lhs.year ?: Int.MAX_VALUE) != (rhs.year ?: Int.MAX_VALUE) ->
                (lhs.year ?: Int.MAX_VALUE).compareTo(rhs.year ?: Int.MAX_VALUE)
            else -> (lhs.opdbMachineId ?: lhs.practiceIdentity).compareTo(rhs.opdbMachineId ?: rhs.practiceIdentity)
        }
    }
    val best = ranked.firstOrNull() ?: return null
    val bestScore = catalogVariantScore(best.variant, normalizedRequested)
    if (bestScore <= 0) return null
    return best
}

internal fun catalogMachineHasPrimaryImage(machine: CatalogMachineRecord): Boolean =
    machine.primaryImageMediumUrl != null || machine.primaryImageLargeUrl != null

internal fun resolvedCatalogVariantLabel(title: String, explicitVariant: String?): String? {
    normalizeCatalogVariantLabel(explicitVariant)?.let { return it }
    val trimmedTitle = title.trim()
    if (!trimmedTitle.endsWith(")")) return null
    val openParenIndex = trimmedTitle.lastIndexOf('(')
    if (openParenIndex <= 0) return null
    val rawSuffix = trimmedTitle.substring(openParenIndex + 1, trimmedTitle.length - 1).trim()
    if (!looksLikeCatalogVariantSuffix(rawSuffix)) return null
    return normalizeCatalogVariantLabel(rawSuffix)
}

internal fun resolvedCatalogDisplayTitle(title: String, explicitVariant: String?): String {
    val trimmedTitle = title.trim()
    if (!trimmedTitle.endsWith(")")) return trimmedTitle
    val openParenIndex = trimmedTitle.lastIndexOf('(')
    if (openParenIndex <= 0) return trimmedTitle
    val rawSuffix = trimmedTitle.substring(openParenIndex + 1, trimmedTitle.length - 1).trim()
    val normalizedSuffix = normalizeCatalogVariantLabel(rawSuffix)
    val normalizedExplicit = normalizeCatalogVariantLabel(explicitVariant)
    if (!looksLikeCatalogVariantSuffix(rawSuffix)) return trimmedTitle
    if (normalizedExplicit != null && normalizedSuffix != null && normalizedExplicit != normalizedSuffix) {
        return trimmedTitle
    }
    return trimmedTitle.substring(0, openParenIndex).trim().ifBlank { trimmedTitle }
}

internal fun catalogVariantScore(machineVariant: String?, requestedVariant: String?): Int {
    val normalizedMachineVariant = normalizedOptionalString(machineVariant)?.lowercase()
    val normalizedRequested = normalizedOptionalString(requestedVariant)?.lowercase() ?: return 0
    if (normalizedMachineVariant.isNullOrBlank()) return 0
    if (normalizedMachineVariant == normalizedRequested) return 200
    val machineTokens = normalizedMachineVariant
        ?.split(Regex("[^A-Za-z0-9]+"))
        ?.filter { it.isNotBlank() }
        ?.toSet()
        .orEmpty()
    val requestTokens = normalizedRequested
        .split(Regex("[^A-Za-z0-9]+"))
        .filter { it.isNotBlank() }
        .toSet()
    val sharedTokens = machineTokens.intersect(requestTokens)
    if (machineTokens.isNotEmpty() && requestTokens.isNotEmpty() && sharedTokens.isNotEmpty()) {
        var score = 100 + (sharedTokens.size * 20)
        if ("anniversary" in sharedTokens) score += 200
        if (sharedTokens.any { it.endsWith("th") || it.all(Char::isDigit) }) score += 120
        if ("premium" in sharedTokens) score += 40
        if ("le" in sharedTokens) score += 40
        return score
    }
    if (!normalizedMachineVariant.isNullOrBlank() &&
        (normalizedMachineVariant.contains(normalizedRequested) || normalizedRequested.contains(normalizedMachineVariant))
    ) return 80
    return 0
}

private fun looksLikeCatalogVariantSuffix(value: String): Boolean {
    val lowered = value.trim().lowercase()
    if (lowered.isBlank()) return false
    return lowered == "premium" ||
        lowered == "pro" ||
        lowered == "le" ||
        lowered == "ce" ||
        lowered == "se" ||
        lowered == "home" ||
        lowered == "arcade" ||
        lowered == "wizard" ||
        lowered.contains("anniversary") ||
        lowered.contains("limited edition") ||
        lowered.contains("special edition") ||
        lowered.contains("collector") ||
        lowered == "premium/le" ||
        lowered == "premium le" ||
        lowered == "premium-le"
}

private fun normalizeCatalogVariantLabel(value: String?): String? {
    val trimmed = value?.trim().orEmpty()
    if (trimmed.isBlank()) return null
    val lowered = trimmed.lowercase()
    return when {
        lowered == "null" || lowered == "none" -> null
        lowered == "premium" -> "Premium"
        lowered == "pro" -> "Pro"
        lowered == "le" || lowered.contains("limited edition") -> "LE"
        lowered == "ce" || lowered.contains("collector") -> "CE"
        lowered == "se" || lowered.contains("special edition") -> "SE"
        lowered == "arcade" -> "Arcade"
        lowered == "wizard" -> "Wizard"
        lowered == "premium/le" || lowered == "premium le" || lowered == "premium-le" -> "Premium/LE"
        lowered.contains("anniversary") -> trimmed.split(" ")
            .filter { it.isNotBlank() }
            .joinToString(" ") { token ->
                when (token.lowercase()) {
                    "le", "ce", "se" -> token.uppercase()
                    else -> token.replaceFirstChar { ch -> if (ch.isLowerCase()) ch.titlecase() else ch.toString() }
                }
            }
        else -> trimmed
    }
}

internal fun resolveRulesheetLinks(rulesheetLinks: List<CatalogRulesheetLinkRecord>): ResolvedRulesheetLinks {
    val sortedLinks = rulesheetLinks.sortedWith(compareCatalogRulesheetLinks())
    val links = sortedLinks.mapNotNull { link ->
        val url = normalizedOptionalString(link.url) ?: return@mapNotNull null
        ReferenceLink(label = catalogRulesheetLabel(link.provider, link.label, url), url = url)
    }
    val localPath = normalizedOptionalString(sortedLinks.firstOrNull()?.localPath)
        ?.takeUnless { shouldSuppressLocalRulesheetPath(links) }
    return ResolvedRulesheetLinks(
        localPath = localPath,
        links = links,
    )
}

internal fun shouldSuppressLocalRulesheetPath(links: List<ReferenceLink>): Boolean =
    links.any { it.rulesheetSourceKind == RulesheetSourceKind.TF }

internal fun shouldSuppressLocalMarkdownRulesheetLink(link: ReferenceLink): Boolean {
    val destination = resolveLibraryUrl(link.destinationUrl)
    return link.rulesheetSourceKind == RulesheetSourceKind.PROF ||
        link.rulesheetSourceKind == RulesheetSourceKind.LOCAL ||
        isPinProfRulesheetUrl(destination) ||
        isLikelyPinProfMarkdownRulesheetUrl(destination)
}

internal fun mergeRulesheetLinks(primary: List<ReferenceLink>, secondary: List<ReferenceLink>): List<ReferenceLink> {
    val seen = linkedSetOf<String>()
    return buildList {
        for (link in primary + secondary) {
            val key = canonicalRulesheetMergeKey(link)
            if (!seen.add(key)) continue
            add(link)
        }
    }
}

private fun canonicalRulesheetMergeKey(link: ReferenceLink): String {
    val normalizedUrl = normalizedOptionalString(link.url)?.lowercase()
    if (normalizedUrl != null) return "url|$normalizedUrl"
    return "label|${link.label.trim().lowercase()}"
}

internal fun resolveVideoLinks(videoLinks: List<CatalogVideoLinkRecord>): List<Video> {
    val selected = linkedMapOf<String, CatalogVideoLinkRecord>()
    videoLinks.sortedWith(compareVideoLinks()).forEach { link ->
        val url = normalizedOptionalString(link.url) ?: return@forEach
        val key = canonicalVideoMergeKey(link.kind, url)
        if (key !in selected) {
            selected[key] = link
        }
    }
    return selected.values.map { link -> Video(kind = link.kind, label = link.label, url = link.url) }
}

internal fun compareVideoLinks(): Comparator<CatalogVideoLinkRecord> =
    compareBy<CatalogVideoLinkRecord> { videoProviderOrder(it.provider) }
        .thenBy { videoKindOrder(it.kind) }
        .thenBy { it.priority ?: Int.MAX_VALUE }
        .thenBy { it.label.lowercase() }

private fun videoProviderOrder(provider: String): Int =
    when (provider.trim().lowercase()) {
        "local" -> 0
        "matchplay" -> 1
        else -> 99
    }

private fun videoKindOrder(kind: String?): Int =
    when (kind?.trim()?.lowercase()) {
        "tutorial" -> 0
        "gameplay" -> 1
        "competition" -> 2
        else -> 99
    }

private fun extractYouTubeVideoId(rawUrl: String): String? {
    val uri = runCatching { android.net.Uri.parse(rawUrl) }.getOrNull() ?: return null
    val host = uri.host?.trim()?.lowercase() ?: return null
    val pathParts = uri.pathSegments?.filter { it.isNotBlank() }.orEmpty()
    return when {
        host == "youtu.be" || host == "www.youtu.be" -> pathParts.firstOrNull()
        host == "youtube.com" ||
            host == "www.youtube.com" ||
            host == "m.youtube.com" ||
            host == "music.youtube.com" ||
            host == "youtube-nocookie.com" ||
            host == "www.youtube-nocookie.com" ||
            host.endsWith(".youtube.com") ||
            host.endsWith(".youtube-nocookie.com") -> when {
                pathParts.firstOrNull() == "watch" -> uri.getQueryParameter("v")
                pathParts.firstOrNull() in setOf("embed", "shorts", "live") && pathParts.size >= 2 -> pathParts[1]
                else -> uri.getQueryParameter("v")
            }
        else -> null
    }
}

private fun canonicalVideoIdentity(url: String): String =
    extractYouTubeVideoId(url)?.let { "youtube:$it" } ?: "url:${url.trim()}"

private fun canonicalVideoMergeKey(kind: String?, url: String): String =
    "${kind?.trim()?.lowercase().orEmpty()}::${canonicalVideoIdentity(url)}"

internal fun mergeResolvedVideos(primary: List<Video>, secondary: List<Video>): List<Video> {
    val merged = linkedMapOf<String, Video>()
    (primary + secondary).forEach { video ->
        val url = normalizedOptionalString(video.url) ?: return@forEach
        val key = canonicalVideoMergeKey(video.kind, url)
        if (key !in merged) {
            merged[key] = video
        }
    }
    return merged.values.toList()
}

internal fun compareCatalogRulesheetLinks(): Comparator<CatalogRulesheetLinkRecord> =
    compareBy<CatalogRulesheetLinkRecord> {
        catalogRulesheetSortRank(it.provider, it.label, it.url)
    }.thenBy { it.priority ?: Int.MAX_VALUE }
        .thenBy { it.label.lowercase() }
        .thenBy { it.url.orEmpty().lowercase() }

internal fun catalogRulesheetSortRank(providerRawValue: String, label: String, url: String?): Int {
    return when (providerRawValue.lowercase()) {
        "local" -> RulesheetSourceKind.LOCAL.rank
        "prof" -> RulesheetSourceKind.PROF.rank
        "bob" -> RulesheetSourceKind.BOB.rank
        "papa" -> RulesheetSourceKind.PAPA.rank
        "pp" -> RulesheetSourceKind.PP.rank
        "tf" -> RulesheetSourceKind.TF.rank
        "opdb" -> RulesheetSourceKind.OPDB.rank
        else -> ReferenceLink(label = label, url = url).rulesheetSourceKind.rank
    }
}

internal fun catalogRulesheetLabel(providerRawValue: String, fallback: String, url: String? = null): String {
    return when (providerRawValue.lowercase()) {
        "tf" -> "Rulesheet (TF)"
        "pp" -> "Rulesheet (PP)"
        "bob" -> "Rulesheet (Bob)"
        "papa" -> "Rulesheet (PAPA)"
        "prof" -> "Rulesheet (PinProf)"
        "opdb" -> "Rulesheet (OPDB)"
        "local" -> "Rulesheet (PinProf)"
        else -> when (ReferenceLink(label = fallback, url = url).rulesheetSourceKind) {
            RulesheetSourceKind.PROF -> "Rulesheet (PinProf)"
            RulesheetSourceKind.BOB -> "Rulesheet (Bob)"
            RulesheetSourceKind.PAPA -> "Rulesheet (PAPA)"
            RulesheetSourceKind.PP -> "Rulesheet (PP)"
            RulesheetSourceKind.TF -> "Rulesheet (TF)"
            RulesheetSourceKind.OPDB -> "Rulesheet (OPDB)"
            RulesheetSourceKind.LOCAL -> "Rulesheet (PinProf)"
            RulesheetSourceKind.OTHER -> fallback
        }
    }
}

internal data class ResolvedRulesheetLinks(
    val localPath: String?,
    val links: List<ReferenceLink>,
)

internal fun normalizedOptionalString(value: String?): String? =
    value
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
        ?.takeUnless {
            val lowered = it.lowercase()
            lowered == "null" || lowered == "none"
        }
