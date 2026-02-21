package com.pillyliu.pinballandroid.practice

import android.content.Context
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
    val prefs = remember { context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE) }
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
    var gameSlug by remember(origin, selectedGameSlug, fromGameView) {
        val saved = prefs.getString("$QUICK_GAME_KEY_PREFIX${origin.keySuffix}", null)
        val initial = when {
            fromGameView -> selectedGameSlug.orEmpty()
            origin == QuickEntryOrigin.Mechanics -> ""
            else -> saved ?: selectedGameSlug ?: orderedGamesForDropdown(store.games).firstOrNull()?.slug.orEmpty()
        }
        mutableStateOf(initial)
    }
    var scoreText by remember { mutableStateOf("") }
    var scoreContext by remember { mutableStateOf("practice") }
    var tournamentName by remember { mutableStateOf("") }
    var rulesheetProgress by remember { mutableStateOf(0f) }
    var videoInputKind by remember { mutableStateOf("clock") }
    var selectedVideoSource by remember { mutableStateOf("") }
    var videoWatchedTime by remember { mutableStateOf("") }
    var videoTotalTime by remember { mutableStateOf("") }
    var videoPercent by remember { mutableStateOf(100f) }
    var practiceMinutes by remember { mutableStateOf("") }
    var noteText by remember { mutableStateOf("") }
    var mechanicsSkill by remember { mutableStateOf("Drop Catch") }
    var mechanicsCompetency by remember { mutableStateOf(3f) }
    var validation by remember { mutableStateOf<String?>(null) }
    val gameOptions = remember(store.games) { orderedGamesForDropdown(store.games, limit = 41) }
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
    LaunchedEffect(fromGameView, selectedGameSlug) {
        if (fromGameView) {
            gameSlug = selectedGameSlug.orEmpty()
        }
    }
    LaunchedEffect(mode, gameOptions) {
        if (mode == QuickActivity.Mechanics) return@LaunchedEffect
        if (gameSlug.isBlank() || gameSlug == "None") {
            gameSlug = gameOptions.firstOrNull()?.slug.orEmpty()
        }
    }
    val selectedGame = store.games.firstOrNull { it.slug == gameSlug }
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
                    SimpleMenuDropdown(
                        title = "Game",
                        options = if (mode == QuickActivity.Mechanics) {
                            listOf("None") + gameOptions.map { it.slug }
                        } else {
                            gameOptions.map { it.slug }
                        },
                        selected = if (mode == QuickActivity.Mechanics && gameSlug.isBlank()) "None" else gameSlug,
                        selectedLabel = if (mode == QuickActivity.Mechanics && gameSlug.isBlank()) {
                            "None"
                        } else {
                            gameOptions.firstOrNull { it.slug == gameSlug }?.name ?: gameSlug
                        },
                        onSelect = { gameSlug = it },
                        formatOptionLabel = { option ->
                            if (option == "None") {
                                "None"
                            } else {
                                gameOptions.firstOrNull { it.slug == option }?.name ?: option
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
