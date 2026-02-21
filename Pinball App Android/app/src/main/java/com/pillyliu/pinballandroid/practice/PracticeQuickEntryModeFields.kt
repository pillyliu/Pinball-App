package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import kotlin.math.roundToInt

@Composable
internal fun QuickEntryModeFields(
    mode: QuickActivity,
    scoreText: String,
    onScoreTextChange: (String) -> Unit,
    scoreContext: String,
    onScoreContextChange: (String) -> Unit,
    tournamentName: String,
    onTournamentNameChange: (String) -> Unit,
    rulesheetProgress: Float,
    onRulesheetProgressChange: (Float) -> Unit,
    videoInputKind: String,
    onVideoInputKindChange: (String) -> Unit,
    videoSourceOptions: List<String>,
    selectedVideoSource: String,
    onSelectedVideoSourceChange: (String) -> Unit,
    videoWatchedTime: String,
    onVideoWatchedTimeChange: (String) -> Unit,
    videoTotalTime: String,
    onVideoTotalTimeChange: (String) -> Unit,
    videoPercent: Float,
    onVideoPercentChange: (Float) -> Unit,
    practiceMinutes: String,
    onPracticeMinutesChange: (String) -> Unit,
    noteText: String,
    onNoteTextChange: (String) -> Unit,
    mechanicsSkill: String,
    onMechanicsSkillChange: (String) -> Unit,
    mechanicsSkills: List<String>,
    mechanicsCompetency: Float,
    onMechanicsCompetencyChange: (Float) -> Unit,
) {
    when (mode) {
        QuickActivity.Score -> {
            OutlinedTextField(
                value = scoreText,
                onValueChange = onScoreTextChange,
                label = { Text("Score") },
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            )
            SimpleMenuDropdown(
                title = "Context",
                options = listOf("practice", "league", "tournament"),
                selected = scoreContext,
                onSelect = onScoreContextChange,
            )
            if (scoreContext == "tournament") {
                OutlinedTextField(
                    value = tournamentName,
                    onValueChange = onTournamentNameChange,
                    label = { Text("Tournament name") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }

        QuickActivity.Rulesheet -> {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Rulesheet progress")
                Spacer(Modifier.weight(1f))
                Text("${rulesheetProgress.roundToInt()}%")
            }
            Slider(
                value = rulesheetProgress,
                onValueChange = onRulesheetProgressChange,
                valueRange = 0f..100f,
            )
            OutlinedTextField(
                value = noteText,
                onValueChange = onNoteTextChange,
                label = { Text("Optional note") },
                modifier = Modifier.fillMaxWidth(),
            )
        }

        QuickActivity.Tutorial, QuickActivity.Gameplay -> {
            SimpleMenuDropdown(
                title = "Video",
                options = videoSourceOptions,
                selected = selectedVideoSource,
                onSelect = onSelectedVideoSourceChange,
            )
            SimpleMenuDropdown(
                title = "Input mode",
                options = listOf("clock", "percent"),
                selected = videoInputKind,
                onSelect = onVideoInputKindChange,
            )
            if (videoInputKind == "clock") {
                OutlinedTextField(
                    value = videoWatchedTime,
                    onValueChange = onVideoWatchedTimeChange,
                    label = { Text("Amount watched (hh:mm:ss)") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = videoTotalTime,
                    onValueChange = onVideoTotalTimeChange,
                    label = { Text("Total length (hh:mm:ss)") },
                    modifier = Modifier.fillMaxWidth(),
                )
            } else {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Percent watched")
                    Spacer(Modifier.weight(1f))
                    Text("${videoPercent.roundToInt()}%")
                }
                Slider(
                    value = videoPercent,
                    onValueChange = onVideoPercentChange,
                    valueRange = 0f..100f,
                )
            }
            OutlinedTextField(
                value = noteText,
                onValueChange = onNoteTextChange,
                label = { Text("Optional note") },
                modifier = Modifier.fillMaxWidth(),
            )
        }

        QuickActivity.Playfield -> {
            Text("Logs a timestamped playfield review.")
            OutlinedTextField(
                value = noteText,
                onValueChange = onNoteTextChange,
                label = { Text("Optional note") },
                modifier = Modifier.fillMaxWidth(),
            )
        }

        QuickActivity.Practice -> {
            OutlinedTextField(
                value = practiceMinutes,
                onValueChange = onPracticeMinutesChange,
                label = { Text("Practice minutes (optional)") },
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = noteText,
                onValueChange = onNoteTextChange,
                label = { Text("Optional note") },
                modifier = Modifier.fillMaxWidth(),
            )
        }

        QuickActivity.Mechanics -> {
            SimpleMenuDropdown(
                title = "Skill",
                options = mechanicsSkills,
                selected = mechanicsSkill,
                onSelect = onMechanicsSkillChange,
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Competency")
                Spacer(Modifier.weight(1f))
                Text("${mechanicsCompetency.roundToInt()}/5")
            }
            Slider(
                value = mechanicsCompetency,
                onValueChange = onMechanicsCompetencyChange,
                valueRange = 1f..5f,
                steps = 3,
            )
            OutlinedTextField(
                value = noteText,
                onValueChange = onNoteTextChange,
                label = { Text("Mechanics note") },
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
