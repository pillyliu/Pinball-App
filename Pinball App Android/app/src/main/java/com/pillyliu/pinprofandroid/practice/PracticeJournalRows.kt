package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppSwipeActionRow
import com.pillyliu.pinprofandroid.ui.AppSwipeActionSpec

internal data class JournalTimelineRow(
    val id: String,
    val gameSlug: String,
    val summary: String,
    val timestampMs: Long,
    val journalEntry: JournalEntry?,
    val isEditable: Boolean,
)

@Composable
internal fun JournalRow(
    row: JournalTimelineRow,
    isSelectionMode: Boolean,
    isSelected: Boolean,
    onToggleSelected: () -> Unit,
    onOpenGame: (String) -> Unit,
    onEdit: (JournalEntry) -> Unit,
    onDelete: (JournalEntry) -> Unit,
) {
    if (row.journalEntry != null && row.isEditable && !isSelectionMode) {
        AppSwipeActionRow(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 6.dp, vertical = 4.dp)
                .defaultMinSize(minHeight = 40.dp),
            startAction = AppSwipeActionSpec(
                tint = Color(0xFF0A84FF),
                icon = Icons.Outlined.Edit,
                contentDescription = "Edit entry",
                onTrigger = { onEdit(row.journalEntry) },
            ),
            endAction = AppSwipeActionSpec(
                tint = Color(0xFFFF3B30),
                icon = Icons.Outlined.Delete,
                contentDescription = "Delete entry",
                onTrigger = { onDelete(row.journalEntry) },
            ),
        ) {
            Box(modifier = Modifier.fillMaxWidth()) {
                JournalRowContent(
                    row = row,
                    isSelectionMode = isSelectionMode,
                    isSelected = isSelected,
                    onToggleSelected = onToggleSelected,
                    onOpenGame = onOpenGame,
                )
            }
        }
    } else {
        if (row.isEditable) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 6.dp, vertical = 4.dp)
                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
                    .background(MaterialTheme.colorScheme.surfaceContainerLow)
                    .border(
                        width = 1.dp,
                        color = MaterialTheme.colorScheme.outline.copy(alpha = 0.72f),
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
                    )
            ) {
                JournalRowContent(
                    row = row,
                    isSelectionMode = isSelectionMode,
                    isSelected = isSelected,
                    onToggleSelected = onToggleSelected,
                    onOpenGame = onOpenGame,
                )
            }
        } else {
            JournalRowContent(
                row = row,
                isSelectionMode = isSelectionMode,
                isSelected = isSelected,
                onToggleSelected = onToggleSelected,
                onOpenGame = onOpenGame,
            )
        }
    }
}

@Composable
private fun JournalRowContent(
    row: JournalTimelineRow,
    isSelectionMode: Boolean,
    isSelected: Boolean,
    onToggleSelected: () -> Unit,
    onOpenGame: (String) -> Unit,
) {
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable {
                if (isSelectionMode) {
                    onToggleSelected()
                } else if (row.gameSlug.isNotBlank()) {
                    onOpenGame(row.gameSlug)
                }
            }
            .padding(horizontal = 8.dp, vertical = 4.dp),
    ) {
        if (isSelectionMode) {
            if (row.isEditable) {
                Icon(
                    if (isSelected) Icons.Outlined.CheckCircle else Icons.Outlined.Circle,
                    contentDescription = null,
                    tint = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else {
                androidx.compose.material3.Text(" ", modifier = Modifier.padding(horizontal = 12.dp))
            }
        }
        Column(
            verticalArrangement = Arrangement.spacedBy(2.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            StyledPracticeJournalSummaryText(
                summary = row.summary,
                style = MaterialTheme.typography.bodySmall,
            )
            androidx.compose.material3.Text(
                formatTimestamp(row.timestampMs),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
