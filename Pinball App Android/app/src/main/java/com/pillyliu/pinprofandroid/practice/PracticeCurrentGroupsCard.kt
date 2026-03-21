package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Archive
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.RadioButtonChecked
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material.icons.outlined.Unarchive
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalMinimumInteractiveComponentSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppCompactIconButton
import com.pillyliu.pinprofandroid.ui.AppConfirmDialog
import com.pillyliu.pinprofandroid.ui.AppSelectableRowButton
import com.pillyliu.pinprofandroid.ui.AppSwipeActionRow
import com.pillyliu.pinprofandroid.ui.AppSwipeActionSpec
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors

private val DashboardRowShape = androidx.compose.foundation.shape.RoundedCornerShape(10.dp)

private data class PendingGroupSwipeAction(
    val groupId: String,
    val type: PendingGroupSwipeActionType,
)

private enum class PendingGroupSwipeActionType {
    archive,
    restore,
    delete,
}

@Composable
internal fun CurrentGroupsCard(
    store: PracticeStore,
    onCreateGroup: () -> Unit,
    onEditSelectedGroup: (String) -> Unit,
    onOpenGroupDatePicker: (groupId: String, field: GroupDashboardDateField, initialMs: Long) -> Unit,
) {
    var showArchived by rememberSaveable { mutableStateOf(false) }
    var pendingSwipeAction by remember { mutableStateOf<PendingGroupSwipeAction?>(null) }
    val visibleGroups = store.groups.filter { group ->
        if (showArchived) group.isArchived else !group.isArchived
    }
    val selectedVisibleID = store.selectedGroupID?.takeIf { id -> visibleGroups.any { it.id == id } }

    CardContainer(modifier = Modifier.padding(top = 2.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionTitle("Groups")
            CompositionLocalProvider(LocalMinimumInteractiveComponentSize provides 0.dp) {
                SingleChoiceSegmentedButtonRow(
                    modifier = Modifier.padding(start = 10.dp),
                ) {
                    listOf("Current", "Archived").forEachIndexed { index, label ->
                        val archived = index == 1
                        SegmentedButton(
                            selected = showArchived == archived,
                            onClick = { showArchived = archived },
                            colors = pinballSegmentedButtonColors(),
                            shape = SegmentedButtonDefaults.itemShape(index = index, count = 2),
                            modifier = Modifier.height(32.dp),
                            icon = {},
                            label = {
                                Text(
                                    text = label,
                                    style = MaterialTheme.typography.bodySmall,
                                    maxLines = 1,
                                )
                            },
                        )
                    }
                }
            }
            Box(modifier = Modifier.weight(1f))
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                AppCompactIconButton(
                    icon = Icons.Outlined.Add,
                    contentDescription = "Add group",
                    onClick = onCreateGroup,
                    size = 28.dp,
                    iconSize = 16.dp,
                )
                val selectedID = selectedVisibleID
                AppCompactIconButton(
                    icon = Icons.Outlined.Edit,
                    contentDescription = "Edit selected group",
                    onClick = {
                        if (selectedID != null) {
                            onEditSelectedGroup(selectedID)
                        }
                    },
                    enabled = selectedID != null,
                    size = 28.dp,
                    iconSize = 16.dp,
                )
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
                AppSwipeActionRow(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 6.dp, vertical = 1.dp)
                        .height(38.dp)
                        .clip(DashboardRowShape),
                    startAction = AppSwipeActionSpec(
                        tint = Color(0xFFFF9500),
                        icon = if (group.isArchived) Icons.Outlined.Unarchive else Icons.Outlined.Archive,
                        contentDescription = if (group.isArchived) "Restore group" else "Archive group",
                        onTrigger = {
                            pendingSwipeAction = PendingGroupSwipeAction(
                                groupId = group.id,
                                type = if (group.isArchived) {
                                    PendingGroupSwipeActionType.restore
                                } else {
                                    PendingGroupSwipeActionType.archive
                                },
                            )
                        },
                    ),
                    endAction = AppSwipeActionSpec(
                        tint = Color(0xFFFF3B30),
                        icon = Icons.Outlined.Delete,
                        contentDescription = "Delete group",
                        onTrigger = {
                            pendingSwipeAction = PendingGroupSwipeAction(
                                groupId = group.id,
                                type = PendingGroupSwipeActionType.delete,
                            )
                        },
                    ),
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(38.dp)
                    ) {
                        AppSelectableRowButton(
                            text = group.name,
                            selected = selectedID == group.id,
                            onClick = { store.setSelectedGroup(group.id) },
                            highlightCorner = 8.dp,
                            modifier = Modifier
                                .weight(1f)
                                .padding(horizontal = 6.dp, vertical = 3.dp),
                        )
                        Box(
                            modifier = Modifier.width(priorityColWidth),
                            contentAlignment = Alignment.Center,
                        ) {
                            IconButton(
                                onClick = { store.updateGroup(group.copy(isPriority = !group.isPriority)) },
                            ) {
                                Icon(
                                    imageVector = if (group.isPriority) Icons.Outlined.RadioButtonChecked else Icons.Outlined.RadioButtonUnchecked,
                                    contentDescription = if (group.isPriority) "Priority on" else "Priority off",
                                    tint = if (group.isPriority) Color(0xFFFFA726) else MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                        DashboardDateButton(
                            text = group.startDateMs?.let { formatShortDate(it) } ?: "-",
                            width = dateColWidth,
                            onClick = {
                                onOpenGroupDatePicker(
                                    group.id,
                                    GroupDashboardDateField.Start,
                                    group.startDateMs ?: System.currentTimeMillis(),
                                )
                            },
                        )
                        DashboardDateButton(
                            text = group.endDateMs?.let { formatShortDate(it) } ?: "-",
                            width = dateColWidth,
                            onClick = {
                                onOpenGroupDatePicker(
                                    group.id,
                                    GroupDashboardDateField.End,
                                    group.endDateMs ?: System.currentTimeMillis(),
                                )
                            },
                        )
                    }
                }
            }
        }
    }

    pendingSwipeAction?.let { action ->
        val targetGroup = store.groups.firstOrNull { it.id == action.groupId }
        val isArchive = action.type == PendingGroupSwipeActionType.archive
        val isRestore = action.type == PendingGroupSwipeActionType.restore
        val groupName = targetGroup?.name ?: "this group"
        AppConfirmDialog(
            title = when {
                isArchive -> "Archive group?"
                isRestore -> "Restore group?"
                else -> "Delete group?"
            },
            message = when {
                isArchive -> {
                "This will move $groupName out of current groups."
                }
                isRestore -> {
                    "This will move $groupName back into current groups."
                }
                else -> {
                "This will permanently remove $groupName."
                }
            },
            confirmLabel = when {
                isArchive -> "Archive"
                isRestore -> "Restore"
                else -> "Delete"
            },
            onConfirm = {
                if (targetGroup != null) {
                    if (isArchive) {
                        store.updateGroup(
                            targetGroup.copy(isArchived = true, isActive = false, isPriority = false),
                        )
                    } else if (isRestore) {
                        store.updateGroup(targetGroup.copy(isArchived = false))
                    } else {
                        store.deleteGroup(targetGroup.id)
                    }
                }
                pendingSwipeAction = null
            },
            onDismiss = { pendingSwipeAction = null },
        )
    }
}

@Composable
private fun DashboardDateButton(
    text: String,
    width: androidx.compose.ui.unit.Dp,
    onClick: () -> Unit,
) {
    Text(
        text = text,
        modifier = Modifier
            .width(width)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(vertical = 6.dp),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        textAlign = TextAlign.Center,
    )
}
