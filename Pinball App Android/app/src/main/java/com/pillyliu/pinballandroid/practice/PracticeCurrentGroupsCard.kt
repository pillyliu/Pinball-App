package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Archive
import androidx.compose.material.icons.outlined.CheckBox
import androidx.compose.material.icons.outlined.CheckBoxOutlineBlank
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Unarchive
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.ui.CardContainer
import kotlin.math.roundToInt
import kotlin.math.abs

@Composable
internal fun CurrentGroupsCard(
    store: PracticeStore,
    revealedGroupID: String?,
    onRevealedGroupIDChange: (String?) -> Unit,
    onCreateGroup: () -> Unit,
    onEditSelectedGroup: (String) -> Unit,
    onOpenGroupDatePicker: (groupId: String, field: GroupDashboardDateField, initialMs: Long) -> Unit,
) {
    var showArchived by rememberSaveable { mutableStateOf(false) }
    val visibleGroups = store.groups.filter { group ->
        if (showArchived) group.isArchived else !group.isArchived
    }
    val selectedVisibleID = store.selectedGroupID?.takeIf { id -> visibleGroups.any { it.id == id } }

    CardContainer(modifier = Modifier.padding(top = 2.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Groups", fontWeight = FontWeight.SemiBold)
            Row(
                modifier = Modifier
                    .padding(start = 10.dp)
                    .background(
                        MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.88f),
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
                    )
                    .padding(2.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(
                    onClick = { showArchived = false },
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 1.dp),
                    modifier = Modifier
                        .background(
                            if (!showArchived) MaterialTheme.colorScheme.surface else Color.Transparent,
                            shape = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
                        ),
                ) { Text("Current", style = MaterialTheme.typography.labelSmall) }
                TextButton(
                    onClick = { showArchived = true },
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 1.dp),
                    modifier = Modifier
                        .background(
                            if (showArchived) MaterialTheme.colorScheme.surface else Color.Transparent,
                            shape = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
                        ),
                ) { Text("Archived", style = MaterialTheme.typography.labelSmall) }
            }
            Box(modifier = Modifier.weight(1f))
            IconButton(onClick = onCreateGroup) {
                Icon(Icons.Outlined.Add, contentDescription = "Add group")
            }
            val selectedID = selectedVisibleID
            IconButton(
                onClick = {
                    if (selectedID != null) {
                        onEditSelectedGroup(selectedID)
                    }
                },
                enabled = selectedID != null,
            ) {
                Icon(Icons.Outlined.Edit, contentDescription = "Edit selected group")
            }
        }
        if (visibleGroups.isEmpty()) {
            Text(if (showArchived) "No archived groups." else "No current groups.")
        } else {
            val selectedID = selectedVisibleID
            val priorityColWidth = 54.dp
            val dateColWidth = 78.dp
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp)
                    .padding(bottom = 0.dp),
            ) {
                Text("Name", modifier = Modifier.weight(1f), style = MaterialTheme.typography.labelSmall)
                Text(
                    "Priority",
                    style = MaterialTheme.typography.labelSmall,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.width(priorityColWidth),
                )
                Text(
                    "Start",
                    style = MaterialTheme.typography.labelSmall,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.width(dateColWidth),
                )
                Text(
                    "End",
                    style = MaterialTheme.typography.labelSmall,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.width(dateColWidth),
                )
            }
            visibleGroups.forEach { group ->
                val actionWidth = 132.dp
                val actionWidthPx = with(LocalDensity.current) { actionWidth.toPx() }
                var offsetX by rememberSaveable(group.id) { mutableFloatStateOf(0f) }
                val revealProgress = (abs(offsetX) / actionWidthPx).coerceIn(0f, 1f)
                val dragState = rememberDraggableState { delta ->
                    offsetX = (offsetX + delta).coerceIn(-actionWidthPx, 0f)
                }
                LaunchedEffect(revealedGroupID) {
                    if (revealedGroupID != group.id && offsetX != 0f) {
                        offsetX = 0f
                    }
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 6.dp, vertical = 4.dp)
                        .height(40.dp)
                        .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp)),
                ) {
                    Row(
                        modifier = Modifier
                            .align(Alignment.CenterEnd)
                            .width(actionWidth)
                            .fillMaxHeight()
                            .alpha(if (revealProgress > 0f) 1f else 0f),
                    ) {
                        SwipeActionIcon(
                            modifier = Modifier.weight(1f),
                            tint = Color(0xFFFF9500),
                            icon = if (group.isArchived) Icons.Outlined.Unarchive else Icons.Outlined.Archive,
                            contentDescription = if (group.isArchived) "Restore group" else "Archive group",
                            onClick = {
                                if (group.isArchived) {
                                    store.updateGroup(group.copy(isArchived = false))
                                } else {
                                    store.updateGroup(group.copy(isArchived = true, isActive = false, isPriority = false))
                                }
                                onRevealedGroupIDChange(null)
                                offsetX = 0f
                            },
                        )
                        SwipeActionIcon(
                            modifier = Modifier.weight(1f),
                            tint = Color(0xFFFF3B30),
                            icon = Icons.Outlined.Delete,
                            contentDescription = "Delete group",
                            onClick = {
                                store.deleteGroup(group.id)
                                onRevealedGroupIDChange(null)
                                offsetX = 0f
                            },
                        )
                    }

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .fillMaxHeight()
                            .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
                            .background(
                                MaterialTheme.colorScheme.surfaceContainerLow.copy(
                                    alpha = 1f - (1.00f * revealProgress),
                                ),
                            )
                            .border(
                                width = 1.dp,
                                color = MaterialTheme.colorScheme.outline.copy(alpha = 0.72f - (0.22f * revealProgress)),
                                shape = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
                            )
                            .offset { IntOffset(offsetX.roundToInt(), 0) }
                            .draggable(
                                state = dragState,
                                orientation = Orientation.Horizontal,
                                onDragStopped = {
                                    val reveal = offsetX <= (-actionWidthPx * 0.2f)
                                    offsetX = if (reveal) -actionWidthPx else 0f
                                    onRevealedGroupIDChange(if (reveal) group.id else null)
                                },
                            )
                    ) {
                        TextButton(
                            onClick = {
                                store.setSelectedGroup(group.id)
                                onRevealedGroupIDChange(null)
                                offsetX = 0f
                            },
                            modifier = Modifier.weight(1f),
                            contentPadding = PaddingValues(0.dp),
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 6.dp)
                                    .background(
                                        if (selectedID == group.id) MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.62f) else Color.Transparent,
                                        shape = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
                                    )
                                    .padding(horizontal = 8.dp, vertical = 4.dp),
                            ) {
                                Text(
                                    group.name,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    color = if (selectedID == group.id) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                        IconButton(
                            onClick = {
                                store.updateGroup(group.copy(isPriority = !group.isPriority))
                                onRevealedGroupIDChange(null)
                                offsetX = 0f
                            },
                            modifier = Modifier
                                .width(priorityColWidth)
                                .height(30.dp),
                        ) {
                            Icon(
                                imageVector = if (group.isPriority) Icons.Outlined.CheckBox else Icons.Outlined.CheckBoxOutlineBlank,
                                contentDescription = if (group.isPriority) "Priority on" else "Priority off",
                                tint = if (group.isPriority) Color(0xFFFFA726) else MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        TextButton(
                            onClick = {
                                onOpenGroupDatePicker(
                                    group.id,
                                    GroupDashboardDateField.Start,
                                    group.startDateMs ?: System.currentTimeMillis(),
                                )
                                onRevealedGroupIDChange(null)
                                offsetX = 0f
                            },
                            modifier = Modifier
                                .width(dateColWidth)
                                .height(30.dp),
                            contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp),
                        ) {
                            Text(
                                group.startDateMs?.let { formatShortDate(it) } ?: "-",
                                style = MaterialTheme.typography.labelSmall,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                        TextButton(
                            onClick = {
                                onOpenGroupDatePicker(
                                    group.id,
                                    GroupDashboardDateField.End,
                                    group.endDateMs ?: System.currentTimeMillis(),
                                )
                                onRevealedGroupIDChange(null)
                                offsetX = 0f
                            },
                            modifier = Modifier
                                .width(dateColWidth)
                                .height(30.dp),
                            contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp),
                        ) {
                            Text(
                                group.endDateMs?.let { formatShortDate(it) } ?: "-",
                                style = MaterialTheme.typography.labelSmall,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RowScope.SwipeActionIcon(
    modifier: Modifier,
    tint: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
) {
    IconButton(
        onClick = onClick,
        modifier = modifier
            .height(40.dp)
            .background(tint, shape = androidx.compose.foundation.shape.RoundedCornerShape(6.dp)),
    ) {
        Icon(icon, contentDescription = contentDescription, tint = Color.White)
    }
}
