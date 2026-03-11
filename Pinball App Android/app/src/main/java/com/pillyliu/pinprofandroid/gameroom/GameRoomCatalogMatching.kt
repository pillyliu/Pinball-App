package com.pillyliu.pinprofandroid.gameroom

import com.pillyliu.pinprofandroid.library.matchesSearchQuery
import java.text.Normalizer
import java.util.Locale

internal fun gameRoomCatalogMatchesSearch(
    game: GameRoomCatalogGame,
    query: String,
    variantAliases: List<String> = emptyList(),
): Boolean {
    return matchesSearchQuery(query, gameRoomCatalogSearchFields(game, variantAliases))
}

internal fun gameRoomCatalogSearchHaystack(
    game: GameRoomCatalogGame,
    variantAliases: List<String> = emptyList(),
): String =
    gameRoomCatalogSearchFields(game, variantAliases)
        .filterNotNull()
        .joinToString(" ")

private fun gameRoomCatalogSearchFields(
    game: GameRoomCatalogGame,
    variantAliases: List<String>,
): List<String?> =
    listOfNotNull(
        game.displayTitle,
        game.displayVariant,
        game.manufacturer,
        game.year?.toString(),
    ) + variantAliases

internal fun preferredCatalogGame(games: List<GameRoomCatalogGame>): GameRoomCatalogGame? =
    games.minWithOrNull(::comparePreferredCatalogGame)

internal fun dedupedCatalogGames(games: List<GameRoomCatalogGame>): List<GameRoomCatalogGame> =
    games.groupBy { it.catalogGameID }
        .values
        .mapNotNull(::preferredCatalogGame)
        .sortedWith(::compareSortedCatalogGames)

internal fun comparePreferredCatalogGame(
    lhs: GameRoomCatalogGame,
    rhs: GameRoomCatalogGame,
): Int {
    val lhsYear = lhs.year ?: Int.MAX_VALUE
    val rhsYear = rhs.year ?: Int.MAX_VALUE
    if (lhsYear != rhsYear) return lhsYear.compareTo(rhsYear)

    val lhsRank = gameRoomVariantPreferenceRank(lhs.displayVariant)
    val rhsRank = gameRoomVariantPreferenceRank(rhs.displayVariant)
    if (lhsRank != rhsRank) return lhsRank.compareTo(rhsRank)

    val lhsHasImage = lhs.primaryImageUrl != null
    val rhsHasImage = rhs.primaryImageUrl != null
    if (lhsHasImage != rhsHasImage) return if (lhsHasImage) -1 else 1

    return catalogGameTieBreakKey(lhs).compareTo(catalogGameTieBreakKey(rhs))
}

internal fun compareSortedCatalogGames(
    lhs: GameRoomCatalogGame,
    rhs: GameRoomCatalogGame,
): Int {
    val lhsName = lhs.displayTitle.lowercase(Locale.getDefault())
    val rhsName = rhs.displayTitle.lowercase(Locale.getDefault())
    if (lhsName != rhsName) return lhsName.compareTo(rhsName)

    val lhsVariant = lhs.displayVariant?.lowercase(Locale.getDefault()).orEmpty()
    val rhsVariant = rhs.displayVariant?.lowercase(Locale.getDefault()).orEmpty()
    if (lhsVariant != rhsVariant) return lhsVariant.compareTo(rhsVariant)

    val lhsManufacturer = lhs.manufacturer?.lowercase(Locale.getDefault()).orEmpty()
    val rhsManufacturer = rhs.manufacturer?.lowercase(Locale.getDefault()).orEmpty()
    if (lhsManufacturer != rhsManufacturer) return lhsManufacturer.compareTo(rhsManufacturer)

    val lhsYear = lhs.year ?: Int.MAX_VALUE
    val rhsYear = rhs.year ?: Int.MAX_VALUE
    if (lhsYear != rhsYear) return lhsYear.compareTo(rhsYear)

    return catalogGameTieBreakKey(lhs).compareTo(catalogGameTieBreakKey(rhs))
}

internal fun gameRoomVariantPreferenceRank(value: String?): Int {
    val normalized = value?.trim()?.takeIf { it.isNotEmpty() }?.lowercase(Locale.getDefault()) ?: return 80
    return when {
        normalized == "premium" || normalized.contains("premium") -> 0
        normalized == "le" || normalized.contains("limited") -> 1
        normalized == "pro" || normalized.contains("pro") -> 2
        normalized.contains("standard") -> 10
        normalized.contains("anniversary") -> 40
        normalized.contains("home") -> 50
        else -> 20
    }
}

internal fun normalizeGameRoomImportText(value: String): String {
    val folded = Normalizer.normalize(value, Normalizer.Form.NFD)
        .replace(Regex("\\p{M}+"), "")
    return folded
        .lowercase(Locale.getDefault())
        .replace(Regex("[^a-z0-9 ]"), " ")
        .replace(Regex("\\s+"), " ")
        .trim()
}

private fun catalogGameTieBreakKey(game: GameRoomCatalogGame): String =
    listOf(
        game.catalogGameID,
        game.canonicalPracticeIdentity,
        game.displayTitle,
        game.displayVariant.orEmpty(),
    ).joinToString("|").lowercase(Locale.getDefault())
