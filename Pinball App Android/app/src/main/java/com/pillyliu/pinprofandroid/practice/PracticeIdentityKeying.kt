package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.canonicalLibrarySourceId
import com.pillyliu.pinprofandroid.library.isAvenueLibrarySourceId
import com.pillyliu.pinprofandroid.library.isGameRoomLibrarySourceId
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.LibrarySourceType
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.normalizedVariant
import java.util.Locale

internal val PinballGame.practiceKey: String
    get() = practiceIdentity?.trim()?.takeIf { it.isNotBlank() } ?: slug

private const val SOURCE_SCOPED_PRACTICE_GAME_ID_PREFIX = "source::"

internal fun sourceScopedPracticeGameID(sourceID: String, gameID: String): String {
    val normalizedSourceID = canonicalLibrarySourceId(sourceID) ?: sourceID
    return "$SOURCE_SCOPED_PRACTICE_GAME_ID_PREFIX$normalizedSourceID::$gameID"
}

internal data class ParsedSourceScopedPracticeGameID(
    val sourceID: String?,
    val gameID: String,
)

internal fun parseSourceScopedPracticeGameID(raw: String): ParsedSourceScopedPracticeGameID {
    val trimmed = raw.trim()
    if (!trimmed.startsWith(SOURCE_SCOPED_PRACTICE_GAME_ID_PREFIX)) {
        return ParsedSourceScopedPracticeGameID(sourceID = null, gameID = trimmed)
    }
    val payload = trimmed.removePrefix(SOURCE_SCOPED_PRACTICE_GAME_ID_PREFIX)
    val parts = payload.split("::")
    if (parts.size < 2) {
        return ParsedSourceScopedPracticeGameID(sourceID = null, gameID = trimmed)
    }
    val sourceID = canonicalLibrarySourceId(parts.first()) ?: parts.first()
    val gameID = parts.drop(1).joinToString("::")
    return ParsedSourceScopedPracticeGameID(sourceID = sourceID, gameID = gameID)
}

internal val PinballGame.displayTitleForPractice: String
    get() = name

internal fun PinballGame.matchesPracticeLookupKey(value: String?): Boolean {
    val parsed = parseSourceScopedPracticeGameID(value.orEmpty())
    val key = parsed.gameID.trim()
    if (key.isBlank()) return false
    if (parsed.sourceID != null && canonicalLibrarySourceId(sourceId) != parsed.sourceID) return false
    return key == practiceKey || key == slug
}

internal fun findGameByPracticeLookupKey(games: List<PinballGame>, value: String?): PinballGame? {
    val parsed = parseSourceScopedPracticeGameID(value.orEmpty())
    val key = parsed.gameID.trim()
    if (key.isBlank()) return null
    val exactSlugMatch = games.firstOrNull {
        it.slug == key && (parsed.sourceID == null || canonicalLibrarySourceId(it.sourceId) == parsed.sourceID)
    }
    if (exactSlugMatch != null) return exactSlugMatch

    val practiceMatches = games.filter { it.practiceKey == key }
    if (practiceMatches.isNotEmpty()) {
        return preferredPracticeRepresentative(practiceMatches, preferredSourceId = parsed.sourceID)
    }

    return null
}

internal fun gamesByPracticeLookupKey(games: List<PinballGame>): Map<String, PinballGame> {
    val out = LinkedHashMap<String, PinballGame>()
    games
        .groupBy { it.practiceKey }
        .forEach { (key, grouped) ->
            preferredPracticeRepresentative(grouped)?.let { representative ->
                out[key] = representative
            }
        }
    games.forEach { game ->
        out.putIfAbsent(game.slug, game)
        out[sourceScopedPracticeGameID(game.sourceId, game.practiceKey)] = game
    }
    return out
}

internal fun distinctGamesByPracticeIdentity(games: List<PinballGame>): List<PinballGame> {
    return games
        .groupBy { it.practiceKey }
        .values
        .mapNotNull(::preferredPracticeRepresentative)
        .sortedWith(compareBy<PinballGame> { it.name.lowercase(Locale.US) }.thenBy { it.slug.lowercase(Locale.US) })
}

private val PRACTICE_IDENTITY_ALIASES: Map<String, String> = emptyMap()

internal fun canonicalPracticeKey(value: String?, games: List<PinballGame>): String {
    val parsed = parseSourceScopedPracticeGameID(value.orEmpty())
    val raw = parsed.gameID.trim()
    if (raw.isBlank()) return ""
    val aliased = PRACTICE_IDENTITY_ALIASES[raw] ?: raw
    val resolvedLookup = if (parsed.sourceID != null) {
        sourceScopedPracticeGameID(parsed.sourceID, aliased)
    } else {
        aliased
    }
    return findGameByPracticeLookupKey(games, resolvedLookup)?.practiceKey
        ?: legacyPracticeKeyMatch(games, aliased)?.practiceKey
        ?: aliased
}

