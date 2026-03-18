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
import com.pillyliu.pinprofandroid.library.isAvenueLibrarySourceId
import com.pillyliu.pinprofandroid.ui.AppTextAction
import com.pillyliu.pinprofandroid.ui.dismissKeyboardOnTapOutside
import kotlin.math.roundToInt

private const val QUICK_GAME_KEY_PREFIX = "practice-quick-game-"
private const val QUICK_LIBRARY_KEY_PREFIX = "practice-quick-library-"
private const val ALL_GAMES_LIBRARY_OPTION = "__all_games__"

internal fun resolveInitialQuickEntryLibraryOption(
    origin: QuickEntryOrigin,
    fromGameView: Boolean,
    selectedGameSourceId: String,
    resumeGameSourceId: String,
    savedLibraryOption: String,
    preferredLibraryOption: String,
    avenueLibraryOption: String,
    defaultPracticeSourceId: String,
    availableLibraryOptionIds: Set<String>,
): String {
    fun validSourceOrBlank(sourceId: String): String {
        return sourceId.takeIf { it.isNotBlank() && it in availableLibraryOptionIds }.orEmpty()
    }

    fun validLibraryOptionOrBlank(option: String): String {
        return when {
            option == ALL_GAMES_LIBRARY_OPTION -> ALL_GAMES_LIBRARY_OPTION
            option.isNotBlank() && option in availableLibraryOptionIds -> option
            else -> ""
        }
    }

    return when {
        origin == QuickEntryOrigin.Mechanics -> ALL_GAMES_LIBRARY_OPTION
        fromGameView -> validLibraryOptionOrBlank(defaultPracticeSourceId)
            .ifBlank { validSourceOrBlank(selectedGameSourceId) }
            .ifBlank { ALL_GAMES_LIBRARY_OPTION }
        else -> validSourceOrBlank(resumeGameSourceId)
            .ifBlank { validSourceOrBlank(selectedGameSourceId) }
            .ifBlank { validLibraryOptionOrBlank(savedLibraryOption) }
            .ifBlank { validLibraryOptionOrBlank(preferredLibraryOption) }
            .ifBlank { validLibraryOptionOrBlank(avenueLibraryOption) }
            .ifBlank { validLibraryOptionOrBlank(defaultPracticeSourceId) }
            .ifBlank { availableLibraryOptionIds.firstOrNull().orEmpty() }
            .ifBlank { ALL_GAMES_LIBRARY_OPTION }
    }
}

internal fun resolveInitialQuickEntryGameSlug(
    origin: QuickEntryOrigin,
    fromGameView: Boolean,
    selectedGameSlug: String,
    resumeGameSlug: String,
    savedQuickGameSlug: String,
    fallbackGameSlug: String,
): String {
    return when {
        origin == QuickEntryOrigin.Mechanics -> ""
        fromGameView -> selectedGameSlug
        resumeGameSlug.isNotBlank() -> resumeGameSlug
        selectedGameSlug.isNotBlank() -> selectedGameSlug
        savedQuickGameSlug.isNotBlank() -> savedQuickGameSlug
        else -> fallbackGameSlug
    }
}

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
        val preferred = prefs.getString(KEY_PREFERRED_LIBRARY_SOURCE_ID, null)
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
    var videoInputKind by remember { mutableStateOf("clock") }
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
            if (selectedLibraryOption != ALL_GAMES_LIBRARY_OPTION) {
                putString(KEY_PREFERRED_LIBRARY_SOURCE_ID, selectedLibraryOption)
            }
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
                if (!fromGameView) {
                    if (showLibraryDropdown) {
                        SimpleMenuDropdown(
                            title = "Library",
                            options = listOf(ALL_GAMES_LIBRARY_OPTION) + librarySources.map { it.id },
                            selected = selectedLibraryOption,
                            selectedLabel = when (selectedLibraryOption) {
                                ALL_GAMES_LIBRARY_OPTION -> "All games"
                                else -> librarySources.firstOrNull { it.id == selectedLibraryOption }?.name ?: selectedLibraryOption
                            },
                            onSelect = { selectedLibraryOption = it },
                            formatOptionLabel = { option ->
                                when (option) {
                                    ALL_GAMES_LIBRARY_OPTION -> "All games"
                                    else -> librarySources.firstOrNull { it.id == option }?.name ?: option
                                }
                            },
                        )
                    }
                    SimpleMenuDropdown(
                        title = "Game",
                        options = if (mode == QuickActivity.Mechanics) {
                            listOf("None") + gameOptions.map { it.practiceKey }
                        } else {
                            gameOptions.map { it.practiceKey }
                        },
                        selected = if (mode == QuickActivity.Mechanics && gameSlug.isBlank()) "None" else gameSlug,
                        selectedLabel = if (mode == QuickActivity.Mechanics && gameSlug.isBlank()) {
                            "None"
                        } else {
                            findGameByPracticeLookupKey(gameOptions, gameSlug)?.displayTitleForPractice ?: gameSlug
                        },
                        onSelect = { gameSlug = it },
                        formatOptionLabel = { option ->
                            if (option == "None") {
                                "None"
                            } else {
                                findGameByPracticeLookupKey(gameOptions, option)?.displayTitleForPractice ?: option
                            }
                        },
                    )
                }
                if (showActivityDropdown) {
                    SimpleMenuDropdown(
                        title = "Activity",
                        options = studyActivities.map { it.label },
                        selected = mode.label,
                        onSelect = { selected ->
                            mode = studyActivities.firstOrNull { it.label == selected } ?: QuickActivity.Rulesheet
                        },
                    )
                }

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
