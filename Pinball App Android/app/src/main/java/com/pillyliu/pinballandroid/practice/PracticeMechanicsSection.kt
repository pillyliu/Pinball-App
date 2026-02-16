package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.ui.CardContainer
import java.util.Locale
import kotlin.math.roundToInt

@Composable
internal fun PracticeMechanicsSection(
    store: PracticeStore,
    selectedGameSlug: String?,
    mechanicsSelectedSkill: String,
    onMechanicsSelectedSkillChange: (String) -> Unit,
    mechanicsCompetency: Float,
    onMechanicsCompetencyChange: (Float) -> Unit,
    mechanicsNote: String,
    onMechanicsNoteChange: (String) -> Unit,
    onOpenDeadFlipTutorials: () -> Unit,
) {
    val allSkills = store.allTrackedMechanicsSkills()
    if (mechanicsSelectedSkill.isBlank() && allSkills.isNotEmpty()) {
        onMechanicsSelectedSkillChange(allSkills.first())
    } else if (allSkills.isNotEmpty() && !allSkills.contains(mechanicsSelectedSkill)) {
        onMechanicsSelectedSkillChange(allSkills.first())
    }

    CardContainer {
        Text("Mechanics", fontWeight = FontWeight.SemiBold)
        Text("Skills are tracked as tags in your notes.")

        SimpleMenuDropdown(
            title = "Skill",
            options = allSkills,
            selected = mechanicsSelectedSkill,
            onSelect = onMechanicsSelectedSkillChange,
        )

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Competency")
            Spacer(Modifier.weight(1f))
            Text("${mechanicsCompetency.roundToInt()}/5")
        }
        androidx.compose.material3.Slider(
            value = mechanicsCompetency,
            onValueChange = { onMechanicsCompetencyChange(it.roundToInt().toFloat()) },
            valueRange = 1f..5f,
            steps = 3,
        )

        OutlinedTextField(
            value = mechanicsNote,
            onValueChange = onMechanicsNoteChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Mechanics note") },
        )
        val detected = store.detectedMechanicsTags(mechanicsNote)
        if (detected.isNotEmpty()) {
            Text("Detected tags: ${detected.joinToString(", ")}", style = MaterialTheme.typography.bodySmall)
        }

        Button(onClick = {
            val gameSlug = selectedGameSlug ?: store.games.firstOrNull()?.slug ?: return@Button
            val prefix = if (mechanicsSelectedSkill.isBlank()) "#mechanics" else "#${mechanicsSelectedSkill.replace(" ", "")}"
            val composed = "$prefix competency ${mechanicsCompetency.roundToInt()}/5. ${mechanicsNote.trim()}".trim()
            store.addPracticeNote(gameSlug, "general", mechanicsSelectedSkill, composed)
            onMechanicsNoteChange("")
        }) { Text("Log Mechanics Session") }
    }

    if (mechanicsSelectedSkill.isNotBlank()) {
        CardContainer {
            Text("$mechanicsSelectedSkill History", fontWeight = FontWeight.SemiBold)
            val summary = store.mechanicsSummary(mechanicsSelectedSkill)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                Text("Logs: ${summary.totalLogs}", style = MaterialTheme.typography.bodySmall)
                Text("Latest: ${summary.latestComfort?.let { "$it/5" } ?: "-"}", style = MaterialTheme.typography.bodySmall)
                Text(
                    "Avg: ${summary.averageComfort?.let { String.format(Locale.US, "%.1f/5", it) } ?: "-"}",
                    style = MaterialTheme.typography.bodySmall,
                )
                Text(
                    "Trend: ${summary.trendDelta?.let { signedCompact(it) } ?: "-"}",
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            val logs = store.mechanicsLogs(mechanicsSelectedSkill)
            MechanicsTrendSparkline(logs = logs)
            val rows = logs.takeLast(24).reversed()
            if (rows.isEmpty()) {
                Text("No sessions logged for this skill yet.")
            } else {
                LazyColumn(modifier = Modifier.height(260.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(rows) { row ->
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(row.note, style = MaterialTheme.typography.bodySmall)
                            Text(
                                "${formatTimestamp(row.timestampMs)} • ${store.gameName(row.gameSlug)}",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }
    }

    OutlinedButton(onClick = onOpenDeadFlipTutorials) {
        Text("Dead Flip Tutorials")
    }
}
