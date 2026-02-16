package com.pillyliu.pinballandroid.practice

import android.content.Context
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
internal fun QuickEntryDialog(
    store: PracticeStore,
    selectedGameSlug: String?,
    presetActivity: QuickActivity,
    origin: QuickEntryOrigin,
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
        QuickEntryOrigin.Score -> QuickActivity.Score
        QuickEntryOrigin.Study -> null
        QuickEntryOrigin.Practice -> QuickActivity.Practice
        QuickEntryOrigin.Mechanics -> QuickActivity.Mechanics
    }
    val showActivityDropdown = origin == QuickEntryOrigin.Study
    var gameSlug by remember(origin, selectedGameSlug) {
        val saved = prefs.getString("$QUICK_GAME_KEY_PREFIX${origin.keySuffix}", null)
        mutableStateOf(saved ?: selectedGameSlug ?: store.games.firstOrNull()?.slug.orEmpty())
    }
    var scoreText by remember { mutableStateOf("") }
    var scoreContext by remember { mutableStateOf("practice") }
    var tournamentName by remember { mutableStateOf("") }
    var rulesheetProgress by remember { mutableStateOf(0f) }
    var videoInputKind by remember { mutableStateOf("clock") }
    var videoValue by remember { mutableStateOf("") }
    var videoPercent by remember { mutableStateOf(0f) }
    var practiceMinutes by remember { mutableStateOf("") }
    var noteText by remember { mutableStateOf("") }
    var noteType by remember { mutableStateOf("general") }
    var mechanicsSkill by remember { mutableStateOf("Drop Catch") }
    var mechanicsCompetency by remember { mutableStateOf(3f) }
    var validation by remember { mutableStateOf<String?>(null) }
    val gameOptions = remember(store.games) { store.games.take(41) }
    val mechanicsSkills = store.allTrackedMechanicsSkills()
    LaunchedEffect(mechanicsSkills) {
        if (mechanicsSkills.isNotEmpty() && !mechanicsSkills.contains(mechanicsSkill)) {
            mechanicsSkill = mechanicsSkills.first()
        }
    }
    LaunchedEffect(origin, presetActivity) {
        if (showActivityDropdown) {
            if (mode !in studyActivities) {
                mode = QuickActivity.Rulesheet
            }
        } else if (fixedModeForOrigin != null) {
            mode = fixedModeForOrigin
        }
    }
    LaunchedEffect(mode, gameOptions) {
        if (mode == QuickActivity.Mechanics) return@LaunchedEffect
        if (gameSlug.isBlank() || gameSlug == "None") {
            gameSlug = gameOptions.firstOrNull()?.slug.orEmpty()
        }
    }
    LaunchedEffect(origin, gameSlug) {
        val selected = gameSlug.takeUnless { it == "None" }.orEmpty()
        if (selected.isNotBlank()) {
            prefs.edit().putString("$QUICK_GAME_KEY_PREFIX${origin.keySuffix}", selected).apply()
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Quick Entry") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
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
                    onScoreTextChange = { scoreText = it },
                    scoreContext = scoreContext,
                    onScoreContextChange = { scoreContext = it },
                    tournamentName = tournamentName,
                    onTournamentNameChange = { tournamentName = it },
                    rulesheetProgress = rulesheetProgress,
                    onRulesheetProgressChange = { rulesheetProgress = it },
                    videoInputKind = videoInputKind,
                    onVideoInputKindChange = { videoInputKind = it },
                    videoValue = videoValue,
                    onVideoValueChange = { videoValue = it },
                    videoPercent = videoPercent,
                    onVideoPercentChange = { videoPercent = it },
                    practiceMinutes = practiceMinutes,
                    onPracticeMinutesChange = { practiceMinutes = it },
                    noteText = noteText,
                    onNoteTextChange = { noteText = it },
                    noteType = noteType,
                    onNoteTypeChange = { noteType = it },
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
                    videoValue = videoValue,
                    videoPercent = videoPercent,
                    practiceMinutes = practiceMinutes,
                    noteText = noteText,
                    noteType = noteType,
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
