package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.CardContainer

@Composable
internal fun PracticeGroupDashboardSection(
    store: PracticeStore,
    onCreateGroup: () -> Unit,
    onEditSelectedGroup: (String) -> Unit,
    onOpenGroupDatePicker: (groupId: String, field: GroupDashboardDateField, initialMs: Long) -> Unit,
    onOpenGame: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        CurrentGroupsCard(
            store = store,
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
