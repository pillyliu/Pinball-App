package com.pillyliu.pinprofandroid.practice

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.pillyliu.pinprofandroid.PinballPerformanceTrace
import com.pillyliu.pinprofandroid.league.LeaguePreviewRefreshEvents
import com.pillyliu.pinprofandroid.library.LibraryActivityLog
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.PinballGame
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

    val isLoadingSearchCatalog: Boolean
        get() = loadCoordinator.isLoadingSearchCatalog

    val isLoadingAllLibraryGames: Boolean
        get() = loadCoordinator.isLoadingAllLibraryGames

    val isLoadingLeagueTargets: Boolean
        get() = loadCoordinator.isLoadingLeagueTargets

    val didLoadLeagueTargets: Boolean
        get() = loadCoordinator.didLoadLeagueTargets

    val isBootstrapping: Boolean
        get() = loadCoordinator.isBootstrapping

    val hasRestoredHomeBootstrapSnapshot: Boolean
        get() = loadCoordinator.hasRestoredHomeBootstrapSnapshot

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

    var prpaPlayerID by mutableStateOf("")
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
        )
    }
    private val persistenceIntegration by lazy {
        PracticePersistenceIntegration(
            prefs = prefs,
            gameNameForSlug = ::gameName,
            quickGamePrefKeys = QUICK_GAME_PREF_KEYS,
        )
    }
    private val loadCoordinator by lazy {
        PracticeStoreLoadCoordinator(
            context = context,
            libraryIntegration = libraryIntegration,
            applyLibraryState = ::applyLibraryState,
            updateSearchCatalogGames = { loaded -> searchCatalogGames = loaded },
            updateBankTemplateGames = { loaded -> bankTemplateGames = loaded },
            saveHomeBootstrapSnapshot = ::saveHomeBootstrapSnapshotIfNeeded,
            ensureLeagueTargetsLoaded = leagueIntegration::ensureTargetsLoaded,
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
        if (loadCoordinator.leagueCatalogGames.isEmpty()) practiceLookupGames() else practiceLookupGames() + loadCoordinator.leagueCatalogGames

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
            ?: if (parsed.sourceID == null) findGameByPracticeLookupKey(loadCoordinator.leagueCatalogGames, id) else null
    }

    private fun applyPersistedState(payload: ParsedPracticeStatePayload) {
        val applied = appliedPracticeStorePersistedState(payload)
        canonicalPersistedState = applied.canonicalState
        rulesheetResumeOffsets = applied.rulesheetResumeOffsets
        applyRuntimePersistedState(applied.runtimeState)
    }

    private fun applyRuntimePersistedState(state: PracticePersistedState) {
        val applied = appliedPracticeRuntimeState(state)
        playerName = applied.playerName
        ifpaPlayerID = applied.ifpaPlayerID
        prpaPlayerID = applied.prpaPlayerID
        comparisonPlayerName = applied.comparisonPlayerName
        leaguePlayerName = applied.leaguePlayerName
        cloudSyncEnabled = applied.cloudSyncEnabled
        selectedGroupID = applied.selectedGroupID
        groups = applied.groups
        scores = applied.scores
        notes = applied.notes
        journal = applied.journal
        rulesheetProgress = applied.rulesheetProgress
        gameSummaryNotes = applied.gameSummaryNotes
    }

    suspend fun loadIfNeeded() {
        if (didLoad) {
            loadCoordinator.finishBootstrapping()
            return
        }
        didLoad = true
        try {
            PinballPerformanceTrace.measureSuspend("PracticeBootstrap") {
                val initialState = loadInitialPracticeStoreState(libraryIntegration, persistenceIntegration)
                applyLibraryState(initialState.libraryState)
                applyLoadedState(initialState.loadedState)
                val referenceLoadRequirements = practiceStoredReferenceLoadRequirements(
                    groups = groups,
                    scores = scores,
                    notes = notes,
                    journal = journal,
                    rulesheetProgress = rulesheetProgress,
                    gameSummaryNotes = gameSummaryNotes,
                    canonicalState = canonicalPersistedState,
                    prefs = prefs,
                    quickGamePrefKeys = QUICK_GAME_PREF_KEYS,
                    searchCatalogGamesLoaded = searchCatalogGames.isNotEmpty(),
                    fullLibraryLoaded = loadCoordinator.didLoadAllLibraryGames,
                    gameResolver = ::gameForAnyID,
                )
                if (referenceLoadRequirements.needsBankTemplateGames) {
                    ensureBankTemplateGamesLoaded()
                }
                if (referenceLoadRequirements.needsAllLibraryGames) {
                    ensureAllLibraryGamesLoaded()
                }
                if (referenceLoadRequirements.needsSearchCatalogGames) {
                    ensureSearchCatalogGamesLoaded()
                }
                val migrated = migrateLoadedStateToPracticeKeys()
                migratePreferenceGameKeysToPracticeKeys()
                if (practiceRequiresCanonicalSaveAfterInitialLoad(initialState.loadedState, migrated)) {
                    saveState()
                    persistenceIntegration.clearLegacyState()
                }
                saveHomeBootstrapSnapshotIfNeeded()
            }
        } finally {
            loadCoordinator.finishBootstrapping()
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

    fun updatePrpaPlayerID(value: String) {
        mutateAndSave { prpaPlayerID = value.trim() }
    }

    fun updateComparisonPlayerName(name: String) {
        mutateAndSave { comparisonPlayerName = name.trim() }
    }

    fun updateLeaguePlayerName(name: String) {
        val trimmed = name.trim()
        leaguePlayerName = trimmed
        canonicalPersistedState = updatedPracticeCanonicalStateForLeaguePlayer(
            canonicalState = canonicalPersistedState,
            playerName = trimmed,
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
            canonicalPersistedState = updatedPracticeCanonicalStateAfterLeagueImport(
                canonicalState = canonicalPersistedState,
                selectedPlayer = selectedPlayer,
                importedAtMs = System.currentTimeMillis(),
            )
            refreshRuntimeFromCanonical()
            saveState()
        }
        return result
    }

    suspend fun autoImportLeagueScoresIfEnabled(): LeagueImportResult? {
        val nowMs = System.currentTimeMillis()
        val lookupGameCount = practiceLookupGames().size
        if (leaguePlayerName.isBlank() || lookupGameCount == 0) return null
        if (isAutoImportingLeagueScores || (nowMs - lastLeagueAutoImportAttemptMs) < 60_000L) return null

        val hasRemoteUpdate = runCatching {
            com.pillyliu.pinprofandroid.data.PinballDataCache.hasRemoteUpdate(
                com.pillyliu.pinprofandroid.library.hostedLeagueStatsPath,
            )
        }.getOrDefault(false)
        val statsUpdatedAtMs = runCatching {
            leagueIntegration.statsUpdatedAtMs(forceRefresh = hasRemoteUpdate)
        }.getOrNull()

        if (
            !shouldPracticeAutoImportLeagueScores(
                leaguePlayerName = leaguePlayerName,
                practiceLookupGameCount = lookupGameCount,
                isAutoImportingLeagueScores = isAutoImportingLeagueScores,
                nowMs = nowMs,
                lastLeagueAutoImportAttemptMs = lastLeagueAutoImportAttemptMs,
                hasRemoteUpdate = hasRemoteUpdate,
                statsUpdatedAtMs = statsUpdatedAtMs,
                leagueSettings = canonicalPersistedState.leagueSettings,
            )
        ) {
            return null
        }

        isAutoImportingLeagueScores = true
        lastLeagueAutoImportAttemptMs = nowMs
        return try {
            val result = importLeagueScoresFromCsvResult(forceRefresh = false)
            result.takeIf { it.errorMessage == null && it.hasChanges }
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
        val purged = purgedImportedLeagueState(canonicalPersistedState)
        canonicalPersistedState = purged.canonicalState
        refreshRuntimeFromCanonical()
        saveState()
        saveHomeBootstrapSnapshotIfNeeded()
        return purged.removedCount
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
        val applied = appliedPracticeLibrarySelectionState(
            sourceId = sourceId,
            currentVisibleGames = games,
            allGames = allLibraryGames,
            sources = librarySources,
        )
        defaultPracticeSourceId = applied.selectedSourceId
        games = applied.visibleGames
        libraryIntegration.persistSelectedSource(applied.selectedSourceId)
        saveHomeBootstrapSnapshotIfNeeded()
    }

    suspend fun loadGames() {
        loadCoordinator.loadGames()
    }

    suspend fun ensureAllLibraryGamesLoaded() {
        loadCoordinator.ensureAllLibraryGamesLoaded()
    }

    private fun applyLibraryState(libraryState: PracticeLibraryStoreState) {
        val applied = appliedPracticeLibraryState(libraryState)
        games = applied.visibleGames
        allLibraryGames = applied.allGames
        librarySources = applied.sources
        defaultPracticeSourceId = applied.defaultSourceId
        loadCoordinator.setDidLoadAllLibraryGames(applied.isFullLibraryScope)
        applied.persistedSelectedSourceId?.let { sourceId ->
            libraryIntegration.persistSelectedSource(sourceId)
        }
    }

    suspend fun ensureSearchCatalogGamesLoaded() {
        loadCoordinator.ensureSearchCatalogGamesLoaded(searchCatalogGames)
    }

    private suspend fun ensureLeagueCatalogGamesLoaded() {
        loadCoordinator.ensureLeagueCatalogGamesLoaded()
    }

    suspend fun ensureBankTemplateGamesLoaded() {
        loadCoordinator.ensureBankTemplateGamesLoaded(bankTemplateGames)
    }

    suspend fun ensureLeagueTargetsLoaded() {
        loadCoordinator.ensureLeagueTargetsLoaded()
    }

    private fun applyLoadedState(loaded: LoadedPracticeStatePayload?) {
        val payload = loaded?.payload ?: return
        applyPersistedState(payload)
    }

    private fun migrateLoadedStateToPracticeKeys(): Boolean {
        val lookupGames = practiceLookupGames()
        val migrated = persistenceIntegration.migrateLoadedState(
            lookupGames = lookupGames,
            runtimeState = practiceStoreRuntimeState(
                playerName = playerName,
                ifpaPlayerID = ifpaPlayerID,
                prpaPlayerID = prpaPlayerID,
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
            canonicalState = canonicalPersistedState,
        ) ?: return false
        val applied = appliedPracticeStorePersistedState(
            canonicalState = migrated.canonicalState,
            runtimeState = migrated.runtimeState,
        )
        canonicalPersistedState = applied.canonicalState
        rulesheetResumeOffsets = applied.rulesheetResumeOffsets
        applyRuntimePersistedState(applied.runtimeState)
        saveState()
        return true
    }

    private fun migratePreferenceGameKeysToPracticeKeys() {
        persistenceIntegration.migratePreferenceGameKeys(practiceLookupGames())
    }

    private fun restoreHomeBootstrapSnapshotIfAvailable() {
        val snapshot = loadPracticeHomeBootstrapRestorePayload(context) ?: run {
            loadCoordinator.recordHomeBootstrapRestore(false)
            return
        }
        val restored = appliedPracticeHomeBootstrapState(snapshot)
        canonicalPersistedState = restored.canonicalState
        rulesheetResumeOffsets = restored.rulesheetResumeOffsets
        applyRuntimePersistedState(restored.runtimeState)
        games = restored.visibleGames
        allLibraryGames = restored.lookupGames
        librarySources = restored.librarySources
        defaultPracticeSourceId = restored.selectedLibrarySourceId
        loadCoordinator.recordHomeBootstrapRestore(restored.hasUsableSnapshot)
    }

    private fun saveHomeBootstrapSnapshotIfNeeded() {
        savePracticeStoreHomeBootstrapSnapshot(
            context = context,
            playerName = playerName,
            selectedGroupID = selectedGroupID,
            groups = groups,
            selectedLibrarySourceId = defaultPracticeSourceId,
            librarySources = librarySources,
            visibleGames = games,
            combinedLookupGames = practiceLookupGames(),
            resumeSlug = resumeSlugFromLibraryOrPractice(),
            gameResolver = ::gameForAnyID,
        )
    }

    private fun saveState() {
        val persistenceState = practiceStorePersistenceState(
            canonicalState = canonicalPersistedState,
            rulesheetResumeOffsets = rulesheetResumeOffsets,
            playerName = playerName,
            ifpaPlayerID = ifpaPlayerID,
            prpaPlayerID = prpaPlayerID,
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
        canonicalPersistedState = persistenceIntegration.saveState(
            runtimeState = persistenceState.runtimeState,
            shadowState = persistenceState.shadowState,
        )
    }

    private fun refreshRuntimeFromCanonical() {
        val applied = appliedPracticeCanonicalRefresh(
            canonicalState = canonicalPersistedState,
            gameName = ::gameName,
        )
        rulesheetResumeOffsets = applied.rulesheetResumeOffsets
        applyRuntimePersistedState(applied.runtimeState)
    }

}
