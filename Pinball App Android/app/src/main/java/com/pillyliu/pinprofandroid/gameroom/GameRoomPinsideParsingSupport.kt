package com.pillyliu.pinprofandroid.gameroom

internal fun parseBasicPinsideMachines(
    html: String,
    groupMap: Map<String, String>,
): List<PinsideImportedMachine> {
    validatePinsideCollectionPageHTML(html)
    if (looksLikePinsideChallengePage(html)) {
        throw pinsideImportException(GameRoomPinsideImportError.parseFailed, "Pinside returned a challenge page.")
    }
    val slugs = findPinsideCollectionSlugs(html)
    if (slugs.isEmpty()) {
        throw pinsideImportException(GameRoomPinsideImportError.noMachinesFound)
    }
    return slugs.map { slug ->
        PinsideImportedMachine(
            id = slug,
            slug = slug,
            rawTitle = resolvePinsideSlugTitle(slug, groupMap),
            rawVariant = pinsideVariantFromSlug(slug),
        )
    }
}

internal fun parseDetailedPinsideMachines(content: String): List<PinsideImportedMachine> {
    val titleRegex = Regex(
        """^####\s+(.+?)\s+\[\]\((?:https?:\/\/)?pinside\.com\/pinball\/machine\/([a-z0-9\-]+)[^)]*\)\s*$""",
        RegexOption.IGNORE_CASE,
    )
    val metadataRegex = Regex(
        """^#####\s+(.+?),\s*((?:19|20)\d{2})\s*$""",
        RegexOption.IGNORE_CASE,
    )
    val lines = content.lines()
    val seen = linkedSetOf<String>()
    val machines = mutableListOf<PinsideImportedMachine>()
    var index = 0

    while (index < lines.size) {
        val line = lines[index].trim()
        val titleMatch = titleRegex.matchEntire(line)
        if (titleMatch == null) {
            index += 1
            continue
        }

        val slug = titleMatch.groupValues.getOrNull(2)?.trim()?.lowercase().orEmpty()
        if (slug.isBlank() || !seen.add(slug)) {
            index += 1
            continue
        }

        val displayTitle = titleMatch.groupValues.getOrNull(1)?.trim().orEmpty()
        var scanIndex = index + 1
        while (scanIndex < lines.size && lines[scanIndex].trim().isEmpty()) {
            scanIndex += 1
        }
        if (scanIndex >= lines.size) break

        val metadataMatch = metadataRegex.matchEntire(lines[scanIndex].trim())
        if (metadataMatch == null) {
            index += 1
            continue
        }

        val parsedTitle = canonicalPinsideDisplayedTitle(displayTitle, pinsideVariantFromSlug(slug))
        val manufacturer = metadataMatch.groupValues.getOrNull(1)?.trim()?.ifBlank { null }
        val year = metadataMatch.groupValues.getOrNull(2)?.trim()?.toIntOrNull()

        scanIndex += 1
        while (scanIndex < lines.size && lines[scanIndex].trim().isEmpty()) {
            scanIndex += 1
        }

        var purchaseText: String? = null
        if (scanIndex < lines.size) {
            val purchaseLine = lines[scanIndex].trim()
            if (purchaseLine.startsWith("Purchased ", ignoreCase = true)) {
                purchaseText = purchaseLine.substring("Purchased ".length).trim().ifBlank { null }
                scanIndex += 1
            }
        }

        machines += PinsideImportedMachine(
            id = slug,
            slug = slug,
            rawTitle = parsedTitle.first,
            rawVariant = parsedTitle.second,
            manufacturerLabel = manufacturer,
            manufactureYear = year,
            rawPurchaseDateText = purchaseText,
            normalizedPurchaseDateMs = normalizeFirstOfMonthMs(purchaseText),
        )
        index = scanIndex
    }

    return machines
}

internal fun mergePinsideMachines(
    primary: List<PinsideImportedMachine>,
    fallback: List<PinsideImportedMachine>,
): List<PinsideImportedMachine> {
    val fallbackBySlug = fallback.associateBy { it.slug.lowercase() }.toMutableMap()
    val merged = mutableListOf<PinsideImportedMachine>()

    primary.forEach { machine ->
        val key = machine.slug.lowercase()
        val fallbackMachine = fallbackBySlug.remove(key)
        if (fallbackMachine == null) {
            merged += machine
        } else {
            merged += machine.copy(
                rawVariant = machine.rawVariant ?: fallbackMachine.rawVariant,
                manufacturerLabel = machine.manufacturerLabel ?: fallbackMachine.manufacturerLabel,
                manufactureYear = machine.manufactureYear ?: fallbackMachine.manufactureYear,
                rawPurchaseDateText = machine.rawPurchaseDateText ?: fallbackMachine.rawPurchaseDateText,
                normalizedPurchaseDateMs = machine.normalizedPurchaseDateMs ?: fallbackMachine.normalizedPurchaseDateMs,
            )
        }
    }

    fallback.forEach { machine ->
        if (fallbackBySlug.containsKey(machine.slug.lowercase())) {
            merged += machine
        }
    }

    return merged
}
