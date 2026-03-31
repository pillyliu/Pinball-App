package com.pillyliu.pinprofandroid.gameroom

import android.util.Log
import com.pillyliu.pinprofandroid.library.decodeCatalogManufacturerOptionsFromOPDBExport
import com.pillyliu.pinprofandroid.library.decodeOPDBExportCatalogMachines

private const val GAME_ROOM_CATALOG_TAG = "PinballDataIntegrity"

internal data class GameRoomLoadedCatalogData(
    val allCatalogGames: List<GameRoomCatalogGame>,
    val games: List<GameRoomCatalogGame>,
    val manufacturers: List<String>,
    val manufacturerOptions: List<GameRoomCatalogManufacturerOption>,
    val gamesByCatalogGameID: Map<String, List<GameRoomCatalogGame>>,
    val gamesByNormalizedCatalogGameID: Map<String, List<GameRoomCatalogGame>>,
    val variantOptionsByCatalogGameID: Map<String, List<String>>,
    val variantOptionsByNormalizedCatalogGameID: Map<String, List<String>>,
    val machineRecordsByCatalogGameID: Map<String, List<GameRoomCatalogMachineRecord>>,
    val slugMatchesBySlug: Map<String, GameRoomCatalogSlugMatch>,
)

internal fun buildGameRoomLoadedCatalogData(
    raw: String,
    practiceIdentityCurationsRaw: String?,
): GameRoomLoadedCatalogData {
    val machines = decodeOPDBExportCatalogMachines(raw, practiceIdentityCurationsRaw)
    if (machines.isEmpty()) {
        throw IllegalStateException("Catalog data is missing machines.")
    }

    val manufacturerOptions = decodeCatalogManufacturerOptionsFromOPDBExport(raw, practiceIdentityCurationsRaw)
        .map { option ->
            GameRoomCatalogManufacturerOption(
                id = option.id,
                name = option.name,
                isModern = option.isModern,
                featuredRank = option.featuredRank,
            )
        }
        .sortedWith(
            compareBy<GameRoomCatalogManufacturerOption> { !it.isModern }
                .thenBy { it.featuredRank ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )

    val allGames = mutableListOf<GameRoomCatalogGame>()
    val variantsByGroup = LinkedHashMap<String, MutableSet<String>>()
    val recordsByGroup = LinkedHashMap<String, MutableList<GameRoomCatalogMachineRecord>>()
    val slugMatches = LinkedHashMap<String, GameRoomCatalogSlugMatch>()
    val manufacturerBucket = linkedSetOf<String>()

    machines.forEach { machine ->
        val groupID = machine.practiceIdentity
        if (groupID.isBlank()) return@forEach
        val opdbID = machine.opdbMachineId ?: groupID
        val rawTitle = machine.name.ifBlank { "Machine" }
        val canonicalPracticeIdentity = machine.practiceIdentity.ifBlank { groupID }
        val manufacturerID = machine.manufacturerId
        val manufacturer = machine.manufacturerName
        val year = machine.year
        val parsedTitle = parseCatalogName(
            title = rawTitle,
            explicitVariant = machine.variant,
        )
        val title = parsedTitle.displayTitle
        val variant = parsedTitle.displayVariant
        val slug = machine.slug.ifBlank { canonicalPracticeIdentity }.lowercase()
        val primaryImageUrl = machine.primaryImageMediumUrl
        val primaryImageLargeUrl = machine.primaryImageLargeUrl
        val playfieldImageUrl = machine.playfieldImageMediumUrl
        val playfieldImageLargeUrl = machine.playfieldImageLargeUrl
        if (!manufacturer.isNullOrBlank()) manufacturerBucket += manufacturer
        if (!variant.isNullOrBlank()) {
            variantsByGroup.getOrPut(groupID) { linkedSetOf() }.add(variant)
        }
        recordsByGroup.getOrPut(groupID) { mutableListOf() }.add(
            GameRoomCatalogMachineRecord(
                groupID = groupID,
                opdbID = opdbID,
                practiceIdentity = canonicalPracticeIdentity,
                slug = slug,
                machineName = title,
                variant = variant,
                manufacturer = manufacturer,
                year = year,
                primaryImageUrl = primaryImageUrl,
                primaryImageLargeUrl = primaryImageLargeUrl,
                playfieldImageUrl = playfieldImageUrl,
                playfieldImageLargeUrl = playfieldImageLargeUrl,
            ),
        )

        allGames += GameRoomCatalogGame(
            catalogGameID = groupID,
            opdbID = opdbID,
            canonicalPracticeIdentity = canonicalPracticeIdentity,
            displayTitle = title,
            displayVariant = variant,
            manufacturerID = manufacturerID,
            manufacturer = manufacturer,
            year = year,
            primaryImageUrl = primaryImageUrl ?: primaryImageLargeUrl,
            opdbType = machine.opdbType,
            opdbDisplay = machine.opdbDisplay,
            opdbShortname = machine.opdbShortname,
            opdbCommonName = machine.opdbCommonName,
        )

        val slugMatch = GameRoomCatalogSlugMatch(
            catalogGameID = groupID,
            canonicalPracticeIdentity = canonicalPracticeIdentity,
            variant = variant,
        )
        buildSlugKeys(slug).forEach { key ->
            val existing = slugMatches[key]
            if (existing != null) {
                if (normalizedCatalogGameID(existing.catalogGameID) != normalizedCatalogGameID(slugMatch.catalogGameID)) {
                    Log.w(
                        GAME_ROOM_CATALOG_TAG,
                        "Duplicate GameRoom catalog slug key $key; keeping existing catalog game ${existing.catalogGameID} and ignoring ${slugMatch.catalogGameID}",
                    )
                }
            } else {
                slugMatches[key] = slugMatch
            }
        }
    }

    val gamesByCatalogGameID = allGames.groupBy { it.catalogGameID }
    val variantOptionsByCatalogGameID = variantsByGroup.mapValues { (_, values) ->
        sanitizeVariantOptions(values.toList()).sortedWith(
            compareBy<String> { gameRoomVariantPreferenceRank(it) }
                .thenBy { it.lowercase() },
        )
    }

    return GameRoomLoadedCatalogData(
        allCatalogGames = allGames,
        games = dedupedCatalogGames(allGames),
        manufacturers = manufacturerBucket.toList().sortedBy { it.lowercase() },
        manufacturerOptions = manufacturerOptions,
        gamesByCatalogGameID = gamesByCatalogGameID,
        gamesByNormalizedCatalogGameID = allGames.groupBy { normalizedCatalogGameID(it.catalogGameID) },
        variantOptionsByCatalogGameID = variantOptionsByCatalogGameID,
        variantOptionsByNormalizedCatalogGameID = variantOptionsByCatalogGameID.entries.associate { (key, values) ->
            normalizedCatalogGameID(key) to values
        },
        machineRecordsByCatalogGameID = recordsByGroup,
        slugMatchesBySlug = slugMatches,
    )
}
