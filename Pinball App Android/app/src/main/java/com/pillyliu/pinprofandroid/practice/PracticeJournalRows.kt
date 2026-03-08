package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.offset
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppSwipeRevealActionButton

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
    revealedRowId: String?,
    onRevealedRowIdChange: (String?) -> Unit,
    isSelectionMode: Boolean,
    isSelected: Boolean,
    onToggleSelected: () -> Unit,
    onOpenGame: (String) -> Unit,
    onEdit: (JournalEntry) -> Unit,
    onDelete: (JournalEntry) -> Unit,
) {
    if (row.journalEntry != null && row.isEditable && !isSelectionMode) {
        val actionWidth = 132.dp
        val actionWidthPx = with(LocalDensity.current) { actionWidth.toPx() }
        var rowHeightPx by rememberSaveable(row.id) { mutableIntStateOf(0) }
        val rowHeightDp = with(LocalDensity.current) {
            if (rowHeightPx > 0) rowHeightPx.toDp() else 40.dp
        }
        var offsetX by rememberSaveable(row.id) { mutableFloatStateOf(0f) }
        val revealProgress = (kotlin.math.abs(offsetX) / actionWidthPx).coerceIn(0f, 1f)
        val dragState = rememberDraggableState { delta ->
            offsetX = (offsetX + delta).coerceIn(-actionWidthPx, 0f)
        }
        LaunchedEffect(revealedRowId) {
            if (revealedRowId != row.id && offsetX != 0f) {
                offsetX = 0f
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 6.dp, vertical = 4.dp)
                .defaultMinSize(minHeight = 40.dp)
                .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
        ) {
            Row(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .width(actionWidth)
                    .height(rowHeightDp)
                    .alpha(if (revealProgress > 0f) 1f else 0f)
            ) {
                AppSwipeRevealActionButton(
                    modifier = Modifier.weight(1f),
                    tint = Color(0xFF0A84FF),
                    icon = Icons.Outlined.Edit,
                    contentDescription = "Edit entry",
                    onClick = { row.journalEntry?.let(onEdit) }
                )
                AppSwipeRevealActionButton(
                    modifier = Modifier.weight(1f),
                    tint = Color(0xFFFF3B30),
                    icon = Icons.Outlined.Delete,
                    contentDescription = "Delete entry",
                    onClick = { row.journalEntry?.let(onDelete) }
                )
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight()
                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
                    .background(
                        MaterialTheme.colorScheme.surfaceContainerLow.copy(alpha = 1f - revealProgress)
                    )
                    .border(
                        width = 1.dp,
                        color = MaterialTheme.colorScheme.outline.copy(alpha = 0.72f - (0.22f * revealProgress)),
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
                    )
                    .offset { IntOffset(offsetX.toInt(), 0) }
                    .onSizeChanged { rowHeightPx = it.height }
                    .draggable(
                        state = dragState,
                        orientation = Orientation.Horizontal,
                        onDragStopped = {
                            val reveal = offsetX <= (-actionWidthPx * 0.2f)
                            offsetX = if (reveal) -actionWidthPx else 0f
                            onRevealedRowIdChange(if (reveal) row.id else null)
                        }
                    )
            ) {
                JournalRowContent(
                    row = row,
                    revealedRowId = revealedRowId,
                    onRevealedRowIdChange = onRevealedRowIdChange,
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
                    revealedRowId = revealedRowId,
                    onRevealedRowIdChange = onRevealedRowIdChange,
                    isSelectionMode = isSelectionMode,
                    isSelected = isSelected,
                    onToggleSelected = onToggleSelected,
                    onOpenGame = onOpenGame,
                )
            }
        } else {
            JournalRowContent(
                row = row,
                revealedRowId = revealedRowId,
                onRevealedRowIdChange = onRevealedRowIdChange,
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
    revealedRowId: String?,
    onRevealedRowIdChange: (String?) -> Unit,
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
                if (revealedRowId != null) {
                    onRevealedRowIdChange(null)
                    return@clickable
                }
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
