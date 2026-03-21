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
import com.pillyliu.pinprofandroid.library.loadPracticeCatalogGames
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
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

    var bankTemplateGames by mutableStateOf<List<PinballGame>>(emptyList())
        private set

    var searchCatalogGames by mutableStateOf<List<PinballGame>>(emptyList())
        private set

    var librarySources by mutableStateOf<List<LibrarySource>>(emptyList())
        private set

    var defaultPracticeSourceId by mutableStateOf<String?>(null)
        private set

    var isLoadingSearchCatalog by mutableStateOf(false)
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
    private val progressIntegration by lazy { PracticeProgressIntegration() }
    private val derivedQueryIntegration by lazy { PracticeDerivedQueryIntegration() }
    private val libraryIntegration by lazy {
        PracticeLibraryIntegration(
            context = context,
            preferredSourceId = { prefs.getString(KEY_PREFERRED_LIBRARY_SOURCE_ID, null) },
            savePreferredSourceId = { sourceId ->
                prefs.edit {
                    if (sourceId != null) {
                        putString(KEY_PREFERRED_LIBRARY_SOURCE_ID, sourceId)
                    } else {
                        remove(KEY_PREFERRED_LIBRARY_SOURCE_ID)
                    }
                }
            },
        )
    }
    private val persistenceIntegration by lazy {
        PracticePersistenceIntegration(
            prefs = prefs,
            gameNameForSlug = ::gameName,
            quickGamePrefKeys = QUICK_GAME_PREF_KEYS,
        )
    }

    private val prefs by lazy { context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE) }

    private inline fun mutateAndSave(update: () -> Unit) {
        update()
        saveState()
    }

    private fun primaryPracticeLookupGames(): List<PinballGame> =
        when {
            searchCatalogGames.isNotEmpty() && allLibraryGames.isNotEmpty() -> allLibraryGames + searchCatalogGames
            searchCatalogGames.isNotEmpty() -> games + searchCatalogGames
            allLibraryGames.isNotEmpty() -> allLibraryGames
            else -> games
        }

    private fun practiceLookupGames(): List<PinballGame> = primaryPracticeLookupGames() + bankTemplateGames

    internal fun practiceLookupGamesForDisplay(): List<PinballGame> = primaryPracticeLookupGames()

    private fun canonicalGameID(gameSlug: String): String =
        canonicalPracticeKey(
            gameSlug,
            if (parseSourceScopedPracticeGameID(gameSlug).sourceID != null) practiceLookupGames() else primaryPracticeLookupGames(),
        )

    internal fun gameForAnyID(id: String): PinballGame? {
        val lookupGames = if (parseSourceScopedPracticeGameID(id).sourceID != null) {
            practiceLookupGames()
        } else {
            primaryPracticeLookupGames()
        }
        return findGameByPracticeLookupKey(lookupGames, id)
    }

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
        val normalizedGameSlugs = uniqueGroupSelectionIDsPreservingOrder(gameSlugs, practiceLookupGames())
        val result = createGroupInList(
            existing = groups,
            selectedGroupID = selectedGroupID,
            name = name,
            gameSlugs = normalizedGameSlugs,
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
        val normalized = updated.copy(
            gameSlugs = uniqueGroupSelectionIDsPreservingOrder(updated.gameSlugs, practiceLookupGames()),
        )
        groups = updateGroupInList(groups, normalized)
        saveState()
    }

    fun removeGameFromGroup(groupID: String, gameSlug: String) {
        val canonicalGameSlug = canonicalGameID(gameSlug)
        val next = groups.map { group ->
            if (group.id != groupID) {
                group
            } else {
                group.copy(
                    gameSlugs = group.gameSlugs.filterNot { canonicalPracticeKey(it, practiceLookupGames()) == canonicalGameSlug },
                )
            }
        }
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
        val canonicalKey = canonicalGameID(gameSlug)
        if (canonicalKey.isBlank()) return
        canonicalPersistedState = progressIntegration.addScore(
            canonicalState = canonicalPersistedState,
            canonicalGameID = canonicalKey,
            score = score,
            context = context,
            timestampMs = timestampMs,
            leagueImported = leagueImported,
        )
        refreshRuntimeFromCanonical()
        markPracticeViewedGame(canonicalKey)
        saveState()
    }

    fun addStudy(gameSlug: String, category: String, value: String, note: String? = null) {
        val canonicalKey = canonicalGameID(gameSlug)
        if (canonicalKey.isBlank()) return
        canonicalPersistedState = progressIntegration.addStudy(
            canonicalState = canonicalPersistedState,
            canonicalGameID = canonicalKey,
            category = category,
            value = value,
            note = note,
            timestampMs = System.currentTimeMillis(),
        ) ?: return
        refreshRuntimeFromCanonical()
        markPracticeViewedGame(canonicalKey)
        saveState()
    }

    fun addPracticeNote(gameSlug: String, category: String, detail: String?, note: String) {
        val canonicalKey = canonicalGameID(gameSlug)
        if (canonicalKey.isBlank()) return
        canonicalPersistedState = progressIntegration.addPracticeNote(
            canonicalState = canonicalPersistedState,
            canonicalGameID = canonicalKey,
            category = category,
            detail = detail,
            note = note,
            timestampMs = System.currentTimeMillis(),
        ) ?: return
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
        derivedQueryIntegration.scoreValues(scores, canonicalGameID(gameSlug))

    fun scoreTrendValues(gameSlug: String, limit: Int = 24): List<Double> =
        derivedQueryIntegration.scoreTrendValues(scores, canonicalGameID(gameSlug), limit)

    fun scoreSummaryFor(gameSlug: String): ScoreSummary? =
        derivedQueryIntegration.scoreSummary(scores, canonicalGameID(gameSlug))

    fun groupDashboardScore(group: PracticeGroup): GroupDashboardScore =
        derivedQueryIntegration.groupDashboardScore(group, practiceLookupGames(), scores, journal, rulesheetProgress)

    fun recommendedGame(group: PracticeGroup): PinballGame? =
        derivedQueryIntegration.recommendedGame(group, practiceLookupGames(), scores, journal, rulesheetProgress)

    fun taskProgressForGame(gameSlug: String, group: PracticeGroup? = null): Map<String, Int> =
        derivedQueryIntegration.taskProgress(journal, rulesheetProgress, canonicalGameID(gameSlug), group)

    fun mechanicsSkills(): List<String> = derivedQueryIntegration.mechanicsSkills()

    fun detectedMechanicsTags(text: String): List<String> =
        derivedQueryIntegration.detectedMechanicsTags(text, mechanicsSkills())

    fun allTrackedMechanicsSkills(): List<String> =
        derivedQueryIntegration.trackedMechanicsSkills(notes, mechanicsSkills())

    fun mechanicsSummary(skill: String): MechanicsSkillSummary =
        derivedQueryIntegration.mechanicsSummary(skill, notes, mechanicsSkills())

    fun mechanicsLogs(skill: String): List<NoteEntry> =
        derivedQueryIntegration.mechanicsLogs(skill, notes, mechanicsSkills())

    fun activeGroups(): List<PracticeGroup> = derivedQueryIntegration.activeGroups(groups)

    fun activeGroupForGame(gameSlug: String): PracticeGroup? {
        return derivedQueryIntegration.activeGroupForGame(groups, canonicalGameID(gameSlug), practiceLookupGames())
    }

    fun groupGames(group: PracticeGroup): List<PinballGame> {
        return derivedQueryIntegration.groupGames(group, games, practiceLookupGames())
    }

    fun groupProgress(group: PracticeGroup): List<GroupProgressSnapshot> {
        return group.gameSlugs.mapNotNull { selectionGameSlug ->
            val game = gameForAnyID(selectionGameSlug) ?: return@mapNotNull null
            GroupProgressSnapshot(
                selectionGameSlug = selectionGameSlug,
                game = game,
                taskProgress = taskProgressForGame(selectionGameSlug, group),
            )
        }
    }

    fun gameName(slug: String): String =
        derivedQueryIntegration.gameName(practiceLookupGames(), canonicalGameID(slug))

    fun leagueTargetScoresFor(gameSlug: String): LeagueTargetScores? =
        leagueIntegration.targetScoresFor(
            gameSlug = canonicalGameID(gameSlug),
            games = practiceLookupGames(),
        )

    fun saveRulesheetProgress(slug: String, ratio: Float) {
        val canonicalKey = canonicalGameID(slug)
        if (canonicalKey.isBlank()) return
        mutateAndSave {
            rulesheetResumeOffsets = progressIntegration.updatedRulesheetResumeOffsets(
                currentOffsets = rulesheetResumeOffsets,
                canonicalGameID = canonicalKey,
                ratio = ratio,
            )
        }
    }

    fun rulesheetSavedProgress(slug: String): Float =
        (rulesheetResumeOffsets[canonicalGameID(slug)] ?: 0.0).toFloat()

    fun gameSummaryNoteFor(slug: String): String = gameSummaryNoteForSlug(gameSummaryNotes, canonicalGameID(slug))

    fun updateGameSummaryNote(slug: String, note: String) {
        val canonicalKey = canonicalGameID(slug)
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
        persistenceIntegration.clearPrimaryState()
        saveState()
    }

    fun markPracticeViewedGame(slug: String) {
        val exactSlug = slug.trim().takeIf { raw ->
            raw.isNotEmpty() && primaryPracticeLookupGames().any { it.slug == raw }
        }
        val persistedKey = exactSlug ?: canonicalGameID(slug)
        if (persistedKey.isBlank()) return
        persistenceIntegration.markViewedGame(persistedKey, System.currentTimeMillis())
    }

    fun resumeSlugFromLibraryOrPractice(): String? =
        persistenceIntegration.resumeSlug(practiceLookupGames())

    fun setPreferredLibrarySource(sourceId: String?) {
        val pool = if (allLibraryGames.isNotEmpty()) allLibraryGames else games
        val selection = libraryIntegration.applySelectedSource(
            sourceId = sourceId,
            sources = librarySources,
            allGames = pool,
        )
        defaultPracticeSourceId = selection.selectedSourceId
        games = selection.visibleGames
        libraryIntegration.persistSelectedSource(selection.selectedSourceId)
    }

    suspend fun loadGames() = coroutineScope {
        isLoadingSearchCatalog = true
        try {
            val libraryStateDeferred = async { libraryIntegration.loadLibraryState() }
            val bankTemplateGamesDeferred = async { loadPracticeAvenueBankTemplateGames() }
            val searchCatalogGamesDeferred = async {
                runCatching { loadPracticeCatalogGames(context) }.getOrElse { searchCatalogGames }
            }

            val libraryState = libraryStateDeferred.await()
            val bankTemplates = bankTemplateGamesDeferred.await()
            val loadedSearchCatalogGames = searchCatalogGamesDeferred.await()

            games = libraryState.visibleGames
            allLibraryGames = libraryState.allGames
            librarySources = libraryState.sources
            bankTemplateGames = bankTemplates
            searchCatalogGames = loadedSearchCatalogGames
            defaultPracticeSourceId = libraryState.defaultSourceId
            defaultPracticeSourceId?.let { sourceId ->
                libraryIntegration.persistSelectedSource(sourceId)
            }
        } finally {
            isLoadingSearchCatalog = false
        }
    }

    suspend fun ensureSearchCatalogGamesLoaded() {
        if (searchCatalogGames.isNotEmpty() || isLoadingSearchCatalog) return
        isLoadingSearchCatalog = true
        try {
            searchCatalogGames = loadPracticeCatalogGames(context)
        } finally {
            isLoadingSearchCatalog = false
        }
    }

    private fun migrateLoadedStateToPracticeKeys() {
        val lookupGames = practiceLookupGames()
        val migrated = persistenceIntegration.migrateLoadedState(
            lookupGames = lookupGames,
            runtimeState = runtimeStateSnapshot(),
            canonicalState = canonicalPersistedState,
        ) ?: return
        canonicalPersistedState = migrated.canonicalState
        rulesheetResumeOffsets = migrated.canonicalState.rulesheetResumeOffsets
        applyRuntimePersistedState(migrated.runtimeState)
        saveState()
    }

    private fun migratePreferenceGameKeysToPracticeKeys() {
        persistenceIntegration.migratePreferenceGameKeys(practiceLookupGames())
    }

    private fun saveState() {
        canonicalPersistedState = persistenceIntegration.saveState(
            runtimeState = runtimeStateSnapshot(),
            shadowState = canonicalPersistedState.copy(
                rulesheetResumeOffsets = rulesheetResumeOffsets,
                gameSummaryNotes = gameSummaryNotes,
            ),
        )
    }

    private fun loadState() {
        val loaded = persistenceIntegration.loadState() ?: return
        runCatching {
            applyPersistedState(loaded.payload)
            if (loaded.usedLegacyKey) {
                saveState()
                persistenceIntegration.clearLegacyState()
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

}
