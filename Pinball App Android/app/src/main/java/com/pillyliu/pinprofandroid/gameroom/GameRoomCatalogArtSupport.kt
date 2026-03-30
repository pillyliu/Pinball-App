package com.pillyliu.pinprofandroid.gameroom

internal fun buildSlugKeys(slug: String): List<String> {
    val lowered = slug.trim().lowercase()
    if (lowered.isBlank()) return emptyList()
    val keys = linkedSetOf<String>()
    keys += lowered
    keys += normalizeSlugForMatching(lowered)
    val strippedVariant = stripVariantSuffix(normalizeSlugForMatching(lowered))
    if (strippedVariant.isNotBlank()) keys += strippedVariant
    return keys.toList()
}

internal fun normalizeSlugForMatching(slug: String): String {
    val prefixTokens = setOf(
        "stern",
        "williams",
        "bally",
        "gottlieb",
        "spooky",
        "jersey",
        "jack",
        "american",
        "pinball",
        "chicago",
        "gaming",
        "company",
        "sega",
        "data",
        "east",
    )
    val tokens = slug.split("-").filter { it.isNotBlank() }.toMutableList()
    while (tokens.isNotEmpty() && tokens.first() in prefixTokens) {
        tokens.removeAt(0)
    }
    val yearRegex = Regex("""^(19|20)\d{2}$""")
    val withoutYears = tokens.filterNot { token -> yearRegex.matches(token) }
    return withoutYears.joinToString("-")
}

internal fun stripVariantSuffix(slug: String): String {
    val suffixTokens = setOf(
        "premium",
        "pro",
        "le",
        "ce",
        "se",
        "limited",
        "edition",
        "collector",
        "collectors",
    )
    val tokens = slug.split("-").filter { it.isNotBlank() }.toMutableList()
    while (tokens.isNotEmpty() && tokens.last() in suffixTokens) {
        tokens.removeAt(tokens.lastIndex)
    }
    return tokens.joinToString("-")
}

internal fun compareCatalogRecords(lhs: GameRoomCatalogMachineRecord, rhs: GameRoomCatalogMachineRecord): Int {
    val lhsHasArt = hasPrimaryArt(lhs)
    val rhsHasArt = hasPrimaryArt(rhs)
    if (lhsHasArt != rhsHasArt) return if (lhsHasArt) -1 else 1

    val lhsVariant = lhs.variant?.trim().orEmpty()
    val rhsVariant = rhs.variant?.trim().orEmpty()
    if (lhsVariant.isEmpty() != rhsVariant.isEmpty()) return if (lhsVariant.isEmpty()) -1 else 1

    val lhsYear = lhs.year ?: Int.MAX_VALUE
    val rhsYear = rhs.year ?: Int.MAX_VALUE
    if (lhsYear != rhsYear) return lhsYear.compareTo(rhsYear)

    return lhs.machineName.lowercase().compareTo(rhs.machineName.lowercase())
}

internal fun machineVariantMatchScore(machineVariant: String?, selectedVariant: String?): Int {
    val requested = selectedVariant?.trim()?.lowercase().orEmpty()
    val candidate = machineVariant?.trim()?.lowercase().orEmpty()
    if (requested.isBlank()) return 0
    if (candidate == requested) return 200
    if (candidate.contains(requested) || requested.contains(candidate)) return 120
    if (requested.contains("premium") && candidate == "le") return 80
    if (requested == "le" && candidate.contains("anniversary")) return 40
    return 0
}

internal fun machineContextScore(
    record: GameRoomCatalogMachineRecord,
    selectedVariant: String?,
    selectedTitle: String?,
    selectedYear: Int?,
): Int {
    var score = machineVariantMatchScore(record.variant, selectedVariant)
    val inferredVariant = selectedTitle
        ?.takeIf { it.contains("(") && it.contains(")") }
        ?.substringAfterLast('(')
        ?.substringBeforeLast(')')
        ?.trim()
    if (score == 0 && !inferredVariant.isNullOrBlank()) {
        score = machineVariantMatchScore(record.variant, inferredVariant)
    }
    if (selectedYear != null && record.year == selectedYear) {
        score += 90
    }
    return score
}

internal fun hasPrimaryArt(record: GameRoomCatalogMachineRecord): Boolean {
    return !record.primaryImageLargeUrl.isNullOrBlank() ||
        !record.primaryImageUrl.isNullOrBlank()
}

internal fun resolveUrl(pathOrUrl: String?): String? {
    val value = pathOrUrl?.trim()?.takeIf { it.isNotEmpty() } ?: return null
    if (value.startsWith("http://") || value.startsWith("https://")) return value
    return if (value.startsWith("/")) {
        "https://pillyliu.com$value"
    } else {
        "https://pillyliu.com/$value"
    }
}
