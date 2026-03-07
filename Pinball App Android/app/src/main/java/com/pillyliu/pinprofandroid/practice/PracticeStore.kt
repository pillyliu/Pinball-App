package com.pillyliu.pinprofandroid.practice

import android.content.Context
import androidx.core.content.edit
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.pillyliu.pinprofandroid.library.LibraryActivityLog
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore
import com.pillyliu.pinprofandroid.library.PinballGame
import java.util.UUID

internal class PracticeStore(private val context: Context) {
    private companion object {
        val QUICK_GAME_PREF_KEYS = listOf(
            "practice-quick-game-score",
            "practice-quick-game-study",
            "practice-quick-game-practice",
            "practice-quick-game-mechanics",
        )
    }

    var didLoad by mutableStateOf(false)
        private set

    var games by mutableStateOf<List<PinballGame>>(emptyList())
        private set

    var allLibraryGames by mutableStateOf<List<PinballGame>>(emptyList())
        private set

    var librarySources by mutableStateOf<List<LibrarySource>>(emptyList())
        private set

    var defaultPracticeSourceId by mutableStateOf<String?>(null)
        private set

    var groups by mutableStateOf<List<PracticeGroup>>(emptyList())
        private set

    var scores by mutableStateOf<List<ScoreEntry>>(emptyList())
        private set

    var notes by mutableStateOf<List<NoteEntry>>(emptyList())
        private set

    var journal by mutableStateOf<List<JournalEntry>>(emptyList())
        private set

    var playerName by mutableStateOf("")
        private set

    var ifpaPlayerID by mutableStateOf("")
        private set

    var comparisonPlayerName by mutableStateOf("")
        private set

    var leaguePlayerName by mutableStateOf("")
        private set

    var cloudSyncEnabled by mutableStateOf(false)
        private set

    var selectedGroupID by mutableStateOf<String?>(null)
        private set

    var rulesheetProgress by mutableStateOf<Map<String, Float>>(emptyMap())
        private set

    var gameSummaryNotes by mutableStateOf<Map<String, String>>(emptyMap())
        private set

    private var rulesheetResumeOffsets: Map<String, Double> = emptyMap()
    private var canonicalPersistedState: CanonicalPracticePersistedState = emptyCanonicalPracticePersistedState()
    private val leagueIntegration by lazy { PracticeLeagueIntegration(::gameName) }
    private val journalIntegration by lazy { PracticeJournalIntegration(::practiceLookupGames, ::gameName) }

