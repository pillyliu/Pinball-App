package com.pillyliu.pinprofandroid.practice

import android.content.Context
import androidx.core.content.edit
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.pillyliu.pinprofandroid.PinballPerformanceTrace
import com.pillyliu.pinprofandroid.league.LeaguePreviewRefreshEvents
import com.pillyliu.pinprofandroid.library.LibraryActivityLog
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore
import com.pillyliu.pinprofandroid.library.PM_AVENUE_LIBRARY_SOURCE_ID
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.canonicalLibrarySourceId
import com.pillyliu.pinprofandroid.library.loadPracticeCatalogGames
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import java.time.Instant
import java.time.ZoneId
import kotlin.math.abs
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

    var isLoadingAllLibraryGames by mutableStateOf(false)
        private set

    var isLoadingLeagueTargets by mutableStateOf(false)
        private set

    var didLoadLeagueTargets by mutableStateOf(false)
        private set

    var isBootstrapping by mutableStateOf(true)
        private set

    var hasRestoredHomeBootstrapSnapshot by mutableStateOf(false)
        private set

    private var didLoadAllLibraryGames = false
    private var isLoadingBankTemplateGames = false
    private var isLoadingLeagueCatalogGames = false
    private var leagueCatalogGames: List<PinballGame> = emptyList()

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
    private var lastLeagueAutoImportAttemptMs: Long = 0L
    private var isAutoImportingLeagueScores = false
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

    init {
        restoreHomeBootstrapSnapshotIfAvailable()
    }

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

    private fun leagueLookupGames(): List<PinballGame> =
        if (leagueCatalogGames.isEmpty()) practiceLookupGames() else practiceLookupGames() + leagueCatalogGames

    internal fun practiceLookupGamesForDisplay(): List<PinballGame> = primaryPracticeLookupGames()

    private fun canonicalGameID(gameSlug: String): String =
        canonicalPracticeKey(
            gameSlug,
            if (parseSourceScopedPracticeGameID(gameSlug).sourceID != null) practiceLookupGames() else primaryPracticeLookupGames(),
        )

    internal fun gameForAnyID(id: String): PinballGame? {
        val parsed = parseSourceScopedPracticeGameID(id)
        val lookupGames = if (parsed.sourceID != null) {
            practiceLookupGames()
        } else {
            primaryPracticeLookupGames()
        }
        return findGameByPracticeLookupKey(lookupGames, id)
            ?: if (parsed.sourceID == null) findGameByPracticeLookupKey(leagueCatalogGames, id) else null
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
        if (didLoad) {
            isBootstrapping = false
            return
        }
        didLoad = true
        try {
            PinballPerformanceTrace.measureSuspend("PracticeBootstrap") {
                var loadedState: LoadedPracticeStatePayload? = null
                coroutineScope {
                    val initialLibraryState = async { libraryIntegration.loadInitialLibraryState() }
                    val loadedStateTask = async { persistenceIntegration.loadState() }

                    applyLibraryState(initialLibraryState.await())
                    loadedState = loadedStateTask.await()
                    applyLoadedState(loadedState)
                }
                if (needsBankTemplateGamesForStoredReferences()) {
                    ensureBankTemplateGamesLoaded()
                }
                if (needsAllLibraryGamesForStoredReferences()) {
                    ensureAllLibraryGamesLoaded()
                }
                if (needsSearchCatalogForStoredReferences()) {
                    ensureSearchCatalogGamesLoaded()
                }
                val migrated = migrateLoadedStateToPracticeKeys()
                migratePreferenceGameKeysToPracticeKeys()
                if (loadedState?.requiresCanonicalSave == true && !migrated) {
                    saveState()
                    persistenceIntegration.clearLegacyState()
                }
                saveHomeBootstrapSnapshotIfNeeded()
            }
        } finally {
            isBootstrapping = false
        }
    }

    fun updatePlayerName(name: String) {
        mutateAndSave { playerName = name.trim() }
        saveHomeBootstrapSnapshotIfNeeded()
    }

    suspend fun savePlayerProfileAndSyncIfpa(
        name: String,
        forceRefreshLeagueIdentity: Boolean = false,
    ): LeagueIdentityMatch? {
        val trimmedName = name.trim()
        updatePlayerName(trimmedName)
        if (trimmedName.isBlank()) return null
        val identity = approvedLeagueIdentityMatch(
            name = trimmedName,
            forceRefresh = forceRefreshLeagueIdentity,
        )
        identity?.ifpaPlayerID?.let(::updateIfpaPlayerID)
        return identity
    }

    fun updateIfpaPlayerID(value: String) {
        mutateAndSave { ifpaPlayerID = value.trim() }
    }

    fun updateComparisonPlayerName(name: String) {
        mutateAndSave { comparisonPlayerName = name.trim() }
    }

    fun updateLeaguePlayerName(name: String) {
        val trimmed = name.trim()
        leaguePlayerName = trimmed
        canonicalPersistedState = canonicalPersistedState.copy(
            leagueSettings = canonicalPersistedState.leagueSettings.copy(
                playerName = trimmed,
                csvAutoFillEnabled = true,
            ),
        )
        saveState()
        LeaguePreviewRefreshEvents.notifyChanged()
    }

    suspend fun selectLeaguePlayerAndSyncIfpa(name: String): LeagueIdentityMatch? {
        val trimmedName = name.trim()
        updateLeaguePlayerName(trimmedName)
        if (trimmedName.isBlank()) return null
        val identity = approvedLeagueIdentityMatch(name = trimmedName)
        identity?.ifpaPlayerID?.let(::updateIfpaPlayerID)
        return identity
    }

    fun updateCloudSyncEnabled(enabled: Boolean) {
        mutateAndSave { cloudSyncEnabled = enabled }
    }

    fun setSelectedGroup(id: String?) {
        if (selectedGroupID == id) return
        mutateAndSave { selectedGroupID = id }
        saveHomeBootstrapSnapshotIfNeeded()
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
        saveHomeBootstrapSnapshotIfNeeded()
        return result.createdId
    }

    fun updateGroup(updated: PracticeGroup) {
        val normalized = updated.copy(
            gameSlugs = uniqueGroupSelectionIDsPreservingOrder(updated.gameSlugs, practiceLookupGames()),
        )
        groups = updateGroupInList(groups, normalized)
        saveState()
        saveHomeBootstrapSnapshotIfNeeded()
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
        saveHomeBootstrapSnapshotIfNeeded()
    }

    fun moveGroup(groupID: String, up: Boolean) {
        val next = moveGroupInList(groups, groupID, up)
        if (next == groups) return
        groups = next
        saveState()
        saveHomeBootstrapSnapshotIfNeeded()
    }

    fun deleteGroup(groupID: String) {
        val result = deleteGroupFromList(groups, selectedGroupID, groupID)
        groups = result.groups
        selectedGroupID = result.selectedGroupID
        saveState()
        saveHomeBootstrapSnapshotIfNeeded()
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

    private fun repairImportedLeagueScore(existingId: String, score: Double, gameSlug: String, timestampMs: Long) {
        val canonicalKey = canonicalGameID(gameSlug)
        if (canonicalKey.isBlank()) return

        val zoneId = ZoneId.systemDefault()
        val targetDate = Instant.ofEpochMilli(timestampMs).atZone(zoneId).toLocalDate()
        val matchingJournalIds = canonicalPersistedState.journalEntries.filter { entry ->
            entry.action == "scoreLogged" &&
                entry.scoreContext == "league" &&
                entry.score != null &&
                abs(entry.score - score) < 0.5 &&
                Instant.ofEpochMilli(entry.timestampMs).atZone(zoneId).toLocalDate() == targetDate
        }.map { it.id }

        var didChange = false
        val updatedScores = canonicalPersistedState.scoreEntries.map { entry ->
            if (entry.id != existingId) {
                entry
            } else if (entry.gameID != canonicalKey || entry.timestampMs != timestampMs) {
                didChange = true
                entry.copy(gameID = canonicalKey, timestampMs = timestampMs)
            } else {
                entry
            }
        }

        val updatedJournal = if (matchingJournalIds.size == 1) {
            val journalId = matchingJournalIds.single()
            canonicalPersistedState.journalEntries.map { entry ->
                if (entry.id != journalId) {
                    entry
                } else if (entry.gameID != canonicalKey || entry.timestampMs != timestampMs) {
                    didChange = true
                    entry.copy(gameID = canonicalKey, timestampMs = timestampMs)
                } else {
                    entry
                }
            }
        } else {
            canonicalPersistedState.journalEntries
        }

        if (!didChange) return
        canonicalPersistedState = canonicalPersistedState.copy(
            scoreEntries = updatedScores,
            journalEntries = updatedJournal,
        )
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

    fun gameJournalEntriesFor(gameSlug: String): List<JournalEntry> =
        derivedQueryIntegration.journalEntriesForGame(journal, canonicalGameID(gameSlug))

    fun dashboardAlertsFor(gameSlug: String): List<PracticeDashboardAlert> =
        computeDashboardAlertsForGame(
            journalEntries = gameJournalEntriesFor(gameSlug),
            scoreSummary = scoreSummaryFor(gameSlug),
        )

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

    suspend fun availableLeaguePlayers(forceRefresh: Boolean = false): List<String> =
        leagueIntegration.availablePlayers(forceRefresh = forceRefresh)

    suspend fun approvedLeagueIdentityMatch(
        name: String,
        forceRefresh: Boolean = false,
    ): LeagueIdentityMatch? = leagueIntegration.approvedLeagueIdentityMatch(
        inputName = name,
        forceRefresh = forceRefresh,
    )

    suspend fun importLeagueScoresFromCsv(forceRefresh: Boolean = false): String {
        return importLeagueScoresFromCsvResult(forceRefresh = forceRefresh).summaryLine
    }

    suspend fun importLeagueScoresFromCsvResult(forceRefresh: Boolean = false): LeagueImportResult {
        ensureLeagueCatalogGamesLoaded()
        val selectedPlayer = leaguePlayerName.trim()
        val result = leagueIntegration.importScores(
            selectedPlayer = selectedPlayer,
            games = leagueLookupGames(),
            existingScores = scores,
            forceRefresh = forceRefresh,
            onAddScore = { slug, score, timestampMs ->
                addScore(slug, score, context = "league", timestampMs = timestampMs, leagueImported = true)
            },
            onRepairScore = { existingId, score, slug, timestampMs ->
                repairImportedLeagueScore(existingId, score, slug, timestampMs)
            },
        )
        if (result.errorMessage == null) {
            canonicalPersistedState = canonicalPersistedState.copy(
                leagueSettings = canonicalPersistedState.leagueSettings.copy(
                    playerName = selectedPlayer,
                    csvAutoFillEnabled = true,
                    lastImportAtMs = System.currentTimeMillis(),
                    lastRepairVersion = PracticeLeagueIntegration.LEAGUE_SCORE_REPAIR_VERSION,
                ),
            )
            refreshRuntimeFromCanonical()
            saveState()
        }
        return result
    }

    suspend fun autoImportLeagueScoresIfEnabled(): LeagueImportResult? {
        if (leaguePlayerName.isBlank() || practiceLookupGames().isEmpty()) return null

        val nowMs = System.currentTimeMillis()
        if (isAutoImportingLeagueScores || (nowMs - lastLeagueAutoImportAttemptMs) < 60_000L) return null

        isAutoImportingLeagueScores = true
        lastLeagueAutoImportAttemptMs = nowMs
        return try {
            val hasRemoteUpdate = runCatching {
                com.pillyliu.pinprofandroid.data.PinballDataCache.hasRemoteUpdate(
                    com.pillyliu.pinprofandroid.library.hostedLeagueStatsPath,
                )
            }.getOrDefault(false)
            val statsUpdatedAtMs = runCatching {
                leagueIntegration.statsUpdatedAtMs(forceRefresh = hasRemoteUpdate)
            }.getOrNull()
            val csvIsNewerThanLastImport = canonicalPersistedState.leagueSettings.lastImportAtMs?.let { lastImportAtMs ->
                statsUpdatedAtMs?.let { it > lastImportAtMs }
            } == true
            val needsRepairPass = canonicalPersistedState.leagueSettings.lastRepairVersion != PracticeLeagueIntegration.LEAGUE_SCORE_REPAIR_VERSION
            val shouldImport = canonicalPersistedState.leagueSettings.lastImportAtMs == null ||
                hasRemoteUpdate ||
                csvIsNewerThanLastImport ||
                needsRepairPass
            if (!shouldImport) {
                null
            } else {
                val result = importLeagueScoresFromCsvResult(forceRefresh = false)
                result.takeIf { it.errorMessage == null && it.hasChanges }
            }
        } finally {
            isAutoImportingLeagueScores = false
        }
    }

    suspend fun comparePlayers(yourName: String, opponentName: String): HeadToHeadComparison? {
        ensureLeagueCatalogGamesLoaded()
        return leagueIntegration.comparePlayers(
            yourName = yourName,
            opponentName = opponentName,
            games = leagueLookupGames(),
        )
    }

    fun resetAllState() {
        canonicalPersistedState = emptyCanonicalPracticePersistedState()
        rulesheetResumeOffsets = emptyMap()
        applyRuntimePersistedState(emptyPracticePersistedState())
        LibraryActivityLog.clear(context)
        persistenceIntegration.clearPrimaryState()
        saveState()
        saveHomeBootstrapSnapshotIfNeeded()
    }

    val importedLeagueScoreCount: Int
        get() = scores.count { it.leagueImported }

    fun purgeImportedLeagueScores(): Int {
        val removedCount = canonicalPersistedState.scoreEntries.count { it.leagueImported }
        canonicalPersistedState = canonicalPersistedState.copy(
            scoreEntries = canonicalPersistedState.scoreEntries.filterNot { it.leagueImported },
            journalEntries = canonicalPersistedState.journalEntries.filterNot { entry ->
                if (entry.action != "scoreLogged") {
                    false
                } else {
                    entry.scoreContext == "league" ||
                        (entry.note?.contains("Imported from LPL stats CSV", ignoreCase = true) == true)
                }
            },
            leagueSettings = canonicalPersistedState.leagueSettings.copy(
                csvAutoFillEnabled = true,
                lastImportAtMs = null,
                lastRepairVersion = null,
            ),
        )
        refreshRuntimeFromCanonical()
        saveState()
        saveHomeBootstrapSnapshotIfNeeded()
        return removedCount
    }

    fun clearImportedLeagueScoresAndBuildStatus(): String {
        return clearedImportedLeagueScoresStatusMessage(purgeImportedLeagueScores())
    }

    fun markPracticeViewedGame(slug: String) {
        val persistedKey = canonicalGameID(slug)
        if (persistedKey.isBlank()) return
        persistenceIntegration.markViewedGame(persistedKey, System.currentTimeMillis())
        saveHomeBootstrapSnapshotIfNeeded()
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
        saveHomeBootstrapSnapshotIfNeeded()
    }

    suspend fun loadGames() {
        applyLibraryState(libraryIntegration.loadInitialLibraryState())
        saveHomeBootstrapSnapshotIfNeeded()
    }

    suspend fun ensureAllLibraryGamesLoaded() {
        if (didLoadAllLibraryGames || isLoadingAllLibraryGames) return
        isLoadingAllLibraryGames = true
        try {
            applyLibraryState(libraryIntegration.loadFullLibraryState())
            saveHomeBootstrapSnapshotIfNeeded()
        } finally {
            isLoadingAllLibraryGames = false
        }
    }

    private fun applyLibraryState(libraryState: PracticeLibraryStoreState) {
        games = libraryState.visibleGames
        allLibraryGames = libraryState.allGames
        librarySources = libraryState.sources
        defaultPracticeSourceId = libraryState.defaultSourceId
        didLoadAllLibraryGames = libraryState.isFullLibraryScope
        defaultPracticeSourceId?.let { sourceId ->
            libraryIntegration.persistSelectedSource(sourceId)
        }
    }

    suspend fun ensureSearchCatalogGamesLoaded() {
        if (searchCatalogGames.isNotEmpty() || isLoadingSearchCatalog) return
        isLoadingSearchCatalog = true
        try {
            searchCatalogGames = PinballPerformanceTrace.measureSuspend("PracticeSearchCatalogLoad") {
                loadPracticeCatalogGames(context)
            }
            saveHomeBootstrapSnapshotIfNeeded()
        } finally {
            isLoadingSearchCatalog = false
        }
    }

    private suspend fun ensureLeagueCatalogGamesLoaded() {
        if (leagueCatalogGames.isNotEmpty() || isLoadingLeagueCatalogGames) return
        isLoadingLeagueCatalogGames = true
        try {
            leagueCatalogGames = PinballPerformanceTrace.measureSuspend("PracticeLeagueCatalogLoad") {
                loadPracticeCatalogGames(context)
            }
        } catch (_: Throwable) {
            leagueCatalogGames = emptyList()
        } finally {
            isLoadingLeagueCatalogGames = false
        }
    }

    suspend fun ensureBankTemplateGamesLoaded() {
        if (bankTemplateGames.isNotEmpty() || isLoadingBankTemplateGames) return
        isLoadingBankTemplateGames = true
        try {
            bankTemplateGames = PinballPerformanceTrace.measureSuspend("PracticeBankTemplateLoad") {
                loadPracticeAvenueBankTemplateGames()
            }
            saveHomeBootstrapSnapshotIfNeeded()
        } finally {
            isLoadingBankTemplateGames = false
        }
    }

    suspend fun ensureLeagueTargetsLoaded() {
        if (didLoadLeagueTargets || isLoadingLeagueTargets) return
        isLoadingLeagueTargets = true
        try {
            leagueIntegration.ensureTargetsLoaded()
            didLoadLeagueTargets = true
        } finally {
            isLoadingLeagueTargets = false
        }
    }

    private fun applyLoadedState(loaded: LoadedPracticeStatePayload?) {
        val payload = loaded?.payload ?: return
        applyPersistedState(payload)
    }

    private fun migrateLoadedStateToPracticeKeys(): Boolean {
        val lookupGames = practiceLookupGames()
        val migrated = persistenceIntegration.migrateLoadedState(
            lookupGames = lookupGames,
            runtimeState = runtimeStateSnapshot(),
            canonicalState = canonicalPersistedState,
        ) ?: return false
        canonicalPersistedState = migrated.canonicalState
        rulesheetResumeOffsets = migrated.canonicalState.rulesheetResumeOffsets
        applyRuntimePersistedState(migrated.runtimeState)
        saveState()
        return true
    }

    private fun migratePreferenceGameKeysToPracticeKeys() {
        persistenceIntegration.migratePreferenceGameKeys(practiceLookupGames())
    }

    private fun restoreHomeBootstrapSnapshotIfAvailable() {
        val snapshot = PracticeHomeBootstrapSnapshotStore.load(context) ?: run {
            hasRestoredHomeBootstrapSnapshot = false
            return
        }

        canonicalPersistedState = emptyCanonicalPracticePersistedState().copy(
            customGroups = snapshot.groups.map { group ->
                CanonicalCustomGroup(
                    id = group.id,
                    name = group.name,
                    gameIDs = group.gameSlugs,
                    type = group.type,
                    isActive = group.isActive,
                    isArchived = group.isArchived,
                    isPriority = group.isPriority,
                    startDateMs = group.startDateMs,
                    endDateMs = group.endDateMs,
                    createdAtMs = snapshot.capturedAtMs,
                )
            },
            practiceSettings = CanonicalPracticeSettings(
                playerName = snapshot.playerName,
                ifpaPlayerID = "",
                comparisonPlayerName = "",
                selectedGroupID = snapshot.selectedGroupID,
            ),
        )
        rulesheetResumeOffsets = emptyMap()
        applyRuntimePersistedState(
            practicePersistedStateFromValues(
                playerName = snapshot.playerName,
                ifpaPlayerID = "",
                comparisonPlayerName = "",
                leaguePlayerName = "",
                cloudSyncEnabled = false,
                selectedGroupID = snapshot.selectedGroupID,
                groups = snapshot.groups,
                scores = emptyList(),
                notes = emptyList(),
                journal = emptyList(),
                rulesheetProgress = emptyMap(),
                gameSummaryNotes = emptyMap(),
            ),
        )
        games = snapshot.visibleGames.map(PracticeHomeBootstrapGameSnapshot::toPinballGame)
        allLibraryGames = snapshot.lookupGames.map(PracticeHomeBootstrapGameSnapshot::toPinballGame)
        librarySources = snapshot.librarySources.map(PracticeHomeBootstrapSourceSnapshot::toLibrarySource)
        defaultPracticeSourceId = snapshot.selectedLibrarySourceId
        hasRestoredHomeBootstrapSnapshot = snapshot.isUsable()
    }

    private fun saveHomeBootstrapSnapshotIfNeeded() {
        val snapshot = buildHomeBootstrapSnapshot() ?: return
        PracticeHomeBootstrapSnapshotStore.save(context, snapshot)
    }

    private fun buildHomeBootstrapSnapshot(): PracticeHomeBootstrapSnapshot? {
        val snapshot = PracticeHomeBootstrapSnapshot(
            schemaVersion = 1,
            capturedAtMs = System.currentTimeMillis(),
            playerName = playerName.trim(),
            selectedGroupID = selectedGroupID,
            groups = groups,
            selectedLibrarySourceId = defaultPracticeSourceId,
            librarySources = librarySources.map { source ->
                PracticeHomeBootstrapSourceSnapshot(
                    id = source.id,
                    name = source.name,
                    typeRaw = source.type.rawValue,
                )
            },
            visibleGames = games.map(::homeBootstrapSnapshotGame),
            lookupGames = currentHomeBootstrapLookupGames().map(::homeBootstrapSnapshotGame),
        )
        return snapshot.takeIf { it.isUsable() }
    }

    private fun currentHomeBootstrapLookupGames(): List<PinballGame> {
        val combined = practiceLookupGames()
        val resumeCandidate = resumeSlugFromLibraryOrPractice()?.let(::gameForAnyID)
        val ordered = LinkedHashMap<String, PinballGame>()

        fun append(game: PinballGame?) {
            game ?: return
            val key = sourceScopedPracticeGameID(game.sourceId, game.practiceKey)
            ordered.putIfAbsent(key, game)
        }

        append(resumeCandidate)
        combined.forEach(::append)
        return ordered.values.toList()
    }

    private fun homeBootstrapSnapshotGame(game: PinballGame): PracticeHomeBootstrapGameSnapshot {
        return PracticeHomeBootstrapGameSnapshot(
            libraryEntryId = game.libraryEntryId,
            practiceIdentity = game.practiceIdentity,
            opdbId = game.opdbId,
            opdbGroupId = game.opdbGroupId,
            opdbMachineId = game.opdbMachineId,
            variant = game.variant,
            sourceId = game.sourceId,
            sourceName = game.sourceName,
            sourceTypeRaw = game.sourceType.rawValue,
            area = game.area,
            areaOrder = game.areaOrder,
            group = game.group,
            position = game.position,
            bank = game.bank,
            name = game.name,
            manufacturer = game.manufacturer,
            year = game.year,
            slug = game.slug,
            primaryImageUrl = game.primaryImageUrl,
            primaryImageLargeUrl = game.primaryImageLargeUrl,
            playfieldImageUrl = game.playfieldImageUrl,
            alternatePlayfieldImageUrl = game.alternatePlayfieldImageUrl,
            playfieldLocalOriginal = game.playfieldLocalOriginal,
            playfieldLocal = game.playfieldLocal,
        )
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

    private fun storedReferenceIds(): List<String> {
        val preferenceKeys = listOf(
            KEY_PRACTICE_LAST_VIEWED_SLUG,
            KEY_LIBRARY_LAST_VIEWED_SLUG,
        ) + QUICK_GAME_PREF_KEYS

        return buildList {
            addAll(groups.flatMap { it.gameSlugs })
            addAll(scores.map { it.gameSlug })
            addAll(notes.map { it.gameSlug })
            addAll(journal.map { it.gameSlug })
            addAll(rulesheetProgress.keys)
            addAll(gameSummaryNotes.keys)
            addAll(canonicalPersistedState.rulesheetResumeOffsets.keys)
            addAll(canonicalPersistedState.videoResumeHints.keys)
            addAll(canonicalPersistedState.gameSummaryNotes.keys)
            preferenceKeys.forEach { key ->
                prefs.getString(key, null)?.let(::add)
            }
        }
    }

    private fun needsBankTemplateGamesForStoredReferences(): Boolean {
        return storedReferenceIds().any { raw ->
            val trimmed = raw.trim()
            if (trimmed.isBlank()) return@any false
            val parsed = parseSourceScopedPracticeGameID(trimmed)
            parsed.sourceID != null && gameForAnyID(trimmed) == null
        }
    }

    private fun needsSearchCatalogForStoredReferences(): Boolean {
        if (searchCatalogGames.isNotEmpty()) return false

        return storedReferenceIds().any { raw ->
            val trimmed = raw.trim()
            if (trimmed.isBlank()) return@any false
            val parsed = parseSourceScopedPracticeGameID(trimmed)
            if (parsed.sourceID != null) return@any false
            gameForAnyID(trimmed) == null
        }
    }

    private fun needsAllLibraryGamesForStoredReferences(): Boolean {
        if (didLoadAllLibraryGames) return false

        return storedReferenceIds().any { raw ->
            val trimmed = raw.trim()
            if (trimmed.isBlank()) return@any false
            val parsed = parseSourceScopedPracticeGameID(trimmed)
            val sourceId = canonicalLibrarySourceId(parsed.sourceID)
            if (sourceId == null || sourceId == PM_AVENUE_LIBRARY_SOURCE_ID) return@any false
            gameForAnyID(trimmed) == null
        }
    }

}
