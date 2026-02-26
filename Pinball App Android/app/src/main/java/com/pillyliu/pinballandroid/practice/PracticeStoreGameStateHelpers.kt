package com.pillyliu.pinballandroid.practice

import com.pillyliu.pinballandroid.library.PinballGame

internal fun activeGroupsFromList(groups: List<PracticeGroup>): List<PracticeGroup> =
    groups.filter { it.isActive && !it.isArchived }

internal fun groupGamesFromList(group: PracticeGroup, games: List<PinballGame>): List<PinballGame> {
    val map = gamesByPracticeLookupKey(games)
    return group.gameSlugs.mapNotNull { map[it] }
}

internal fun gameNameForSlug(games: List<PinballGame>, slug: String): String =
    if (slug.isBlank()) "None" else (findGameByPracticeLookupKey(games, slug)?.name ?: slug)

internal fun leagueTargetScoresForSlug(
    gameSlug: String,
    games: List<PinballGame>,
    resolver: (String) -> LeagueTargetScores?,
): LeagueTargetScores? {
    val game = findGameByPracticeLookupKey(games, gameSlug) ?: return null
    return resolver(game.name)
}

internal fun normalizedRulesheetRatio(ratio: Float): Float {
    val clamped = ratio.coerceIn(0f, 1f)
    return if (clamped >= 0.995f) 1f else clamped
}

internal fun updatedRulesheetProgress(
    current: Map<String, Float>,
    slug: String,
    ratio: Float,
): Map<String, Float> {
    return current + (slug to normalizedRulesheetRatio(ratio))
}

internal fun gameSummaryNoteForSlug(
    current: Map<String, String>,
    slug: String,
): String = current[slug].orEmpty()

internal fun updatedGameSummaryNotes(
    current: Map<String, String>,
    slug: String,
    note: String,
): Map<String, String>? {
    val key = slug.trim()
    if (key.isEmpty()) return null
    val trimmed = note.trim()
    return if (trimmed.isEmpty()) {
        current - key
    } else {
        current + (key to trimmed)
    }
}
