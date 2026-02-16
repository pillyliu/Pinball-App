package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.dp

@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun GroupEditorScheduleDateSheet(
    field: GroupEditorDateField,
    initialSelectedDateMillis: Long,
    onSave: (Long, GroupEditorDateField) -> Unit,
    onClear: (GroupEditorDateField) -> Unit,
    onDismiss: () -> Unit,
) {
    val datePickerState = rememberDatePickerState(
        initialSelectedDateMillis = initialSelectedDateMillis,
    )
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                datePickerState.selectedDateMillis?.let { selectedDate ->
                    onSave(selectedDate, field)
                }
                onDismiss()
            }) { Text("Save") }
        },
        dismissButton = {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = {
                    onClear(field)
                    onDismiss()
                }) { Text("Clear") }
                TextButton(onClick = onDismiss) { Text("Cancel") }
            }
        },
    ) {
        DatePicker(state = datePickerState)
    }
}

@Composable
internal fun DeleteGroupConfirmSheet(
    onConfirmDelete: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Delete this group?") },
        text = { Text("This removes the group and its title list.") },
        confirmButton = {
            TextButton(onClick = onConfirmDelete) { Text("Delete") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}

@Composable
internal fun DeleteTitleConfirmSheet(
    onConfirmDelete: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Remove this title from the group?") },
        text = { Text("This only removes the title from this group.") },
        confirmButton = {
            TextButton(onClick = onConfirmDelete) { Text("Delete") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}
