package com.pillyliu.pinballandroid.practice

import android.content.Context
import androidx.core.content.edit
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.pillyliu.pinballandroid.library.LibraryActivityLog
import com.pillyliu.pinballandroid.library.LibrarySource
import com.pillyliu.pinballandroid.library.PinballGame

private const val PRACTICE_STATE_KEY = "practice-state-json"
private const val LEAGUE_TARGETS_PATH = "/pinball/data/LPL_Targets.csv"

internal class PracticeStore(private val context: Context) {
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

    private var leagueTargetsByNormalizedMachine: Map<String, LeagueTargetScores> = emptyMap()

    private val prefs by lazy { context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE) }

    private inline fun mutateAndSave(update: () -> Unit) {
        update()
        saveState()
    }

    private fun practiceLookupGames(): List<PinballGame> =
        if (allLibraryGames.isNotEmpty()) allLibraryGames else games

    private fun applyPersistedState(state: PracticePersistedState) {
        playerName = state.playerName
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
        loadState()
        autoArchiveExpiredGroupsIfNeeded()
        loadGames()
        migrateLoadedStateToPracticeKeys()
        loadLeagueTargets()
    }

    fun updatePlayerName(name: String) {
        mutateAndSave { playerName = name.trim() }
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
        autoArchiveExpiredGroupsIfNeeded()
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
        val gameName = gameName(canonicalKey)
        val mutation = applyScoreEntryMutation(
            scores = scores,
            journal = journal,
            gameSlug = canonicalKey,
            gameName = gameName,
            score = score,
            context = context,
            timestampMs = timestampMs,
            leagueImported = leagueImported,
        )
        scores = mutation.scores
        journal = mutation.journal
        markPracticeViewedGame(canonicalKey)
        saveState()
    }

    fun addStudy(gameSlug: String, category: String, value: String, note: String? = null) {
        val canonicalKey = canonicalPracticeKey(gameSlug, practiceLookupGames())
        val gameName = gameName(canonicalKey)
        val mutation = applyStudyEntryMutation(
            journal = journal,
            rulesheetProgress = rulesheetProgress,
            gameSlug = canonicalKey,
            gameName = gameName,
            category = category,
            value = value,
            note = note,
            timestampMs = System.currentTimeMillis(),
        )
        rulesheetProgress = mutation.rulesheetProgress
        journal = mutation.journal
        markPracticeViewedGame(canonicalKey)
        saveState()
    }

    fun addPracticeNote(gameSlug: String, category: String, detail: String?, note: String) {
        val canonicalKey = canonicalPracticeKey(gameSlug, practiceLookupGames())
        val gameName = gameName(canonicalKey)
        val mutation = applyPracticeNoteMutation(
            notes = notes,
            journal = journal,
            gameSlug = canonicalKey,
            gameName = gameName,
            category = category,
            detail = detail,
            note = note,
            timestampMs = System.currentTimeMillis(),
        ) ?: return
        notes = mutation.notes
        journal = mutation.journal
        markPracticeViewedGame(canonicalKey)
        saveState()
    }

    fun journalItems(filter: JournalFilter): List<JournalEntry> = filteredJournalItems(journal, filter)

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
        autoArchiveExpiredGroupsIfNeeded()
        return activeGroupsFromList(groups)
    }

    fun activeGroupForGame(gameSlug: String): PracticeGroup? {
        autoArchiveExpiredGroupsIfNeeded()
        return activeGroupForGame(groups, canonicalPracticeKey(gameSlug, practiceLookupGames()))
    }

    fun groupGames(group: PracticeGroup): List<PinballGame> = groupGamesFromList(group, games)

    fun gameName(slug: String): String = gameNameForSlug(practiceLookupGames(), canonicalPracticeKey(slug, practiceLookupGames()))

    fun leagueTargetScoresFor(gameSlug: String): LeagueTargetScores? =
        leagueTargetScoresForSlug(canonicalPracticeKey(gameSlug, practiceLookupGames()), practiceLookupGames(), ::leagueTargetScoresForGameName)

    fun saveRulesheetProgress(slug: String, ratio: Float) {
        val canonicalKey = canonicalPracticeKey(slug, practiceLookupGames())
        mutateAndSave { rulesheetProgress = updatedRulesheetProgress(rulesheetProgress, canonicalKey, ratio) }
    }

    fun rulesheetSavedProgress(slug: String): Float = rulesheetProgress[canonicalPracticeKey(slug, practiceLookupGames())] ?: 0f

    fun gameSummaryNoteFor(slug: String): String = gameSummaryNoteForSlug(gameSummaryNotes, canonicalPracticeKey(slug, practiceLookupGames()))

    fun updateGameSummaryNote(slug: String, note: String) {
        val updated = updatedGameSummaryNotes(gameSummaryNotes, canonicalPracticeKey(slug, practiceLookupGames()), note) ?: return
        mutateAndSave { gameSummaryNotes = updated }
    }

    suspend fun availableLeaguePlayers(): List<String> = availableLeaguePlayersFromCsv()

    suspend fun importLeagueScoresFromCsv(): String {
        val result = importLeagueScoresFromCsvData(
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
        return comparePlayersFromCsv(
            yourName = yourName,
            opponentName = opponentName,
            games = games,
            gameNameForSlug = ::gameName,
        )
    }

    fun resetAllState() {
        applyPersistedState(emptyPracticePersistedState())
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
    }

    private suspend fun loadGames() {
        val loaded = loadPracticeGamesFromLibrary()
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
        defaultPracticeSourceId?.let { prefs.edit().putString(KEY_PREFERRED_LIBRARY_SOURCE_ID, it).apply() }
    }

    private fun migrateLoadedStateToPracticeKeys() {
        if (games.isEmpty()) return
        val current = practicePersistedStateFromValues(
            playerName = playerName,
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
        val migrated = migratePracticeStateKeys(current, games)
        if (migrated == current) return
        applyPersistedState(migrated)
        saveState()
    }

    private fun autoArchiveExpiredGroupsIfNeeded() {
        val updated = autoArchiveExpiredGroups(groups)
        if (updated == groups) return
        groups = updated
        saveState()
    }

    private fun saveState() {
        val serialized = buildPracticeStateJson(
            practicePersistedStateFromValues(
                playerName = playerName,
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
            ),
        )
        savePracticeState(prefs, PRACTICE_STATE_KEY, serialized)
    }

    private fun loadState() {
        val raw = loadPracticeState(prefs, PRACTICE_STATE_KEY) ?: return
        val state = parsePracticeStateJson(raw) ?: return
        runCatching {
            applyPersistedState(state)
        }
    }

    private suspend fun loadLeagueTargets() {
        leagueTargetsByNormalizedMachine = loadLeagueTargetsMap(LEAGUE_TARGETS_PATH)
    }

    private fun leagueTargetScoresForGameName(gameName: String): LeagueTargetScores? =
        resolveLeagueTargetScores(gameName, leagueTargetsByNormalizedMachine)
}
