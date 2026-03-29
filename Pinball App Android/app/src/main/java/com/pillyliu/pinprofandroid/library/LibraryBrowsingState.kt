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
