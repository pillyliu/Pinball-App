package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.ui.CardContainer
import java.util.Locale

@Composable
internal fun SelectedGroupDashboardCard(
    store: PracticeStore,
    selected: PracticeGroup,
    onOpenGame: (String) -> Unit,
) {
    CardContainer {
        Text(selected.name, fontWeight = FontWeight.SemiBold)
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.horizontalScroll(rememberScrollState()),
        ) {
            DashboardStatusChip(
                text = if (selected.isActive) "Active" else "Inactive",
                color = if (selected.isActive) Color(0xFF2E7D32) else MaterialTheme.colorScheme.onSurfaceVariant,
            )
            DashboardStatusChip(
                text = selected.type.replaceFirstChar { it.titlecase(Locale.US) },
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (selected.isPriority) {
                DashboardStatusChip(text = "Priority", color = Color(0xFFE65100))
            }
            selected.startDateMs?.let {
                DashboardStatusChip(text = formatShortDate(it), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            selected.endDateMs?.let {
                DashboardStatusChip(text = formatShortDate(it), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        val dashboard = store.groupDashboardScore(selected)
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            DashboardMetricPill(
                label = "Completion",
                value = "${dashboard.completionAverage}%",
                modifier = Modifier.weight(1f),
            )
            DashboardMetricPill(
                label = "Stale",
                value = "${dashboard.staleGameCount}",
                modifier = Modifier.weight(1f),
            )
            DashboardMetricPill(
                label = "Variance Risk",
                value = "${dashboard.weakerGameCount}",
                modifier = Modifier.weight(1f),
            )
        }
        val games = store.groupGames(selected)
        if (games.isEmpty()) {
            Text("No games in this group yet.")
        } else {
            games.forEach { game ->
                val progress = store.taskProgressForGame(game.practiceKey, selected)
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        TextButton(
                            onClick = { onOpenGame(game.practiceKey) },
                            modifier = Modifier.weight(1f),
                            contentPadding = PaddingValues(horizontal = 0.dp, vertical = 2.dp),
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                GroupProgressWheel(taskProgress = progress, modifier = Modifier.width(46.dp).height(46.dp))
                                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text(game.name, maxLines = 1, overflow = TextOverflow.Ellipsis, fontWeight = FontWeight.SemiBold)
                                    Text(progressSummary(progress), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Icon(
                                    Icons.AutoMirrored.Filled.ArrowForward,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
