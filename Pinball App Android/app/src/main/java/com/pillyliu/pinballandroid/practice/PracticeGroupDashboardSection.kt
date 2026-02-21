package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.changedToUpIgnoreConsumed
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.ui.CardContainer

@Composable
internal fun PracticeGroupDashboardSection(
    store: PracticeStore,
    onCreateGroup: () -> Unit,
    onEditSelectedGroup: (String) -> Unit,
    onOpenGroupDatePicker: (groupId: String, field: GroupDashboardDateField, initialMs: Long) -> Unit,
    onOpenGame: (String) -> Unit,
) {
    var revealedGroupID by rememberSaveable { mutableStateOf<String?>(null) }
    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier.pointerInput(revealedGroupID) {
            awaitPointerEventScope {
                while (true) {
                    val event = awaitPointerEvent(PointerEventPass.Initial)
                    if (revealedGroupID != null && event.changes.any { it.changedToUpIgnoreConsumed() }) {
                        revealedGroupID = null
                    }
                }
            }
        },
    ) {
        CurrentGroupsCard(
            store = store,
            revealedGroupID = revealedGroupID,
            onRevealedGroupIDChange = { revealedGroupID = it },
            onCreateGroup = onCreateGroup,
            onEditSelectedGroup = onEditSelectedGroup,
            onOpenGroupDatePicker = onOpenGroupDatePicker,
        )

        val selected = store.selectedGroup()
        if (selected == null) {
            CardContainer { Text("Create or select a group to populate dashboard.") }
        } else {
            SelectedGroupDashboardCard(
                store = store,
                selected = selected,
                onOpenGame = onOpenGame,
            )
        }
    }
}
