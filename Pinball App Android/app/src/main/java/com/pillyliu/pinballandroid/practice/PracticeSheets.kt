package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.unit.dp
import java.util.Locale

@Composable
internal fun PracticeNamePromptSheet(
    initialName: String,
    onSave: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var nameValue by remember(initialName) { mutableStateOf(initialName) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Welcome to Practice") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Enter your player name to get started.")
                OutlinedTextField(value = nameValue, onValueChange = { nameValue = it }, label = { Text("Player name") })
                Text("Home: resume, quick entry, active groups")
                Text("Group Dashboard: view and manage study groups")
                Text("Insights: score trends, consistency, and head-to-head")
                Text("Journal Timeline: practice activity history")
                Text("Game View: game resources and study log")
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(nameValue) }) { Text("Save") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Not now") }
        },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun GroupDashboardDateSheet(
    store: PracticeStore,
    groupId: String?,
    field: GroupDashboardDateField,
    initialSelectedDateMillis: Long?,
    onDismiss: () -> Unit,
) {
    val pickerState = rememberDatePickerState(initialSelectedDateMillis = initialSelectedDateMillis ?: System.currentTimeMillis())
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                val group = store.groups.firstOrNull { it.id == groupId }
                if (group != null) {
                    val selectedMillis = pickerState.selectedDateMillis
                    val updated = if (field == GroupDashboardDateField.Start) {
                        group.copy(startDateMs = selectedMillis)
                    } else {
                        group.copy(endDateMs = selectedMillis)
                    }
                    store.updateGroup(updated)
                }
                onDismiss()
            }) { Text("Save") }
        },
        dismissButton = {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(onClick = {
                    val group = store.groups.firstOrNull { it.id == groupId }
                    if (group != null) {
                        val updated = if (field == GroupDashboardDateField.Start) {
                            group.copy(startDateMs = null)
                        } else {
                            group.copy(endDateMs = null)
                        }
                        store.updateGroup(updated)
                    }
                    onDismiss()
                }) { Text("Clear") }
                TextButton(onClick = onDismiss) { Text("Cancel") }
            }
        },
    ) {
        DatePicker(state = pickerState)
    }
}

@Composable
internal fun ResetPracticeLogDialog(
    onConfirmReset: () -> Unit,
    onDismiss: () -> Unit,
) {
    var resetConfirmText by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Reset Practice Log?") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Type reset to confirm.")
                OutlinedTextField(value = resetConfirmText, onValueChange = { resetConfirmText = it }, label = { Text("Type reset") })
            }
        },
        confirmButton = {
            TextButton(
                onClick = onConfirmReset,
                enabled = resetConfirmText.trim().lowercase(Locale.US) == "reset",
            ) { Text("Yes, Reset") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("No") }
        },
    )
}
