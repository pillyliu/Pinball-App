package com.pillyliu.pinballandroid.practice

import com.pillyliu.pinballandroid.library.PinballGame
import java.util.Locale

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
    return findGameByPracticeLookupKey(games, aliased)?.practiceKey
        ?: legacyPracticeKeyMatch(games, aliased)?.practiceKey
        ?: aliased
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

internal fun migrateCanonicalPracticeStateKeys(
    state: CanonicalPracticePersistedState,
    games: List<PinballGame>,
): CanonicalPracticePersistedState {
    fun mapKey(key: String): String = canonicalPracticeKey(key, games)

    return state.copy(
        studyEvents = state.studyEvents.map { it.copy(gameID = mapKey(it.gameID)) },
        videoProgressEntries = state.videoProgressEntries.map { it.copy(gameID = mapKey(it.gameID)) },
        scoreEntries = state.scoreEntries.map { it.copy(gameID = mapKey(it.gameID)) },
        noteEntries = state.noteEntries.map { it.copy(gameID = mapKey(it.gameID)) },
        journalEntries = state.journalEntries.map { it.copy(gameID = mapKey(it.gameID)) },
        customGroups = state.customGroups.map { group ->
            group.copy(gameIDs = group.gameIDs.map(::mapKey).filter { it.isNotBlank() }.distinct())
        },
        rulesheetResumeOffsets = state.rulesheetResumeOffsets
            .mapKeys { (key, _) -> mapKey(key) }
            .filterKeys { it.isNotBlank() },
        videoResumeHints = state.videoResumeHints
            .mapKeys { (key, _) -> mapKey(key) }
            .filterKeys { it.isNotBlank() },
        gameSummaryNotes = state.gameSummaryNotes
            .mapKeys { (key, _) -> mapKey(key) }
            .filterKeys { it.isNotBlank() },
    )
}

private fun legacyPracticeKeyMatch(games: List<PinballGame>, raw: String): PinballGame? {
    extractLikelyOpdbGroup(raw)?.let { token ->
        games.firstOrNull { it.practiceKey.equals(token, ignoreCase = true) }?.let { return it }
    }
    val normalized = normalizedLegacyGameKey(raw)
    if (normalized.isBlank()) return null
    return games.firstOrNull { normalizedLegacyGameKey(it.slug) == normalized }
        ?: games.firstOrNull { normalizedLegacyGameKey(it.practiceKey) == normalized }
}

private fun extractLikelyOpdbGroup(raw: String): String? {
    val match = Regex("\\bG[0-9A-Za-z]{4,}\\b", RegexOption.IGNORE_CASE).find(raw) ?: return null
    return match.value
}

private fun normalizedLegacyGameKey(raw: String): String =
    raw.trim()
        .lowercase(Locale.US)
        .replace("&", "and")
        .replace(Regex("[^a-z0-9]+"), "-")
        .trim('-')
