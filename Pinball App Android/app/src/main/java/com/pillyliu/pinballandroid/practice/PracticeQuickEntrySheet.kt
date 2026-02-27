package com.pillyliu.pinballandroid.practice

import androidx.core.content.edit
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import kotlin.math.roundToInt

private const val QUICK_GAME_KEY_PREFIX = "practice-quick-game-"
private const val QUICK_LIBRARY_KEY_PREFIX = "practice-quick-library-"
private const val ALL_GAMES_LIBRARY_OPTION = "__all_games__"

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
                .map { com.pillyliu.pinballandroid.library.LibrarySource(it.id, it.name, allLibraryGames.firstOrNull { g -> g.sourceId == it.id }?.sourceType ?: com.pillyliu.pinballandroid.library.LibrarySourceType.VENUE) }
        }
    }
    val showLibraryDropdown = !fromGameView && librarySources.size > 1
    fun avenueLibraryOptionId(): String? {
        return librarySources.firstOrNull { it.id == "venue--the-avenue-cafe" }?.id
            ?: librarySources.firstOrNull { it.id == "the-avenue" }?.id
            ?: librarySources.firstOrNull { it.name.contains("the avenue", ignoreCase = true) }?.id
    }
    fun canonicalExistingQuickGameKey(raw: String?): String {
        val canonical = canonicalPracticeKey(raw, allLibraryGames)
        return canonical.takeIf { it.isNotBlank() && findGameByPracticeLookupKey(allLibraryGames, it) != null }.orEmpty()
    }
    var selectedLibraryOption by remember(origin, fromGameView, librarySources, store.defaultPracticeSourceId) {
        val saved = prefs.getString("$QUICK_LIBRARY_KEY_PREFIX${origin.keySuffix}", null)
        val preferred = prefs.getString(KEY_PREFERRED_LIBRARY_SOURCE_ID, null)
        val avenue = avenueLibraryOptionId()
        val initial = when {
            origin == QuickEntryOrigin.Mechanics -> ALL_GAMES_LIBRARY_OPTION
            fromGameView -> store.defaultPracticeSourceId ?: ALL_GAMES_LIBRARY_OPTION
            avenue != null -> avenue
            saved == ALL_GAMES_LIBRARY_OPTION -> ALL_GAMES_LIBRARY_OPTION
            saved != null && librarySources.any { it.id == saved } -> saved
            preferred != null && librarySources.any { it.id == preferred } -> preferred
            else -> store.defaultPracticeSourceId ?: librarySources.firstOrNull()?.id ?: ALL_GAMES_LIBRARY_OPTION
        }
        mutableStateOf(initial)
    }
    var gameSlug by remember(origin, selectedGameSlug, fromGameView, store.games, store.allLibraryGames) {
        val saved = prefs.getString("$QUICK_GAME_KEY_PREFIX${origin.keySuffix}", null)
        val initial = when {
            origin == QuickEntryOrigin.Mechanics -> ""
            fromGameView -> canonicalExistingQuickGameKey(selectedGameSlug)
            else -> canonicalExistingQuickGameKey(saved)
                .ifBlank { canonicalExistingQuickGameKey(selectedGameSlug) }
                .ifBlank { orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true).firstOrNull()?.practiceKey.orEmpty() }
        }
        mutableStateOf(initial)
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
                    noteText = noteText,
                    onNoteTextChange = { noteText = it },
                    mechanicsSkill = mechanicsSkill,
                    onMechanicsSkillChange = { mechanicsSkill = it },
                    mechanicsSkills = mechanicsSkills,
                    mechanicsCompetency = mechanicsCompetency,
                    onMechanicsCompetencyChange = { mechanicsCompetency = it.roundToInt().toFloat() },
                )
                validation?.let {
                    Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = {
            val selectedSlugForEnable = gameSlug.takeUnless { it == "None" }.orEmpty()
            TextButton(onClick = {
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
                    noteText = noteText,
                    mechanicsSkill = mechanicsSkill,
                    mechanicsCompetency = mechanicsCompetency,
                )
                if (result.validationMessage != null) {
                    validation = result.validationMessage
                    return@TextButton
                }
                result.savedSlug?.let(onSave)
            }, enabled = mode == QuickActivity.Mechanics || selectedSlugForEnable.isNotBlank()) { Text("Save") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

private fun formatScoreInputWithCommas(raw: String): String {
    val digits = raw.filter { it.isDigit() }
    if (digits.isEmpty()) return ""
    return digits.reversed().chunked(3).joinToString(",").reversed()
}
