package com.pillyliu.pinprofandroid.practice

import android.content.SharedPreferences
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.matchesSearchTokens
import com.pillyliu.pinprofandroid.library.normalizedSearchTokens
import java.util.Locale

internal const val KEY_PRACTICE_SEARCH_RECENTS = "practice-search-recents-v1"
internal const val PRACTICE_SEARCH_MAX_RECENTS = 20

internal enum class PracticeSearchTypeFilter(val rawValue: String, val label: String) {
    EM("em", "EM"),
    SS("ss", "SS"),
    LCD("lcd", "LCD"),
}

internal data class PracticeSearchResult(
    val canonicalGameId: String,
    val displayName: String,
    val manufacturer: String?,
    val year: Int?,
    val searchTokens: List<String>,
    val manufacturerTokens: List<String>,
    val categoryFields: List<String>,
    val yearFields: List<Int>,
)

internal fun practiceManufacturerSuggestions(
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

internal fun filterPracticeSearchResults(
    results: List<PracticeSearchResult>,
    nameQuery: String,
    manufacturerQuery: String,
    yearQuery: String,
    selectedType: PracticeSearchTypeFilter?,
): List<PracticeSearchResult> {
    val targetYear = yearQuery.trim().toIntOrNull()
    val nameTokens = normalizedSearchTokens(nameQuery)
    val manufacturerTokens = normalizedSearchTokens(manufacturerQuery.trim())
    return results.filter { result ->
        val matchesName = nameTokens.isEmpty() || matchesSearchTokens(nameTokens, result.searchTokens)
        val matchesManufacturer = manufacturerTokens.isEmpty() || matchesSearchTokens(manufacturerTokens, result.manufacturerTokens)
        val matchesYear = targetYear == null || result.yearFields.contains(targetYear)
        val matchesType = selectedType == null || result.categoryFields.any { it == selectedType.rawValue }
        matchesName && matchesManufacturer && matchesYear && matchesType
    }
}

internal fun buildPracticeSearchResults(games: List<PinballGame>): List<PracticeSearchResult> {
    return games
        .groupBy { it.practiceKey }
        .mapNotNull { (canonicalGameId, groupedGames) ->
            if (canonicalGameId.isBlank()) return@mapNotNull null
            val displayName = practiceDisplayTitleForGames(groupedGames)
            val manufacturer = practiceSearchManufacturer(groupedGames)
            val year = practiceSearchYear(groupedGames)
            PracticeSearchResult(
                canonicalGameId = canonicalGameId,
                displayName = displayName,
                manufacturer = manufacturer,
                year = year,
                searchTokens = groupedGames.flatMap { game ->
                    listOf(
                        displayName,
                        game.name,
                        game.opdbName,
                        game.opdbShortname,
                        game.opdbCommonName,
                        game.opdbGroupShortname,
                    )
                }.flatMap { normalizedSearchTokens(it.orEmpty()) },
                manufacturerTokens = groupedGames
                    .mapNotNull { it.manufacturer?.trim()?.takeIf(String::isNotBlank) }
                    .flatMap(::normalizedSearchTokens),
                categoryFields = groupedGames.mapNotNull(::practiceSearchCategory).distinct(),
                yearFields = groupedGames.mapNotNull { game ->
                    game.year ?: practiceSearchYear(game.opdbManufactureDate)
                },
            )
        }
        .sortedWith(compareBy<PracticeSearchResult> { it.displayName.lowercase(Locale.US) }.thenBy { it.canonicalGameId.lowercase(Locale.US) })
}

internal fun buildPracticeSearchMetaLine(result: PracticeSearchResult): String {
    val parts = mutableListOf(result.manufacturer ?: "-")
    result.year?.let { parts += it.toString() }
    return parts.joinToString(" • ")
}

internal fun loadPracticeSearchRecents(prefs: SharedPreferences): List<String> {
    return prefs.getString(KEY_PRACTICE_SEARCH_RECENTS, null)
        ?.split('\n')
        ?.map { it.trim() }
        ?.filter { it.isNotBlank() }
        ?: emptyList()
}

internal fun rememberPracticeSearchRecent(
    prefs: SharedPreferences,
    canonicalGameId: String,
) {
    val trimmed = canonicalGameId.trim()
    if (trimmed.isBlank()) return
    val updated = buildList {
        add(trimmed)
        loadPracticeSearchRecents(prefs).forEach { existing ->
            if (!existing.equals(trimmed, ignoreCase = true)) {
                add(existing)
            }
        }
    }.take(PRACTICE_SEARCH_MAX_RECENTS)
    prefs.edit().putString(KEY_PRACTICE_SEARCH_RECENTS, updated.joinToString("\n")).apply()
}

private fun practiceSearchManufacturer(games: List<PinballGame>): String? {
    return games.mapNotNull { it.manufacturer?.trim()?.takeIf(String::isNotBlank) }
        .distinctBy { it.lowercase(Locale.US) }
        .sortedBy { it.lowercase(Locale.US) }
        .firstOrNull()
}

private fun practiceSearchYear(games: List<PinballGame>): Int? {
    return games.mapNotNull { it.year ?: practiceSearchYear(it.opdbManufactureDate) }
        .sorted()
        .firstOrNull()
}

private fun practiceSearchYear(raw: String?): Int? {
    val trimmed = raw?.trim().orEmpty()
    if (trimmed.length < 4) return null
    return trimmed.take(4).toIntOrNull()
}

private fun practiceSearchCategory(game: PinballGame): String? {
    return when {
        game.opdbDisplay == PracticeSearchTypeFilter.LCD.rawValue -> PracticeSearchTypeFilter.LCD.rawValue
        game.opdbType == PracticeSearchTypeFilter.EM.rawValue -> PracticeSearchTypeFilter.EM.rawValue
        game.opdbType == PracticeSearchTypeFilter.SS.rawValue -> PracticeSearchTypeFilter.SS.rawValue
        else -> null
    }
}
