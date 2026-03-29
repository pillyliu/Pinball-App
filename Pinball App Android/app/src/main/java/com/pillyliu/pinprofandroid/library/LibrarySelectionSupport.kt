package com.pillyliu.pinprofandroid.library

internal data class LibrarySelectionResolution(
    val selectedSourceId: String,
    val sortOptionName: String,
    val yearSortDescending: Boolean,
    val selectedBank: Int?,
)

internal fun resolvePreferredLibrarySource(
    sources: List<LibrarySource>,
    selectedSourceId: String?,
    currentSelectedSourceId: String? = null,
): LibrarySource? {
    val preferredSourceId = listOfNotNull(selectedSourceId, currentSelectedSourceId)
        .mapNotNull(::canonicalLibrarySourceId)
        .firstOrNull { candidate -> sources.any { it.id == candidate } }
    return sources.firstOrNull { it.id == preferredSourceId } ?: sources.firstOrNull()
}

internal fun resolveLibrarySelection(
    payload: ParsedLibraryData,
    sourceState: LibrarySourceState,
    currentSelectedSourceId: String,
): LibrarySelectionResolution? {
    val chosenSource = resolvePreferredLibrarySource(
        sources = payload.sources,
        selectedSourceId = sourceState.selectedSourceId,
        currentSelectedSourceId = currentSelectedSourceId,
    )
    return chosenSource?.let { source ->
        resolveLibrarySelectionForSource(
            source = source,
            games = payload.games,
            sourceState = sourceState,
        )
    }
}

internal fun resolveLibrarySelectionForSource(
    source: LibrarySource,
    games: List<PinballGame>,
    sourceState: LibrarySourceState,
): LibrarySelectionResolution {
    val sourceGames = games.filter { it.sourceId == source.id }
    val options = sortOptionsForSource(source, sourceGames)
    val persistedSort = sourceState.selectedSortBySource[source.id]
    val (sortOptionName, yearSortDescending) = when {
        source.type == LibrarySourceType.MANUFACTURER ->
            LibrarySortOption.YEAR.name to true
        persistedSort == "YEAR_DESC" ->
            LibrarySortOption.YEAR.name to true
        persistedSort != null && options.any { it.name == persistedSort } ->
            persistedSort to false
        else -> {
            val defaultSort = preferredDefaultSortOption(source, sourceGames)
            val resolvedSort = defaultSort.takeIf { options.contains(it) } ?: options.first()
            resolvedSort.name to preferredDefaultYearSortDescending(source, sourceGames)
        }
    }
    val selectedBank = if (source.type == LibrarySourceType.VENUE && sourceGames.any { (it.bank ?: 0) > 0 }) {
        sourceState.selectedBankBySource[source.id]
    } else {
        null
    }
    return LibrarySelectionResolution(
        selectedSourceId = source.id,
        sortOptionName = sortOptionName,
        yearSortDescending = yearSortDescending,
        selectedBank = selectedBank,
    )
}

internal fun preferredDefaultSortOption(source: LibrarySource, games: List<PinballGame>): LibrarySortOption {
    return when (source.type) {
        LibrarySourceType.MANUFACTURER -> LibrarySortOption.YEAR
        LibrarySourceType.CATEGORY,
        LibrarySourceType.TOURNAMENT -> LibrarySortOption.ALPHABETICAL
        LibrarySourceType.VENUE -> {
            val hasArea = games.any {
                val area = it.area?.trim()
                !area.isNullOrEmpty() && !area.equals("null", ignoreCase = true)
            }
            val hasPosition = games.any { (it.group ?: 0) > 0 || (it.position ?: 0) > 0 }
            if (hasArea || hasPosition) LibrarySortOption.AREA else LibrarySortOption.ALPHABETICAL
        }
    }
}

internal fun preferredDefaultYearSortDescending(source: LibrarySource, games: List<PinballGame>): Boolean =
    source.type == LibrarySourceType.MANUFACTURER && preferredDefaultSortOption(source, games) == LibrarySortOption.YEAR
