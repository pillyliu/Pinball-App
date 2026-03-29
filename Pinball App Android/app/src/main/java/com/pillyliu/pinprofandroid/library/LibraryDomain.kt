package com.pillyliu.pinprofandroid.library

import androidx.compose.ui.unit.dp

internal val LIBRARY_CONTENT_BOTTOM_FILLER = 60.dp

internal enum class LibrarySourceType(val rawValue: String) {
    VENUE("venue"),
    CATEGORY("category"),
    MANUFACTURER("manufacturer"),
    TOURNAMENT("tournament");

    companion object {
        fun fromRaw(raw: String?): LibrarySourceType? {
            return when (raw?.trim()?.lowercase()) {
                "venue" -> VENUE
                "category" -> CATEGORY
                "manufacturer" -> MANUFACTURER
                "tournament" -> TOURNAMENT
                else -> null
            }
        }
    }
}

internal data class LibrarySource(
    val id: String,
    val name: String,
    val type: LibrarySourceType,
) {
    val defaultSortOption: LibrarySortOption
        get() = when (type) {
            LibrarySourceType.VENUE -> LibrarySortOption.AREA
            LibrarySourceType.CATEGORY -> LibrarySortOption.ALPHABETICAL
            LibrarySourceType.MANUFACTURER -> LibrarySortOption.YEAR
            LibrarySourceType.TOURNAMENT -> LibrarySortOption.ALPHABETICAL
        }
}

internal data class ParsedLibraryData(
    val games: List<PinballGame>,
    val sources: List<LibrarySource>,
)

internal data class LibraryExtraction(
    val payload: ParsedLibraryData,
    val state: LibrarySourceState,
)

internal data class CatalogManufacturerOption(
    val id: String,
    val name: String,
    val gameCount: Int,
    val isModern: Boolean,
    val featuredRank: Int?,
    val sortBucket: Int,
)

internal data class LibraryVenueSearchResult(
    val id: String,
    val name: String,
    val city: String?,
    val state: String?,
    val zip: String?,
    val distanceMiles: Double?,
    val machineCount: Int,
)
internal data class LibraryGroupSection(val groupKey: Int?, val games: List<PinballGame>)
internal enum class LibraryRouteKind {
    LIST,
    DETAIL,
    RULESHEET,
    EXTERNAL_RULESHEET,
    PLAYFIELD,
}

internal enum class LibrarySortOption(val label: String) {
    AREA("Sort: Area"),
    BANK("Sort: Bank"),
    ALPHABETICAL("Sort: A-Z"),
    YEAR("Sort: Year"),
}

internal data class PinballGame(
    val libraryEntryId: String?,
    val practiceIdentity: String?,
    val opdbId: String? = null,
    val opdbGroupId: String? = null,
    val opdbMachineId: String? = null,
    val variant: String?,
    val sourceId: String,
    val sourceName: String,
    val sourceType: LibrarySourceType,
    val area: String?,
    val areaOrder: Int?,
    val group: Int?,
    val position: Int?,
    val bank: Int?,
    val name: String,
    val manufacturer: String?,
    val year: Int?,
    val slug: String,
    val opdbName: String? = null,
    val opdbCommonName: String? = null,
    val opdbShortname: String? = null,
    val opdbDescription: String? = null,
    val opdbType: String? = null,
    val opdbDisplay: String? = null,
    val opdbPlayerCount: Int? = null,
    val opdbManufactureDate: String? = null,
    val opdbIpdbId: Int? = null,
    val opdbGroupShortname: String? = null,
    val opdbGroupDescription: String? = null,
    val primaryImageUrl: String? = null,
    val primaryImageLargeUrl: String? = null,
    val playfieldImageUrl: String?,
    val alternatePlayfieldImageUrl: String? = null,
    val playfieldLocalOriginal: String?,
    val playfieldLocal: String?,
    val playfieldSourceLabel: String? = null,
    val gameinfoLocal: String?,
    val rulesheetLocal: String?,
    val rulesheetUrl: String?,
    val rulesheetLinks: List<ReferenceLink> = emptyList(),
    val videos: List<Video>,
)

internal val PinballGame.orderedRulesheetLinks: List<ReferenceLink>
    get() = rulesheetLinks.sortedWith(
        compareBy<ReferenceLink> { it.rulesheetSourceKind.rank }
            .thenBy { it.label.lowercase() }
            .thenBy { resolveLibraryUrl(it.destinationUrl).orEmpty().lowercase() },
    )
