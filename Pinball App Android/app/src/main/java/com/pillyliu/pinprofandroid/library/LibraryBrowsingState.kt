package com.pillyliu.pinprofandroid.library

internal data class LibraryBrowseState(
    val games: List<PinballGame>,
    val sources: List<LibrarySource>,
    val selectedSourceId: String,
    val query: String,
    val sortOptionName: String,
    val yearSortDescending: Boolean,
    val selectedBank: Int?,
    val pinnedSourceIds: List<String>,
) {
    val selectedSource: LibrarySource?
        get() = sources.firstOrNull { it.id == selectedSourceId } ?: sources.firstOrNull()

    val visibleSources: List<LibrarySource>
        get() {
            val pinned = pinnedSourceIds.mapNotNull { pinnedId -> sources.firstOrNull { it.id == pinnedId } }
            if (pinned.isEmpty()) return sources
            return buildList {
                addAll(pinned)
                selectedSource?.let { source ->
                    if (none { it.id == source.id }) {
                        add(source)
                    }
                }
                sources.forEach { source ->
                    if (none { it.id == source.id }) {
                        add(source)
                    }
                }
            }
        }

    val sourceScopedGames: List<PinballGame>
        get() {
            val sid = selectedSource?.id ?: return games
            return games.filter { it.sourceId == sid }
        }

    val sortOptions: List<LibrarySortOption>
        get() = selectedSource?.let { sortOptionsForSource(it, sourceScopedGames) }
            ?: listOf(LibrarySortOption.AREA, LibrarySortOption.ALPHABETICAL)

    val fallbackSort: LibrarySortOption
        get() = selectedSource?.defaultSortOption?.takeIf { sortOptions.contains(it) } ?: sortOptions.first()

    val sortOption: LibrarySortOption
        get() = LibrarySortOption.entries.firstOrNull { it.name == sortOptionName }
            ?.takeIf { sortOptions.contains(it) }
            ?: fallbackSort

    val supportsBankFilter: Boolean
        get() = selectedSource?.type == LibrarySourceType.VENUE && sourceScopedGames.any { (it.bank ?: 0) > 0 }

    val effectiveSelectedBank: Int?
        get() = if (supportsBankFilter) selectedBank else null

    val bankOptions: List<Int>
        get() = sourceScopedGames.mapNotNull { it.bank }.filter { it > 0 }.toSet().sorted()

    val filteredGames: List<PinballGame>
        get() {
            return sourceScopedGames.filter { game ->
                val queryMatch = matchesSearchQuery(
                    query = query,
                    fields = listOf(
                        game.name,
                        game.normalizedVariant,
                        game.manufacturer,
                        game.year?.toString(),
                    ),
                )
                val bankMatch = effectiveSelectedBank == null || game.bank == effectiveSelectedBank
                queryMatch && bankMatch
            }
        }

    val sortedGames: List<PinballGame>
        get() = sortLibraryGames(filteredGames, sortOption, yearSortDescending)

    val showGroupedView: Boolean
        get() = effectiveSelectedBank == null && (sortOption == LibrarySortOption.AREA || sortOption == LibrarySortOption.BANK)

    val selectedSortLabel: String
        get() = when {
            sortOption == LibrarySortOption.YEAR && yearSortDescending -> "Sort: Year (New-Old)"
            sortOption == LibrarySortOption.YEAR -> "Sort: Year (Old-New)"
            else -> sortOption.label
        }

    val selectedBankLabel: String
        get() = effectiveSelectedBank?.let { "Bank $it" } ?: "All banks"

    fun visibleGames(limit: Int): List<PinballGame> = sortedGames.take(limit)

    fun hasMoreGames(limit: Int): Boolean = visibleGames(limit).size < sortedGames.size

    fun groupedSections(limit: Int): List<LibraryGroupSection> {
        val visible = visibleGames(limit)
        return when (sortOption) {
            LibrarySortOption.AREA -> buildSections(visible) { it.group }
            LibrarySortOption.BANK -> buildSections(visible) { it.bank }
            LibrarySortOption.ALPHABETICAL, LibrarySortOption.YEAR -> emptyList()
        }
    }
}

internal data class LibrarySelectionResolution(
    val selectedSourceId: String,
    val sortOptionName: String,
    val yearSortDescending: Boolean,
    val selectedBank: Int?,
)

internal fun resolveLibrarySelection(
    payload: ParsedLibraryData,
    sourceState: LibrarySourceState,
    savedSourceId: String?,
    currentSelectedSourceId: String,
): LibrarySelectionResolution? {
    val preferredSourceId = listOfNotNull(sourceState.selectedSourceId, savedSourceId, currentSelectedSourceId)
        .firstOrNull { candidate -> payload.sources.any { it.id == candidate } }
    val chosenSource = payload.sources.firstOrNull { it.id == preferredSourceId } ?: payload.sources.firstOrNull()
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