internal fun canonicalizeGroupSelectionKey(value: String?, games: List<PinballGame>): String {
    val parsed = parseSourceScopedPracticeGameID(value.orEmpty())
    val resolved = findGameByPracticeLookupKey(games, value)
        ?: legacyPracticeKeyMatch(games, parsed.gameID)
        ?: return canonicalPracticeKey(value, games)
    return parsed.sourceID?.let { sourceScopedPracticeGameID(it, resolved.practiceKey) } ?: resolved.practiceKey
}

internal fun uniqueGroupSelectionIDsPreservingOrder(ids: List<String>, games: List<PinballGame>): List<String> {
    val seen = linkedSetOf<String>()
    val ordered = mutableListOf<String>()
    ids.forEach { id ->
        val normalized = canonicalizeGroupSelectionKey(id, games)
        val canonical = canonicalPracticeKey(normalized, games)
        if (canonical.isBlank() || !seen.add(canonical)) return@forEach
        ordered += normalized
    }
    return ordered
}

internal fun preferredPracticeSelectionKey(
    game: PinballGame,
    selectedSourceId: String?,
    librarySources: List<LibrarySource>,
): String {
    val selectedSource = librarySources.firstOrNull { it.id == selectedSourceId }
    return if (selectedSource?.type == LibrarySourceType.VENUE) {
        sourceScopedPracticeGameID(selectedSource.id, game.practiceKey)
    } else {
        game.practiceKey
    }
}

internal fun migratePracticeStateKeys(state: PracticePersistedState, games: List<PinballGame>): PracticePersistedState {
    fun mapKey(key: String): String = canonicalPracticeKey(key, games)
    fun mapGroupKey(key: String): String = canonicalizeGroupSelectionKey(key, games)

    val migratedGroups = state.groups.map { group ->
        group.copy(gameSlugs = uniqueGroupSelectionIDsPreservingOrder(group.gameSlugs.map(::mapGroupKey), games))
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
    fun mapGroupKey(key: String): String = canonicalizeGroupSelectionKey(key, games)

    return state.copy(
        studyEvents = state.studyEvents.map { it.copy(gameID = mapKey(it.gameID)) },
        videoProgressEntries = state.videoProgressEntries.map { it.copy(gameID = mapKey(it.gameID)) },
        scoreEntries = state.scoreEntries.map { it.copy(gameID = mapKey(it.gameID)) },
        noteEntries = state.noteEntries.map { it.copy(gameID = mapKey(it.gameID)) },
        journalEntries = state.journalEntries.map { it.copy(gameID = mapKey(it.gameID)) },
        customGroups = state.customGroups.map { group ->
            group.copy(gameIDs = uniqueGroupSelectionIDsPreservingOrder(group.gameIDs.map(::mapGroupKey), games))
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

internal fun legacyPracticeKeyMatch(games: List<PinballGame>, raw: String): PinballGame? {
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

private fun preferredPracticeRepresentative(
    games: List<PinballGame>,
    preferredSourceId: String? = null,
): PinballGame? {
    val candidateGames = preferredSourceId
        ?.let { preferred ->
            val normalizedPreferred = canonicalLibrarySourceId(preferred) ?: preferred
            games.filter { canonicalLibrarySourceId(it.sourceId) == normalizedPreferred }
                .ifEmpty { games }
        }
        ?: games
    return candidateGames.maxWithOrNull(compareBy<PinballGame>(::practiceRepresentativeScore).thenBy { it.slug })
}

private fun practiceRepresentativeScore(game: PinballGame): Int {
    var score = 0
    if (isGameRoomLibrarySourceId(game.sourceId)) score += 600
    if (game.area != null || game.group != null || game.position != null) score += 260
    if ((game.bank ?: 0) > 0) score += 240
    if (isAvenueLibrarySourceId(game.sourceId)) score += 180
    if (game.sourceType.name == "VENUE") score += 120
    if (game.name.contains(":")) score += 120
    if (!game.normalizedVariant.isNullOrBlank()) score += 100
    if (game.normalizedVariant?.contains("anniversary", ignoreCase = true) == true) score += 120
    if (!game.primaryImageLargeUrl.isNullOrBlank() || !game.primaryImageUrl.isNullOrBlank()) score += 60
    if (game.year != null) score += game.year
    score += game.name.length
    return score
}
