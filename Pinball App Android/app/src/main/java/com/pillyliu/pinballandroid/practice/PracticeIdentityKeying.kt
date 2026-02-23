package com.pillyliu.pinballandroid.practice

import com.pillyliu.pinballandroid.library.PinballGame

internal val PinballGame.practiceKey: String
    get() = practiceIdentity?.trim()?.takeIf { it.isNotBlank() } ?: slug

internal val PinballGame.displayTitleForPractice: String
    get() = name

internal fun PinballGame.matchesPracticeLookupKey(value: String?): Boolean {
    val key = value?.trim().orEmpty()
    if (key.isBlank()) return false
    return key == practiceKey || key == slug
}

internal fun findGameByPracticeLookupKey(games: List<PinballGame>, value: String?): PinballGame? {
    val key = value?.trim().orEmpty()
    if (key.isBlank()) return null
    return games.firstOrNull { it.practiceKey == key }
        ?: games.firstOrNull { it.slug == key }
}

internal fun gamesByPracticeLookupKey(games: List<PinballGame>): Map<String, PinballGame> {
    val out = LinkedHashMap<String, PinballGame>()
    games.forEach { game ->
        out.putIfAbsent(game.practiceKey, game)
        out.putIfAbsent(game.slug, game)
    }
    return out
}

internal fun distinctGamesByPracticeIdentity(games: List<PinballGame>): List<PinballGame> {
    val seen = LinkedHashSet<String>()
    val out = ArrayList<PinballGame>(games.size)
    games.forEach { game ->
        val key = game.practiceKey
        if (seen.add(key)) out += game
    }
    return out
}

private val PRACTICE_IDENTITY_ALIASES: Map<String, String> = emptyMap()

internal fun canonicalPracticeKey(value: String?, games: List<PinballGame>): String {
    val raw = value?.trim().orEmpty()
    if (raw.isBlank()) return ""
    val aliased = PRACTICE_IDENTITY_ALIASES[raw] ?: raw
    return findGameByPracticeLookupKey(games, aliased)?.practiceKey ?: aliased
}

internal fun migratePracticeStateKeys(state: PracticePersistedState, games: List<PinballGame>): PracticePersistedState {
    fun mapKey(key: String): String = canonicalPracticeKey(key, games)

    val migratedGroups = state.groups.map { group ->
        group.copy(gameSlugs = group.gameSlugs.map(::mapKey).filter { it.isNotBlank() }.distinct())
    }
    val migratedScores = state.scores.map { it.copy(gameSlug = mapKey(it.gameSlug)) }
    val migratedNotes = state.notes.map { it.copy(gameSlug = mapKey(it.gameSlug)) }
    val migratedJournal = state.journal.map { it.copy(gameSlug = mapKey(it.gameSlug)) }
    val migratedRulesheetProgress = state.rulesheetProgress
        .mapKeys { (key, _) -> mapKey(key) }
        .filterKeys { it.isNotBlank() }
    val migratedGameSummaryNotes = state.gameSummaryNotes
        .mapKeys { (key, _) -> mapKey(key) }
        .filterKeys { it.isNotBlank() }

    return state.copy(
        groups = migratedGroups,
        scores = migratedScores,
        notes = migratedNotes,
        journal = migratedJournal,
        rulesheetProgress = migratedRulesheetProgress,
        gameSummaryNotes = migratedGameSummaryNotes,
    )
}
