package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.practice.StyledPracticeJournalSummaryText
import com.pillyliu.pinprofandroid.practice.formatTimestamp
import com.pillyliu.pinprofandroid.ui.AppSwipeActionRow
import com.pillyliu.pinprofandroid.ui.AppSwipeActionSpec

@Composable
internal fun GameRoomLogRow(
    event: MachineEvent,
    mediaCount: Int,
    selected: Boolean,
    onSelect: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    AppSwipeActionRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 6.dp, vertical = 4.dp)
            .defaultMinSize(minHeight = 40.dp)
            .clip(RoundedCornerShape(8.dp)),
        shape = RoundedCornerShape(8.dp),
        startAction = AppSwipeActionSpec(
            tint = Color(0xFF0A84FF),
            icon = Icons.Outlined.Edit,
            contentDescription = "Edit entry",
            onTrigger = onEdit,
        ),
        endAction = AppSwipeActionSpec(
            tint = Color(0xFFFF3B30),
            icon = Icons.Outlined.Delete,
            contentDescription = "Delete entry",
            onTrigger = onDelete,
        ),
    ) {
        Row(
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    if (selected) {
                        MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.35f)
                    } else {
                        Color.Transparent
                    },
                    RoundedCornerShape(8.dp),
                )
                .clickable(onClick = onSelect)
                .padding(horizontal = 8.dp, vertical = 4.dp),
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                StyledPracticeJournalSummaryText(
                    summary = event.summary,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    text = "${displayMachineEventCategory(event.category)} • ${formatTimestamp(event.occurredAtMs)} • $mediaCount media",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}
