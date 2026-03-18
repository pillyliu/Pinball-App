package com.pillyliu.pinprofandroid.gameroom

import com.pillyliu.pinprofandroid.library.matchesSearchTokens
import com.pillyliu.pinprofandroid.library.normalizedSearchTokens

internal enum class GameRoomAddMachineTypeFilter(val rawValue: String, val label: String) {
    EM("em", "EM"),
    SS("ss", "SS"),
    LCD("lcd", "LCD"),
}

internal data class GameRoomCatalogSearchEntry(
    val game: GameRoomCatalogGame,
    val searchTokens: List<String>,
    val manufacturerTokens: List<String>,
)

internal fun gameRoomManufacturerSuggestions(
    options: List<String>,
    query: String,
): List<String> {
    val trimmed = query.trim()
    if (trimmed.isBlank()) return emptyList()
    val queryTokens = normalizedSearchTokens(trimmed)
    return options.filter { option ->
        matchesSearchTokens(queryTokens, normalizedSearchTokens(option))
    }.take(8)
}

internal fun buildGameRoomCatalogSearchEntries(
    games: List<GameRoomCatalogGame>,
    variantOptions: (String) -> List<String>,
): List<GameRoomCatalogSearchEntry> {
    return games.map { game ->
        val searchTokens = buildList {
            addAll(normalizedSearchTokens(game.displayTitle))
            addAll(normalizedSearchTokens(game.displayVariant.orEmpty()))
            addAll(normalizedSearchTokens(game.opdbShortname.orEmpty()))
            addAll(normalizedSearchTokens(game.opdbCommonName.orEmpty()))
            addAll(normalizedSearchTokens(game.manufacturer.orEmpty()))
            variantOptions(game.catalogGameID).forEach { variant ->
                addAll(normalizedSearchTokens(variant))
            }
        }
        GameRoomCatalogSearchEntry(
            game = game,
            searchTokens = searchTokens,
            manufacturerTokens = normalizedSearchTokens(game.manufacturer.orEmpty()),
        )
    }
}

internal fun filterGameRoomCatalogGames(
    entries: List<GameRoomCatalogSearchEntry>,
    nameQuery: String,
    manufacturerQuery: String,
    yearQuery: String,
    selectedType: GameRoomAddMachineTypeFilter?,
): List<GameRoomCatalogGame> {
    val nameTokens = normalizedSearchTokens(nameQuery.trim())
    val manufacturerTokens = normalizedSearchTokens(manufacturerQuery.trim())
    val targetYear = yearQuery.trim().toIntOrNull()
    return entries.mapNotNull { entry ->
        val game = entry.game
        val matchesName = nameTokens.isEmpty() || matchesSearchTokens(nameTokens, entry.searchTokens)
        val matchesManufacturer = manufacturerTokens.isEmpty() || matchesSearchTokens(manufacturerTokens, entry.manufacturerTokens)
        val matchesYear = targetYear == null || game.year == targetYear
        val matchesType = selectedType == null || gameRoomSearchCategory(game) == selectedType.rawValue
        if (matchesName && matchesManufacturer && matchesYear && matchesType) game else null
    }
}

internal fun gameRoomSearchCategory(game: GameRoomCatalogGame): String? {
    return when {
        game.opdbDisplay == GameRoomAddMachineTypeFilter.LCD.rawValue -> GameRoomAddMachineTypeFilter.LCD.rawValue
        game.opdbType == GameRoomAddMachineTypeFilter.EM.rawValue -> GameRoomAddMachineTypeFilter.EM.rawValue
        game.opdbType == GameRoomAddMachineTypeFilter.SS.rawValue -> GameRoomAddMachineTypeFilter.SS.rawValue
        else -> null
    }
}
