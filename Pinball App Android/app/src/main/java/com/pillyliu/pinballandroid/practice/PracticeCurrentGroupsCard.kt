package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.CheckBox
import androidx.compose.material.icons.outlined.CheckBoxOutlineBlank
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.ui.CardContainer

@Composable
internal fun CurrentGroupsCard(
    store: PracticeStore,
    onCreateGroup: () -> Unit,
    onEditSelectedGroup: (String) -> Unit,
    onOpenGroupDatePicker: (groupId: String, field: GroupDashboardDateField, initialMs: Long) -> Unit,
) {
    CardContainer(modifier = Modifier.padding(top = 2.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Current Groups", fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            IconButton(onClick = onCreateGroup) {
                Icon(Icons.Outlined.Add, contentDescription = "Add group")
            }
            val selectedID = store.selectedGroup()?.id
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
        if (store.groups.isEmpty()) {
            Text("No groups yet.")
        } else {
            val selectedID = store.selectedGroup()?.id
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
            store.groups.forEach { group ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 0.dp),
                ) {
                    TextButton(
                        onClick = { store.setSelectedGroup(group.id) },
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(0.dp),
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    if (selectedID == group.id) MaterialTheme.colorScheme.surfaceVariant else Color.Transparent,
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
                        onClick = { store.updateGroup(group.copy(isPriority = !group.isPriority)) },
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