    private val prefs by lazy { context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE) }

    private inline fun mutateAndSave(update: () -> Unit) {
        update()
        saveState()
    }

    private fun practiceLookupGames(): List<PinballGame> =
        if (allLibraryGames.isNotEmpty()) allLibraryGames else games

    private fun applyPersistedState(payload: ParsedPracticeStatePayload) {
        canonicalPersistedState = payload.canonical
        rulesheetResumeOffsets = payload.canonical.rulesheetResumeOffsets
        applyRuntimePersistedState(payload.runtime)
    }

    private fun applyRuntimePersistedState(state: PracticePersistedState) {
        playerName = state.playerName
        ifpaPlayerID = state.ifpaPlayerID
        comparisonPlayerName = state.comparisonPlayerName
        leaguePlayerName = state.leaguePlayerName
        cloudSyncEnabled = state.cloudSyncEnabled
        selectedGroupID = state.selectedGroupID
        groups = state.groups
        scores = state.scores
        notes = state.notes
        journal = state.journal
        rulesheetProgress = state.rulesheetProgress
        gameSummaryNotes = state.gameSummaryNotes
    }

    suspend fun loadIfNeeded() {
        if (didLoad) return
        didLoad = true
        loadGames()
        loadState()
        migrateLoadedStateToPracticeKeys()
        migratePreferenceGameKeysToPracticeKeys()
        leagueIntegration.loadTargets()
    }

    fun updatePlayerName(name: String) {
        mutateAndSave { playerName = name.trim() }
    }

    fun updateIfpaPlayerID(value: String) {
        mutateAndSave { ifpaPlayerID = value.trim() }
    }

    fun updateComparisonPlayerName(name: String) {
        mutateAndSave { comparisonPlayerName = name.trim() }
    }

    fun updateLeaguePlayerName(name: String) {
        mutateAndSave { leaguePlayerName = name.trim() }
    }

    fun updateCloudSyncEnabled(enabled: Boolean) {
        mutateAndSave { cloudSyncEnabled = enabled }
    }

    fun setSelectedGroup(id: String?) {
        mutateAndSave { selectedGroupID = id }
    }

    fun selectedGroup(): PracticeGroup? {
        return selectCurrentGroup(groups, selectedGroupID)
    }

    fun createGroup(
        name: String,
        gameSlugs: List<String>,
        isActive: Boolean,
        isPriority: Boolean,
        type: String = "custom",
        startDateMs: Long? = null,
        endDateMs: Long? = null,
        isArchived: Boolean = false,
        insertAt: Int? = null,
    ): String? {
        val result = createGroupInList(
            existing = groups,
            selectedGroupID = selectedGroupID,
            name = name,
            gameSlugs = gameSlugs,
            isActive = isActive,
            isPriority = isPriority,
            type = type,
            startDateMs = startDateMs,
            endDateMs = endDateMs,
            isArchived = isArchived,
            insertAt = insertAt,
            nowMs = System.currentTimeMillis(),
        ) ?: return null
        groups = result.groups
        selectedGroupID = result.selectedGroupID
        saveState()
        return result.createdId
    }

    fun updateGroup(updated: PracticeGroup) {
        groups = updateGroupInList(groups, updated)
        saveState()
    }

    fun removeGameFromGroup(groupID: String, gameSlug: String) {
        val next = removeGameFromGroupInList(groups, groupID, gameSlug)
        if (next == groups) return
        groups = next
        saveState()
    }

    fun moveGroup(groupID: String, up: Boolean) {
        val next = moveGroupInList(groups, groupID, up)
        if (next == groups) return
        groups = next
        saveState()
    }

    fun deleteGroup(groupID: String) {
        val result = deleteGroupFromList(groups, selectedGroupID, groupID)
        groups = result.groups
        selectedGroupID = result.selectedGroupID
        saveState()
    }

    fun addScore(gameSlug: String, score: Double, context: String, timestampMs: Long = System.currentTimeMillis(), leagueImported: Boolean = false) {
        val canonicalKey = canonicalPracticeKey(gameSlug, practiceLookupGames())
        if (canonicalKey.isBlank()) return
        val (scoreContext, tournamentName) = splitCanonicalScoreContext(context)
        val scoreEntry = CanonicalScoreLogEntry(
            id = UUID.randomUUID().toString(),
            gameID = canonicalKey,
            score = score,
            context = scoreContext,
            tournamentName = tournamentName,
            timestampMs = timestampMs,
            leagueImported = leagueImported,
        )
        val journalEntry = CanonicalJournalEntry(
            id = UUID.randomUUID().toString(),
            gameID = canonicalKey,
            action = "scoreLogged",
            task = null,
            progressPercent = null,
            videoKind = null,
            videoValue = null,
            score = score,
            scoreContext = scoreContext,
            tournamentName = tournamentName,
            noteCategory = null,
            noteDetail = null,
            note = null,
            timestampMs = timestampMs,
        )
        canonicalPersistedState = canonicalPersistedState.copy(
            scoreEntries = canonicalPersistedState.scoreEntries + scoreEntry,
            journalEntries = canonicalPersistedState.journalEntries + journalEntry,
        )
        refreshRuntimeFromCanonical()
        markPracticeViewedGame(canonicalKey)
        saveState()
    }

    fun addStudy(gameSlug: String, category: String, value: String, note: String? = null) {
        val canonicalKey = canonicalPracticeKey(gameSlug, practiceLookupGames())
        if (canonicalKey.isBlank()) return
        val timestampMs = System.currentTimeMillis()
        val normalizedCategory = category.trim().lowercase()
        val trimmedValue = value.trim()
        if (trimmedValue.isBlank()) return
        val trimmedNote = note?.trim()?.ifBlank { null }
        val action = when (normalizedCategory) {
            "rulesheet" -> "rulesheetRead"
            "tutorial" -> "tutorialWatch"
            "gameplay" -> "gameplayWatch"
            "playfield" -> "playfieldViewed"
            "practice" -> "practiceSession"
            else -> if (normalizedCategory == "practice") "practiceSession" else "rulesheetRead"
        }
        val task = when (normalizedCategory) {
            "rulesheet" -> "rulesheet"
            "tutorial" -> "tutorialVideo"
            "gameplay" -> "gameplayVideo"
            "playfield" -> "playfield"
            "practice" -> "practice"
            else -> if (normalizedCategory == "practice") "practice" else "rulesheet"
        }
        val progressPercent = Regex("""(\d{1,3})\s*%?""").find(trimmedValue)?.groupValues?.getOrNull(1)?.toIntOrNull()?.coerceIn(0, 100)
            ?.takeIf { normalizedCategory == "rulesheet" || normalizedCategory == "tutorial" || normalizedCategory == "gameplay" }
        val videoKind = if (normalizedCategory == "tutorial" || normalizedCategory == "gameplay") {
            if (trimmedValue.contains(":")) "clock" else "percent"
        } else {
            null
        }
        val videoValue = if (normalizedCategory == "tutorial" || normalizedCategory == "gameplay") trimmedValue else null
        val journalNote = when (normalizedCategory) {
            "practice" -> trimmedNote ?: trimmedValue
            else -> trimmedNote
        }
        val studyEvent = progressPercent?.let {
            CanonicalStudyProgressEvent(
                id = UUID.randomUUID().toString(),
                gameID = canonicalKey,
                task = task,
                progressPercent = it,
                timestampMs = timestampMs,
            )
        }
        val videoEntry = if (!videoValue.isNullOrBlank()) {
            CanonicalVideoProgressEntry(
                id = UUID.randomUUID().toString(),
                gameID = canonicalKey,
                kind = videoKind ?: "percent",
                value = videoValue,
                timestampMs = timestampMs,
            )
        } else null
        val journalEntry = CanonicalJournalEntry(
            id = UUID.randomUUID().toString(),
            gameID = canonicalKey,
            action = action,
            task = task,
            progressPercent = progressPercent,
            videoKind = videoKind,
            videoValue = videoValue,
            score = null,
            scoreContext = null,
            tournamentName = null,
            noteCategory = null,
            noteDetail = null,
            note = journalNote,
            timestampMs = timestampMs,
        )
        canonicalPersistedState = canonicalPersistedState.copy(
            studyEvents = canonicalPersistedState.studyEvents + listOfNotNull(studyEvent),
            videoProgressEntries = canonicalPersistedState.videoProgressEntries + listOfNotNull(videoEntry),
            journalEntries = canonicalPersistedState.journalEntries + journalEntry,
        )
        refreshRuntimeFromCanonical()
        markPracticeViewedGame(canonicalKey)
        saveState()
    }

    fun addPracticeNote(gameSlug: String, category: String, detail: String?, note: String) {
        val canonicalKey = canonicalPracticeKey(gameSlug, practiceLookupGames())
        if (canonicalKey.isBlank()) return
        val trimmedNote = note.trim()
        if (trimmedNote.isBlank()) return
        val timestampMs = System.currentTimeMillis()
        val normalizedCategory = category.trim().ifBlank { "general" }
        val noteEntry = CanonicalPracticeNoteEntry(
            id = UUID.randomUUID().toString(),
            gameID = canonicalKey,
            category = normalizedCategory,
            detail = detail?.trim()?.ifBlank { null },
            note = trimmedNote,
            timestampMs = timestampMs,
        )
        val journalEntry = CanonicalJournalEntry(
            id = UUID.randomUUID().toString(),
            gameID = canonicalKey,
            action = "noteAdded",
            task = null,
            progressPercent = null,
            videoKind = null,
            videoValue = null,
            score = null,
            scoreContext = null,
            tournamentName = null,
            noteCategory = normalizedCategory,
            noteDetail = noteEntry.detail,
            note = trimmedNote,
            timestampMs = timestampMs,
        )
        canonicalPersistedState = canonicalPersistedState.copy(
            noteEntries = canonicalPersistedState.noteEntries + noteEntry,
            journalEntries = canonicalPersistedState.journalEntries + journalEntry,
        )
        refreshRuntimeFromCanonical()
        markPracticeViewedGame(canonicalKey)
        saveState()
    }

    fun journalItems(filter: JournalFilter): List<JournalEntry> = journalIntegration.items(journal, filter)

    fun canEditJournalEntry(entry: JournalEntry): Boolean = journalIntegration.canEdit(entry)

    fun journalEditDraft(entry: JournalEntry): PracticeJournalEditDraft? =
        journalIntegration.editDraft(entry, canonicalPersistedState, scores, notes)

    fun updateJournalEntry(draft: PracticeJournalEditDraft): Boolean {
        canonicalPersistedState = journalIntegration.updateEntry(canonicalPersistedState, draft) ?: return false

        refreshRuntimeFromCanonical()
        saveState()
        return true
    }

    fun deleteJournalEntry(entryId: String): Boolean {
        canonicalPersistedState = journalIntegration.deleteEntry(canonicalPersistedState, journal, entryId) ?: return false
        refreshRuntimeFromCanonical()
        saveState()
        return true
    }

    fun scoreValuesFor(gameSlug: String): List<Double> =
        scoreValuesForGame(scores, canonicalPracticeKey(gameSlug, practiceLookupGames()))

    fun scoreTrendValues(gameSlug: String, limit: Int = 24): List<Double> =
        scoreTrendValuesForGame(scores, canonicalPracticeKey(gameSlug, practiceLookupGames()), limit)

    fun scoreSummaryFor(gameSlug: String): ScoreSummary? = computeScoreSummaryForGame(scores, canonicalPracticeKey(gameSlug, practiceLookupGames()))

    fun groupDashboardScore(group: PracticeGroup): GroupDashboardScore =
        computeGroupDashboardScore(group, games, scores, journal, rulesheetProgress)

    fun recommendedGame(group: PracticeGroup): PinballGame? =
        computeRecommendedGame(group, games, scores, journal, rulesheetProgress)

    fun taskProgressForGame(gameSlug: String, group: PracticeGroup? = null): Map<String, Int> =
        computeTaskProgressForGame(
            journal = journal,
            rulesheetProgress = rulesheetProgress,
            gameSlug = canonicalPracticeKey(gameSlug, practiceLookupGames()),
            startDateMs = group?.startDateMs,
            endDateMs = group?.endDateMs,
        )

    fun mechanicsSkills(): List<String> = defaultMechanicsSkills()

    fun detectedMechanicsTags(text: String): List<String> = detectMechanicsTags(text, mechanicsSkills())

    fun allTrackedMechanicsSkills(): List<String> = trackedMechanicsSkills(notes, mechanicsSkills())

    fun mechanicsSummary(skill: String): MechanicsSkillSummary =
        mechanicsSummaryForSkill(skill, notes, mechanicsSkills())

    fun mechanicsLogs(skill: String): List<NoteEntry> =
        mechanicsLogsForSkill(skill, notes, mechanicsSkills())

    fun activeGroups(): List<PracticeGroup> {
        return activeGroupsFromList(groups)
    }

    fun activeGroupForGame(gameSlug: String): PracticeGroup? {
        return activeGroupForGame(groups, canonicalPracticeKey(gameSlug, practiceLookupGames()))
    }

    fun groupGames(group: PracticeGroup): List<PinballGame> {
        val primary = games
        val fallback = practiceLookupGames()
        return group.gameSlugs.mapNotNull { key ->
            findGameByPracticeLookupKey(primary, key) ?: findGameByPracticeLookupKey(fallback, key)
        }
    }

    fun gameName(slug: String): String = gameNameForSlug(practiceLookupGames(), canonicalPracticeKey(slug, practiceLookupGames()))

    fun leagueTargetScoresFor(gameSlug: String): LeagueTargetScores? =
        leagueIntegration.targetScoresFor(
            gameSlug = canonicalPracticeKey(gameSlug, practiceLookupGames()),
            games = practiceLookupGames(),
        )

    fun saveRulesheetProgress(slug: String, ratio: Float) {
        val canonicalKey = canonicalPracticeKey(slug, practiceLookupGames())
        mutateAndSave {
            rulesheetResumeOffsets = updatedRulesheetProgress(
                rulesheetResumeOffsets.mapValues { it.value.toFloat() },
                canonicalKey,
                ratio,
            ).mapValues { it.value.toDouble() }
        }
    }

    fun rulesheetSavedProgress(slug: String): Float =
        (rulesheetResumeOffsets[canonicalPracticeKey(slug, practiceLookupGames())] ?: 0.0).toFloat()

    fun gameSummaryNoteFor(slug: String): String = gameSummaryNoteForSlug(gameSummaryNotes, canonicalPracticeKey(slug, practiceLookupGames()))

    fun updateGameSummaryNote(slug: String, note: String) {
        val canonicalKey = canonicalPracticeKey(slug, practiceLookupGames())
        if (canonicalKey.isBlank()) return
        val trimmed = note.trim()
        val previous = gameSummaryNotes[canonicalKey]?.trim().orEmpty()
        val updated = updatedGameSummaryNotes(gameSummaryNotes, canonicalKey, note) ?: return
        mutateAndSave { gameSummaryNotes = updated }
        if (trimmed.isNotEmpty() && trimmed != previous) {
            addPracticeNote(canonicalKey, "general", "Game Note", trimmed)
        }
    }

    suspend fun availableLeaguePlayers(): List<String> = leagueIntegration.availablePlayers()

    suspend fun importLeagueScoresFromCsv(): String {
        val result = leagueIntegration.importScores(
            selectedPlayer = leaguePlayerName.trim(),
            games = games,
            onAddScore = { slug, score, timestampMs ->
                addScore(slug, score, context = "league", timestampMs = timestampMs, leagueImported = true)
            },
        )
        saveState()
        return result
    }

    suspend fun comparePlayers(yourName: String, opponentName: String): HeadToHeadComparison? {
        return leagueIntegration.comparePlayers(
            yourName = yourName,
            opponentName = opponentName,
            games = games,
        )
    }

    fun resetAllState() {
        canonicalPersistedState = emptyCanonicalPracticePersistedState()
        rulesheetResumeOffsets = emptyMap()
        applyRuntimePersistedState(emptyPracticePersistedState())
        LibraryActivityLog.clear(context)
        clearPracticeState(prefs, PRACTICE_STATE_KEY)
        saveState()
    }

    fun markPracticeViewedGame(slug: String) {
        val canonicalKey = canonicalPracticeKey(slug, practiceLookupGames())
        if (canonicalKey.isBlank()) return
        markPracticeLastViewedGame(prefs, canonicalKey, System.currentTimeMillis())
    }

    fun resumeSlugFromLibraryOrPractice(): String? =
        resumeSlugFromLibraryOrPractice(prefs)?.let { canonicalPracticeKey(it, practiceLookupGames()) }

    fun setPreferredLibrarySource(sourceId: String?) {
        val pool = if (allLibraryGames.isNotEmpty()) allLibraryGames else games
        val trimmed = sourceId?.trim().orEmpty()
        val selected = if (trimmed.isBlank()) {
            null
        } else {
            librarySources.firstOrNull { it.id == trimmed }
        }
        defaultPracticeSourceId = selected?.id
        games = if (selected != null) pool.filter { it.sourceId == selected.id } else pool
        prefs.edit {
            if (selected != null) {
                putString(KEY_PREFERRED_LIBRARY_SOURCE_ID, selected.id)
            } else {
                remove(KEY_PREFERRED_LIBRARY_SOURCE_ID)
            }
        }
        LibrarySourceStateStore.setSelectedSource(context, selected?.id)
    }

    suspend fun loadGames() {
        val loaded = loadPracticeGamesFromLibrary(context)
        val avenueCandidates = listOf("venue--the-avenue-cafe", "the-avenue")
        val savedSourceId = prefs.getString(KEY_PREFERRED_LIBRARY_SOURCE_ID, null)
        val preferredSource = listOfNotNull(savedSourceId, loaded.defaultSourceId)
            .plus(avenueCandidates)
            .firstOrNull { id -> loaded.sources.any { it.id == id } }
            ?.let { id -> loaded.sources.firstOrNull { it.id == id } }
            ?: loaded.sources.firstOrNull()

        games = if (preferredSource != null) loaded.allGames.filter { it.sourceId == preferredSource.id } else loaded.games
        allLibraryGames = loaded.allGames
        librarySources = loaded.sources
        defaultPracticeSourceId = preferredSource?.id ?: loaded.defaultSourceId
        defaultPracticeSourceId?.let { sourceId ->
            prefs.edit { putString(KEY_PREFERRED_LIBRARY_SOURCE_ID, sourceId) }
        }
        LibrarySourceStateStore.setSelectedSource(context, defaultPracticeSourceId)
    }

    private fun migrateLoadedStateToPracticeKeys() {
        val lookupGames = practiceLookupGames()
        if (lookupGames.isEmpty()) return
        val currentRuntime = runtimeStateSnapshot()
        val migratedRuntime = migratePracticeStateKeys(currentRuntime, lookupGames)
        val migratedCanonical = migrateCanonicalPracticeStateKeys(canonicalPersistedState, lookupGames)
        val changed = migratedRuntime != currentRuntime || migratedCanonical != canonicalPersistedState
        if (!changed) return
        canonicalPersistedState = migratedCanonical
        rulesheetResumeOffsets = migratedCanonical.rulesheetResumeOffsets
        applyRuntimePersistedState(runtimePracticeStateFromCanonicalState(migratedCanonical, ::gameName))
        saveState()
    }

    private fun migratePreferenceGameKeysToPracticeKeys() {
        val lookupGames = practiceLookupGames()
        if (lookupGames.isEmpty()) return
        val gamePrefKeys = listOf(
            KEY_PRACTICE_LAST_VIEWED_SLUG,
            KEY_LIBRARY_LAST_VIEWED_SLUG,
        ) + QUICK_GAME_PREF_KEYS

        var changed = false
        prefs.edit {
            gamePrefKeys.forEach { key ->
                val raw = prefs.getString(key, null)?.trim().orEmpty()
                if (raw.isEmpty()) return@forEach
                val canonical = canonicalPracticeKey(raw, lookupGames)
                if (canonical != raw) {
                    putString(key, canonical)
                    changed = true
                }
            }
        }
    }

    private fun autoArchiveExpiredGroupsIfNeeded() {
        val updated = autoArchiveExpiredGroups(groups)
        if (updated == groups) return
        groups = updated
        saveState()
    }

    private fun saveState() {
        canonicalPersistedState = canonicalPracticeStateFromRuntimeAndShadow(
            runtime = runtimeStateSnapshot(),
            shadow = canonicalPersistedState.copy(
                rulesheetResumeOffsets = rulesheetResumeOffsets,
                gameSummaryNotes = gameSummaryNotes,
            ),
        )
        val serialized = buildCanonicalPracticeStateJson(canonicalPersistedState)
        savePracticeState(prefs, PRACTICE_STATE_KEY, serialized)
    }

    private fun loadState() {
        val loaded = loadPracticeStatePayload(prefs, ::gameName) ?: return
        runCatching {
            applyPersistedState(loaded.payload)
            if (loaded.usedLegacyKey) {
                saveState()
                clearPracticeState(prefs, LEGACY_PRACTICE_STATE_KEY)
            }
        }
    }

    private fun runtimeStateSnapshot(): PracticePersistedState {
        return practicePersistedStateFromValues(
            playerName = playerName,
            ifpaPlayerID = ifpaPlayerID,
            comparisonPlayerName = comparisonPlayerName,
            leaguePlayerName = leaguePlayerName,
            cloudSyncEnabled = cloudSyncEnabled,
            selectedGroupID = selectedGroupID,
            groups = groups,
            scores = scores,
            notes = notes,
            journal = journal,
            rulesheetProgress = rulesheetProgress,
            gameSummaryNotes = gameSummaryNotes,
        )
    }

    private fun refreshRuntimeFromCanonical() {
        rulesheetResumeOffsets = canonicalPersistedState.rulesheetResumeOffsets
        applyRuntimePersistedState(runtimePracticeStateFromCanonicalState(canonicalPersistedState, ::gameName))
    }

    private fun splitCanonicalScoreContext(raw: String): Pair<String, String?> {
        val trimmed = raw.trim()
        return if (trimmed.startsWith("tournament:")) {
            "tournament" to trimmed.removePrefix("tournament:").trim().ifBlank { null }
        } else {
            trimmed.ifBlank { "practice" } to null
        }
    }

}
