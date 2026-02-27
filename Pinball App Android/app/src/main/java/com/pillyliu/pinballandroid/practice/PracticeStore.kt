package com.pillyliu.pinballandroid.practice

import android.content.Context
import androidx.core.content.edit
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.pillyliu.pinballandroid.library.LibraryActivityLog
import com.pillyliu.pinballandroid.library.LibrarySource
import com.pillyliu.pinballandroid.library.PinballGame
import java.util.UUID
import kotlin.math.abs

private const val LEAGUE_TARGETS_PATH = "/pinball/data/LPL_Targets.csv"

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

    private var leagueTargetsByNormalizedMachine: Map<String, LeagueTargetScores> = emptyMap()

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

    fun journalItems(filter: JournalFilter): List<JournalEntry> = filteredJournalItems(journal, filter)

    fun canEditJournalEntry(entry: JournalEntry): Boolean = isUserEditablePracticeJournalEntry(entry)

    fun journalEditDraft(entry: JournalEntry): PracticeJournalEditDraft? {
        if (!canEditJournalEntry(entry)) return null
        val canonical = canonicalPersistedState.journalEntries.firstOrNull { it.id == entry.id }
            ?: return parsePracticeJournalEditDraft(entry, gameName(entry.gameSlug), scores, notes)
        return canonicalDraftForJournalEntry(canonical)
    }

    fun updateJournalEntry(draft: PracticeJournalEditDraft): Boolean {
        val journalIndex = canonicalPersistedState.journalEntries.indexOfFirst { it.id == draft.id }
        if (journalIndex < 0) return false
        val original = canonicalPersistedState.journalEntries[journalIndex]
        val canonicalGameSlug = canonicalPracticeKey(draft.gameSlug, practiceLookupGames())
        if (canonicalGameSlug.isBlank()) return false

        when (draft.kind) {
            PracticeJournalEditKind.Score -> {
                val score = draft.score ?: return false
                val contextBase = draft.scoreContext?.trim().orEmpty().ifBlank { "practice" }
                val context = if (contextBase == "tournament") "tournament" else contextBase
                val tournamentName = if (context == "tournament") draft.tournamentName?.trim()?.ifBlank { null } else null
                val scoreEntryIndex = matchingCanonicalScoreEntryIndex(original)
                if (scoreEntryIndex != null) {
                    val existing = canonicalPersistedState.scoreEntries[scoreEntryIndex]
                    canonicalPersistedState = canonicalPersistedState.copy(
                        scoreEntries = canonicalPersistedState.scoreEntries.toMutableList().apply {
                            this[scoreEntryIndex] = existing.copy(
                                gameID = canonicalGameSlug,
                                score = score,
                                context = context,
                                tournamentName = tournamentName,
                            )
                        }
                    )
                }
                canonicalPersistedState = canonicalPersistedState.copy(
                    journalEntries = canonicalPersistedState.journalEntries.toMutableList().apply {
                        this[journalIndex] = original.copy(
                            gameID = canonicalGameSlug,
                            score = score,
                            scoreContext = context,
                            tournamentName = tournamentName,
                        )
                    }
                )
            }

            PracticeJournalEditKind.Note, PracticeJournalEditKind.Mechanics -> {
                val noteText = draft.noteText?.trim().orEmpty()
                if (noteText.isBlank()) return false
                val category = draft.noteCategory?.trim().orEmpty().ifBlank { if (draft.kind == PracticeJournalEditKind.Mechanics) "mechanics" else "general" }
                val noteEntryIndex = matchingCanonicalNoteEntryIndex(original)
                if (noteEntryIndex != null) {
                    val existing = canonicalPersistedState.noteEntries[noteEntryIndex]
                    canonicalPersistedState = canonicalPersistedState.copy(
                        noteEntries = canonicalPersistedState.noteEntries.toMutableList().apply {
                            this[noteEntryIndex] = existing.copy(
                                gameID = canonicalGameSlug,
                                category = category,
                                detail = draft.noteDetail?.trim()?.ifBlank { null },
                                note = noteText,
                            )
                        }
                    )
                }
                canonicalPersistedState = canonicalPersistedState.copy(
                    journalEntries = canonicalPersistedState.journalEntries.toMutableList().apply {
                        this[journalIndex] = original.copy(
                            gameID = canonicalGameSlug,
                            noteCategory = category,
                            noteDetail = draft.noteDetail?.trim()?.ifBlank { null },
                            note = noteText,
                        )
                    }
                )
            }

            PracticeJournalEditKind.Study, PracticeJournalEditKind.Practice -> {
                val category = draft.studyCategory?.trim().orEmpty().lowercase()
                val value = draft.studyValue?.trim().orEmpty()
                if (category.isBlank() || value.isBlank()) return false
                val note = draft.studyNote?.trim()?.ifBlank { null }
                val action = when (category) {
                    "rulesheet" -> "rulesheetRead"
                    "tutorial" -> "tutorialWatch"
                    "gameplay" -> "gameplayWatch"
                    "playfield" -> "playfieldViewed"
                    "practice" -> "practiceSession"
                    else -> if (draft.kind == PracticeJournalEditKind.Practice) "practiceSession" else "rulesheetRead"
                }
                val task = when (category) {
                    "rulesheet" -> "rulesheet"
                    "tutorial" -> "tutorialVideo"
                    "gameplay" -> "gameplayVideo"
                    "playfield" -> "playfield"
                    "practice" -> "practice"
                    else -> if (draft.kind == PracticeJournalEditKind.Practice) "practice" else "rulesheet"
                }
                val progressPercent = Regex("""(\d{1,3})\s*%?""").find(value)?.groupValues?.getOrNull(1)?.toIntOrNull()?.coerceIn(0, 100)
                    ?.takeIf { category == "rulesheet" || category == "tutorial" || category == "gameplay" }
                val videoKind = if (category == "tutorial" || category == "gameplay") {
                    if (value.contains(":")) "clock" else "percent"
                } else null
                val videoValue = if (category == "tutorial" || category == "gameplay") value else null
                val journalNote = if (category == "practice") composePracticeSessionNote(value, note) else note
                val updatedJournal = original.copy(
                    gameID = canonicalGameSlug,
                    action = action,
                    task = task,
                    progressPercent = progressPercent,
                    videoKind = videoKind,
                    videoValue = videoValue,
                    note = journalNote,
                )

                val studyIndex = matchingCanonicalStudyEventIndex(original, original.task)
                val nextStudyEvents = canonicalPersistedState.studyEvents.toMutableList()
                if (progressPercent != null) {
                    if (studyIndex != null) {
                        val existing = nextStudyEvents[studyIndex]
                        nextStudyEvents[studyIndex] = existing.copy(
                            gameID = canonicalGameSlug,
                            task = task,
                            progressPercent = progressPercent,
                        )
                    } else {
                        nextStudyEvents += CanonicalStudyProgressEvent(
                            id = UUID.randomUUID().toString(),
                            gameID = canonicalGameSlug,
                            task = task,
                            progressPercent = progressPercent,
                            timestampMs = original.timestampMs,
                        )
                    }
                } else if (studyIndex != null) {
                    nextStudyEvents.removeAt(studyIndex)
                }
                val videoIndex = matchingCanonicalVideoEntryIndex(original)
                val nextVideos = canonicalPersistedState.videoProgressEntries.toMutableList()
                if (!videoValue.isNullOrBlank()) {
                    if (videoIndex != null) {
                        val existing = nextVideos[videoIndex]
                        nextVideos[videoIndex] = existing.copy(
                            gameID = canonicalGameSlug,
                            kind = videoKind ?: existing.kind,
                            value = videoValue,
                        )
                    } else {
                        nextVideos += CanonicalVideoProgressEntry(
                            id = UUID.randomUUID().toString(),
                            gameID = canonicalGameSlug,
                            kind = videoKind ?: "percent",
                            value = videoValue,
                            timestampMs = original.timestampMs,
                        )
                    }
                } else if (videoIndex != null) {
                    nextVideos.removeAt(videoIndex)
                }

                canonicalPersistedState = canonicalPersistedState.copy(
                    studyEvents = nextStudyEvents,
                    videoProgressEntries = nextVideos,
                    journalEntries = canonicalPersistedState.journalEntries.toMutableList().apply {
                        this[journalIndex] = updatedJournal
                    },
                )
            }
        }

        refreshRuntimeFromCanonical()
        saveState()
        return true
    }

    fun deleteJournalEntry(entryId: String): Boolean {
        val journalIndex = canonicalPersistedState.journalEntries.indexOfFirst { it.id == entryId }
        if (journalIndex < 0) return false
        val entry = canonicalPersistedState.journalEntries[journalIndex]
        val legacyEntry = journal.firstOrNull { it.id == entryId }
        if (legacyEntry != null && !canEditJournalEntry(legacyEntry)) return false

        val nextJournal = canonicalPersistedState.journalEntries.toMutableList().apply { removeAt(journalIndex) }
        val nextScores = canonicalPersistedState.scoreEntries.toMutableList()
        val nextNotes = canonicalPersistedState.noteEntries.toMutableList()
        val nextStudyEvents = canonicalPersistedState.studyEvents.toMutableList()
        val nextVideos = canonicalPersistedState.videoProgressEntries.toMutableList()

        when (entry.action) {
            "scoreLogged" -> matchingCanonicalScoreEntryIndex(entry)?.let { nextScores.removeAt(it) }
            "noteAdded" -> matchingCanonicalNoteEntryIndex(entry)?.let { nextNotes.removeAt(it) }
            "rulesheetRead", "playfieldViewed", "practiceSession", "tutorialWatch", "gameplayWatch" -> {
                matchingCanonicalStudyEventIndex(entry, entry.task)?.let { nextStudyEvents.removeAt(it) }
                if (entry.action == "tutorialWatch" || entry.action == "gameplayWatch") {
                    matchingCanonicalVideoEntryIndex(entry)?.let { nextVideos.removeAt(it) }
                }
            }
        }

        canonicalPersistedState = canonicalPersistedState.copy(
            journalEntries = nextJournal,
            scoreEntries = nextScores,
            noteEntries = nextNotes,
            studyEvents = nextStudyEvents,
            videoProgressEntries = nextVideos,
        )
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
        leagueTargetScoresForSlug(canonicalPracticeKey(gameSlug, practiceLookupGames()), practiceLookupGames(), ::leagueTargetScoresForGameName)

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
        defaultPracticeSourceId?.let { sourceId ->
            prefs.edit { putString(KEY_PREFERRED_LIBRARY_SOURCE_ID, sourceId) }
        }
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

    private fun canonicalDraftForJournalEntry(entry: CanonicalJournalEntry): PracticeJournalEditDraft? {
        return when (entry.action) {
            "scoreLogged" -> PracticeJournalEditDraft(
                id = entry.id,
                kind = PracticeJournalEditKind.Score,
                gameSlug = entry.gameID,
                timestampMs = entry.timestampMs,
                score = entry.score,
                scoreContext = entry.scoreContext ?: "practice",
                tournamentName = entry.tournamentName,
            )
            "noteAdded" -> {
                val category = entry.noteCategory ?: "general"
                PracticeJournalEditDraft(
                    id = entry.id,
                    kind = if (category == "mechanics") PracticeJournalEditKind.Mechanics else PracticeJournalEditKind.Note,
                    gameSlug = entry.gameID,
                    timestampMs = entry.timestampMs,
                    noteCategory = category,
                    noteDetail = entry.noteDetail,
                    noteText = entry.note ?: "",
                )
            }
            "rulesheetRead", "tutorialWatch", "gameplayWatch", "playfieldViewed", "practiceSession" -> {
                val category = when (entry.action) {
                    "rulesheetRead" -> "rulesheet"
                    "tutorialWatch" -> "tutorial"
                    "gameplayWatch" -> "gameplay"
                    "playfieldViewed" -> "playfield"
                    "practiceSession" -> "practice"
                    else -> "study"
                }
                val value = when (entry.action) {
                    "rulesheetRead" -> entry.progressPercent?.let { "$it%" } ?: "0%"
                    "tutorialWatch", "gameplayWatch" -> entry.videoValue ?: (entry.progressPercent?.let { "$it%" } ?: "0%")
                    "playfieldViewed" -> "Viewed"
                    "practiceSession" -> parsePracticeSessionParts(value = entry.note, note = null).value
                    else -> entry.note ?: "Updated"
                }
                val practiceParts = if (entry.action == "practiceSession") {
                    parsePracticeSessionParts(value = entry.note, note = null)
                } else {
                    null
                }
                PracticeJournalEditDraft(
                    id = entry.id,
                    kind = if (entry.action == "practiceSession") PracticeJournalEditKind.Practice else PracticeJournalEditKind.Study,
                    gameSlug = entry.gameID,
                    timestampMs = entry.timestampMs,
                    studyCategory = category,
                    studyValue = value,
                    studyNote = if (entry.action == "practiceSession") practiceParts?.note else entry.note,
                )
            }
            else -> null
        }
    }

    private fun matchingCanonicalScoreEntryIndex(journalEntry: CanonicalJournalEntry): Int? {
        val expectedTournament = journalEntry.tournamentName?.trim().orEmpty()
        return canonicalPersistedState.scoreEntries.withIndex()
            .filter { (_, entry) ->
                entry.gameID == journalEntry.gameID &&
                    (journalEntry.scoreContext == null || entry.context == journalEntry.scoreContext) &&
                    (journalEntry.score == null || abs(entry.score - journalEntry.score) <= 0.5) &&
                    ((expectedTournament.isEmpty() && entry.tournamentName.isNullOrBlank()) ||
                        entry.tournamentName?.trim().orEmpty().equals(expectedTournament, ignoreCase = true))
            }
            .minByOrNull { abs(it.value.timestampMs - journalEntry.timestampMs) }
            ?.index
    }

    private fun matchingCanonicalNoteEntryIndex(journalEntry: CanonicalJournalEntry): Int? {
        return canonicalPersistedState.noteEntries.withIndex()
            .filter { (_, entry) ->
                entry.gameID == journalEntry.gameID &&
                    (journalEntry.noteCategory == null || entry.category == journalEntry.noteCategory) &&
                    (journalEntry.noteDetail.isNullOrBlank() || (entry.detail?.trim().orEmpty().equals(journalEntry.noteDetail.trim(), ignoreCase = true))) &&
                    (journalEntry.note.isNullOrBlank() || entry.note.trim() == journalEntry.note.trim())
            }
            .minByOrNull { abs(it.value.timestampMs - journalEntry.timestampMs) }
            ?.index
    }

    private fun matchingCanonicalStudyEventIndex(journalEntry: CanonicalJournalEntry, taskOverride: String?): Int? {
        val task = taskOverride ?: journalEntry.task ?: return null
        return canonicalPersistedState.studyEvents.withIndex()
            .filter { (_, entry) ->
                entry.gameID == journalEntry.gameID &&
                    entry.task == task &&
                    (journalEntry.progressPercent == null || entry.progressPercent == journalEntry.progressPercent)
            }
            .minByOrNull { abs(it.value.timestampMs - journalEntry.timestampMs) }
            ?.index
    }

    private fun matchingCanonicalVideoEntryIndex(journalEntry: CanonicalJournalEntry): Int? {
        return canonicalPersistedState.videoProgressEntries.withIndex()
            .filter { (_, entry) ->
                entry.gameID == journalEntry.gameID &&
                    (journalEntry.videoKind == null || entry.kind == journalEntry.videoKind) &&
                    (journalEntry.videoValue.isNullOrBlank() || entry.value.trim() == journalEntry.videoValue.trim())
            }
            .minByOrNull { abs(it.value.timestampMs - journalEntry.timestampMs) }
            ?.index
    }

    private suspend fun loadLeagueTargets() {
        leagueTargetsByNormalizedMachine = loadLeagueTargetsMap(LEAGUE_TARGETS_PATH)
    }

    private fun leagueTargetScoresForGameName(gameName: String): LeagueTargetScores? =
        resolveLeagueTargetScores(gameName, leagueTargetsByNormalizedMachine)
}
