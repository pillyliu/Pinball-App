package com.pillyliu.pinprofandroid.library

internal fun buildSections(
    filtered: List<PinballGame>,
    keySelector: (PinballGame) -> Int?,
): List<LibraryGroupSection> {
    val out = mutableListOf<LibraryGroupSection>()
    filtered.forEach { game ->
        val key = keySelector(game)
        if (out.isNotEmpty() && out.last().groupKey == key) {
            val merged = out.last().games + game
            out[out.lastIndex] = LibraryGroupSection(groupKey = key, games = merged)
        } else {
            out += LibraryGroupSection(groupKey = key, games = listOf(game))
        }
    }
    return out
}

internal fun sortLibraryGames(
    games: List<PinballGame>,
    option: LibrarySortOption,
    yearSortDescending: Boolean = false,
): List<PinballGame> {
    return when (option) {
        LibrarySortOption.AREA -> games.sortedWith(
            compareBy<PinballGame> { it.areaOrder ?: Int.MAX_VALUE }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.position ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )
        LibrarySortOption.BANK -> games.sortedWith(
            compareBy<PinballGame> { it.bank ?: Int.MAX_VALUE }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.position ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )
        LibrarySortOption.ALPHABETICAL -> games.sortedWith(
            compareBy<PinballGame> { it.name.lowercase() }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.position ?: Int.MAX_VALUE },
        )
        LibrarySortOption.YEAR -> {
            if (yearSortDescending) {
                games.sortedWith(
                    compareByDescending<PinballGame> { it.year ?: Int.MIN_VALUE }
                        .thenBy { it.name.lowercase() },
                )
            } else {
                games.sortedWith(
                    compareBy<PinballGame> { it.year ?: Int.MAX_VALUE }
                        .thenBy { it.name.lowercase() },
                )
            }
        }
    }
}

internal fun sortOptionsForSource(source: LibrarySource, games: List<PinballGame>): List<LibrarySortOption> {
    return when (source.type) {
        LibrarySourceType.CATEGORY,
        LibrarySourceType.MANUFACTURER,
        LibrarySourceType.TOURNAMENT -> listOf(
            LibrarySortOption.YEAR,
            LibrarySortOption.ALPHABETICAL,
        )
        LibrarySourceType.VENUE -> {
            val hasBank = games.any { (it.bank ?: 0) > 0 }
            buildList {
                add(LibrarySortOption.AREA)
                if (hasBank) add(LibrarySortOption.BANK)
                add(LibrarySortOption.ALPHABETICAL)
                add(LibrarySortOption.YEAR)
            }
        }
    }
}

internal fun PinballGame.metaLine(): String {
    val parts = mutableListOf<String>()
    parts += manufacturer ?: "-"
    year?.let { parts += "$it" }
    locationText()?.let { parts += it }
    bank?.takeIf { it > 0 }?.let { parts += "Bank $it" }
    return parts.joinToString(" • ")
}

internal fun PinballGame.manufacturerYearLine(): String {
    return if (year != null) "${manufacturer ?: "-"} • $year" else (manufacturer ?: "-")
}

internal fun PinballGame.manufacturerYearCardLine(): String {
    val maker = abbreviatedLibraryCardManufacturer(manufacturer) ?: "-"
    return if (year != null) "$maker • $year" else maker
}

private fun abbreviatedLibraryCardManufacturer(manufacturer: String?): String? {
    val trimmed = manufacturer?.trim()?.takeIf { it.isNotEmpty() } ?: return null
    return when (trimmed.lowercase()) {
        "jersey jack pinball" -> "JJP"
        "barrels of fun" -> "BoF"
        "chicago gaming company" -> "CGC"
        else -> trimmed
    }
}

internal val PinballGame.normalizedVariant: String?
    get() = variant?.trim()?.takeIf { it.isNotBlank() && !it.equals("null", ignoreCase = true) }

internal fun PinballGame.locationBankLine(): String {
    val parts = mutableListOf<String>()
    locationText()?.let { parts += it }
    bank?.takeIf { it > 0 }?.let { parts += "Bank $it" }
    return if (parts.isEmpty()) "" else parts.joinToString(" • ")
}

private fun PinballGame.locationText(): String? {
    val g = group ?: return null
    val p = position ?: return null
    val normalizedArea = area
        ?.trim()
        ?.takeUnless { it.isBlank() || it.equals("null", ignoreCase = true) }
    return if (normalizedArea != null) {
        "📍 $normalizedArea:$g:$p"
    } else {
        "📍 $g:$p"
    }
}

internal val PinballGame.practiceKey: String
    get() = canonicalPracticeKey

internal val PinballGame.canonicalPracticeKey: String
    get() = practiceIdentity?.ifBlank { null } ?: opdbId?.ifBlank { null } ?: ""

internal val PinballGame.libraryRouteId: String
    get() = libraryEntryId?.ifBlank { null } ?: opdbId?.ifBlank { null } ?: practiceKey
