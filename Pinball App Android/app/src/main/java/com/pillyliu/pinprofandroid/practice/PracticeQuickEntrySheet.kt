package com.pillyliu.pinprofandroid.practice

import androidx.core.content.edit
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore
import com.pillyliu.pinprofandroid.library.isAvenueLibrarySourceId
import com.pillyliu.pinprofandroid.ui.AppTextAction
import com.pillyliu.pinprofandroid.ui.dismissKeyboardOnTapOutside
import kotlin.math.roundToInt

@Composable
internal fun QuickEntrySheet(
    store: PracticeStore,
    selectedGameSlug: String?,
    presetActivity: QuickActivity,
    origin: QuickEntryOrigin,
    fromGameView: Boolean,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit,
) {
    val context = LocalContext.current
    val prefs = remember { practiceSharedPreferences(context) }
    var mode by remember(presetActivity) { mutableStateOf(presetActivity) }
    var showScoreScanner by remember { mutableStateOf(false) }
    val studyActivities = remember {
        listOf(QuickActivity.Rulesheet, QuickActivity.Tutorial, QuickActivity.Gameplay, QuickActivity.Playfield)
    }
    val fixedModeForOrigin = when (origin) {
        QuickEntryOrigin.Study -> if (fromGameView) presetActivity else null
        QuickEntryOrigin.Score -> QuickActivity.Score
        QuickEntryOrigin.Practice -> QuickActivity.Practice
        QuickEntryOrigin.Mechanics -> QuickActivity.Mechanics
    }
    val showActivityDropdown = origin == QuickEntryOrigin.Study && !fromGameView
    val allLibraryGames = remember(store.games, store.allLibraryGames) {
        if (store.allLibraryGames.isNotEmpty()) store.allLibraryGames else store.games
    }
    val librarySources = remember(store.librarySources, allLibraryGames) {
        if (store.librarySources.isNotEmpty()) {
            store.librarySources
        } else {
            allLibraryGames
                .groupBy { it.sourceId }
                .mapNotNull { (_, rows) ->
                    val first = rows.firstOrNull() ?: return@mapNotNull null
                    object {
                        val id = first.sourceId
                        val name = first.sourceName
                    }
                }
                .map { com.pillyliu.pinprofandroid.library.LibrarySource(it.id, it.name, allLibraryGames.firstOrNull { g -> g.sourceId == it.id }?.sourceType ?: com.pillyliu.pinprofandroid.library.LibrarySourceType.VENUE) }
        }
    }
    val showLibraryDropdown = !fromGameView && librarySources.size > 1
    fun avenueLibraryOptionId(): String? {
        return librarySources.firstOrNull { isAvenueLibrarySourceId(it.id) }?.id
            ?: librarySources.firstOrNull { it.name.contains("the avenue", ignoreCase = true) }?.id
    }
    fun canonicalExistingQuickGameKey(raw: String?): String {
        val canonical = canonicalPracticeKey(raw, allLibraryGames)
        return canonical.takeIf { it.isNotBlank() && findGameByPracticeLookupKey(allLibraryGames, it) != null }.orEmpty()
    }
    val resumeGameSlug = remember(store.games, store.allLibraryGames) {
        canonicalExistingQuickGameKey(store.resumeSlugFromLibraryOrPractice())
    }
    val resumeGameSourceId = remember(resumeGameSlug, allLibraryGames) {
        findGameByPracticeLookupKey(allLibraryGames, resumeGameSlug)?.sourceId.orEmpty()
    }
    val savedQuickGameSlug = remember(origin, store.games, store.allLibraryGames) {
        canonicalExistingQuickGameKey(prefs.getString("$QUICK_GAME_KEY_PREFIX${origin.keySuffix}", null))
    }
    val currentSelectedGameSlug = remember(selectedGameSlug, store.games, store.allLibraryGames) {
        canonicalExistingQuickGameKey(selectedGameSlug)
    }
    val currentSelectedGameSourceId = remember(currentSelectedGameSlug, allLibraryGames) {
        findGameByPracticeLookupKey(allLibraryGames, currentSelectedGameSlug)?.sourceId.orEmpty()
    }
    val fallbackGameSlug = remember(store.games, store.allLibraryGames) {
        orderedGamesForDropdown(allLibraryGames, collapseByPracticeIdentity = true).firstOrNull()?.practiceKey.orEmpty()
    }
    var selectedLibraryOption by remember(
        origin,
        fromGameView,
        librarySources,
        store.defaultPracticeSourceId,
        resumeGameSourceId,
        currentSelectedGameSourceId,
    ) {
        val saved = prefs.getString("$QUICK_LIBRARY_KEY_PREFIX${origin.keySuffix}", null)
        val preferred = LibrarySourceStateStore.load(context).selectedSourceId
        val avenue = avenueLibraryOptionId()
        val initial = resolveInitialQuickEntryLibraryOption(
            origin = origin,
            fromGameView = fromGameView,
            selectedGameSourceId = currentSelectedGameSourceId,
            resumeGameSourceId = resumeGameSourceId,
            savedLibraryOption = saved.orEmpty(),
            preferredLibraryOption = preferred.orEmpty(),
            avenueLibraryOption = avenue.orEmpty(),
            defaultPracticeSourceId = store.defaultPracticeSourceId.orEmpty(),
            availableLibraryOptionIds = librarySources.mapTo(linkedSetOf()) { it.id },
        )
        mutableStateOf(initial)
    }
    var gameSlug by remember(
        origin,
        fromGameView,
        resumeGameSlug,
        currentSelectedGameSlug,
        savedQuickGameSlug,
        fallbackGameSlug,
    ) {
        mutableStateOf(
            resolveInitialQuickEntryGameSlug(
                origin = origin,
                fromGameView = fromGameView,
                selectedGameSlug = currentSelectedGameSlug,
                resumeGameSlug = resumeGameSlug,
                savedQuickGameSlug = savedQuickGameSlug,
                fallbackGameSlug = fallbackGameSlug,
            )
        )
    }
    var scoreText by remember { mutableStateOf("") }
    var scoreContext by remember { mutableStateOf("practice") }
    var tournamentName by remember { mutableStateOf("") }
    var rulesheetProgress by remember { mutableFloatStateOf(0f) }
    var videoInputKind by remember { mutableStateOf(DEFAULT_PRACTICE_VIDEO_INPUT_KIND) }
    var selectedVideoSource by remember { mutableStateOf("") }
    var videoWatchedTime by remember { mutableStateOf("") }
    var videoTotalTime by remember { mutableStateOf("") }
    var videoPercent by remember { mutableFloatStateOf(100f) }
    var practiceMinutes by remember { mutableStateOf("") }
    var practiceCategory by remember { mutableStateOf("general") }
    var noteText by remember { mutableStateOf("") }
    var mechanicsSkill by remember { mutableStateOf("Drop Catch") }
    var mechanicsCompetency by remember { mutableFloatStateOf(3f) }
    var validation by remember { mutableStateOf<String?>(null) }
    val libraryFilteredGames = remember(allLibraryGames, selectedLibraryOption) {
        if (selectedLibraryOption == ALL_GAMES_LIBRARY_OPTION) {
            allLibraryGames
        } else {
            allLibraryGames.filter { it.sourceId == selectedLibraryOption }
        }
    }
    val gameOptions = remember(libraryFilteredGames) {
        orderedGamesForDropdown(libraryFilteredGames, collapseByPracticeIdentity = true)
    }
    val mechanicsSkills = store.allTrackedMechanicsSkills()
    LaunchedEffect(mechanicsSkills) {
        if (mechanicsSkills.isNotEmpty() && !mechanicsSkills.contains(mechanicsSkill)) {
            mechanicsSkill = mechanicsSkills.first()
        }
    }
    LaunchedEffect(origin, presetActivity, fromGameView) {
        if (showActivityDropdown) {
            if (mode !in studyActivities) {
                mode = QuickActivity.Rulesheet
            }
        } else if (fixedModeForOrigin != null) {
            mode = fixedModeForOrigin
        }
    }
    LaunchedEffect(fromGameView, selectedGameSlug, allLibraryGames) {
        if (fromGameView && origin != QuickEntryOrigin.Mechanics) {
            gameSlug = canonicalExistingQuickGameKey(selectedGameSlug)
        }
    }
    LaunchedEffect(mode, gameOptions) {
        if (mode == QuickActivity.Mechanics) return@LaunchedEffect
        val selectedStillAvailable = findGameByPracticeLookupKey(gameOptions, gameSlug) != null
        if (gameSlug.isBlank() || gameSlug == "None" || !selectedStillAvailable) {
            gameSlug = gameOptions.firstOrNull()?.practiceKey.orEmpty()
        }
    }
    LaunchedEffect(showLibraryDropdown, selectedLibraryOption) {
        if (!showLibraryDropdown) return@LaunchedEffect
        prefs.edit {
            putString("$QUICK_LIBRARY_KEY_PREFIX${origin.keySuffix}", selectedLibraryOption)
        }
        if (selectedLibraryOption != ALL_GAMES_LIBRARY_OPTION) {
            LibrarySourceStateStore.setSelectedSource(context, selectedLibraryOption)
        }
    }
    val selectedGame = findGameByPracticeLookupKey(allLibraryGames, gameSlug)
    val videoSourceOptions = remember(selectedGame, mode) {
        quickEntryVideoSourceOptions(selectedGame, mode)
    }
    LaunchedEffect(mode, videoSourceOptions) {
        if (mode != QuickActivity.Tutorial && mode != QuickActivity.Gameplay) return@LaunchedEffect
        if (selectedVideoSource !in videoSourceOptions) {
            selectedVideoSource = videoSourceOptions.firstOrNull().orEmpty()
        }
    }
    LaunchedEffect(origin, gameSlug) {
        val selected = gameSlug.takeUnless { it == "None" }.orEmpty()
        if (selected.isNotBlank()) {
            prefs.edit { putString("$QUICK_GAME_KEY_PREFIX${origin.keySuffix}", selected) }
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier.dismissKeyboardOnTapOutside(),
        title = { Text("Quick Entry") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                QuickEntrySelectionFields(
                    fromGameView = fromGameView,
                    showLibraryDropdown = showLibraryDropdown,
                    librarySources = librarySources,
                    selectedLibraryOption = selectedLibraryOption,
                    onLibraryOptionChange = { selectedLibraryOption = it },
                    mode = mode,
                    showActivityDropdown = showActivityDropdown,
                    studyActivities = studyActivities,
                    onActivityChange = { mode = it },
                    gameOptions = gameOptions,
                    gameSlug = gameSlug,
                    onGameSlugChange = { gameSlug = it },
                )

                QuickEntryModeFields(
                    mode = mode,
                    scoreText = scoreText,
                    onScoreTextChange = { scoreText = formatScoreInputWithCommas(it) },
                    scoreContext = scoreContext,
                    onScoreContextChange = { scoreContext = it },
                    tournamentName = tournamentName,
                    onTournamentNameChange = { tournamentName = it },
                    rulesheetProgress = rulesheetProgress,
                    onRulesheetProgressChange = { rulesheetProgress = it },
                    videoInputKind = videoInputKind,
                    onVideoInputKindChange = { videoInputKind = it },
                    videoSourceOptions = videoSourceOptions,
                    selectedVideoSource = selectedVideoSource,
                    onSelectedVideoSourceChange = { selectedVideoSource = it },
                    videoWatchedTime = videoWatchedTime,
                    onVideoWatchedTimeChange = { videoWatchedTime = it },
                    videoTotalTime = videoTotalTime,
                    onVideoTotalTimeChange = { videoTotalTime = it },
                    videoPercent = videoPercent,
                    onVideoPercentChange = { videoPercent = it },
                    practiceMinutes = practiceMinutes,
                    onPracticeMinutesChange = { practiceMinutes = it },
                    practiceCategory = practiceCategory,
                    onPracticeCategoryChange = { practiceCategory = it },
                    noteText = noteText,
                    onNoteTextChange = { noteText = it },
                    mechanicsSkill = mechanicsSkill,
                    onMechanicsSkillChange = { mechanicsSkill = it },
                    mechanicsSkills = mechanicsSkills,
                    mechanicsCompetency = mechanicsCompetency,
                    onMechanicsCompetencyChange = { mechanicsCompetency = it.roundToInt().toFloat() },
                    onOpenScoreScanner = if (mode == QuickActivity.Score) {
                        {
                            validation = null
                            showScoreScanner = true
                        }
                    } else {
                        null
                    },
                )
                validation?.let {
                    Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = {
            val selectedSlugForEnable = gameSlug.takeUnless { it == "None" }.orEmpty()
            AppTextAction(text = "Save", onClick = {
                validation = null
                val result = saveQuickEntry(
                    store = store,
                    mode = mode,
                    rawGameSlug = gameSlug,
                    scoreText = scoreText,
                    scoreContext = scoreContext,
                    tournamentName = tournamentName,
                    rulesheetProgress = rulesheetProgress,
                    videoInputKind = videoInputKind,
                    selectedVideoSource = selectedVideoSource,
                    videoWatchedTime = videoWatchedTime,
                    videoTotalTime = videoTotalTime,
                    videoPercent = videoPercent,
                    practiceMinutes = practiceMinutes,
                    practiceCategory = practiceCategory,
                    noteText = noteText,
                    mechanicsSkill = mechanicsSkill,
                    mechanicsCompetency = mechanicsCompetency,
                )
                if (result.validationMessage != null) {
                    validation = result.validationMessage
                    return@AppTextAction
                }
                result.savedSlug?.let(onSave)
            }, enabled = mode == QuickActivity.Mechanics || selectedSlugForEnable.isNotBlank())
        },
        dismissButton = { AppTextAction(text = "Cancel", onClick = onDismiss) },
    )

    if (showScoreScanner) {
        ScoreScannerDialog(
            onUseReading = { score ->
                scoreText = formatScoreInputWithCommas(score.toString())
                validation = null
                showScoreScanner = false
            },
            onClose = { showScoreScanner = false },
        )
    }
}
