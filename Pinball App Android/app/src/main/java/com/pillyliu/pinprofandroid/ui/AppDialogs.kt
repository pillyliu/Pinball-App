package com.pillyliu.pinprofandroid.ui

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
fun AppConfirmDialog(
    title: String,
    message: String,
    confirmLabel: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    dismissLabel: String = "Cancel",
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(message) },
        confirmButton = {
            TextButton(onClick = onConfirm) { Text(confirmLabel) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(dismissLabel) }
        },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppDatePickerSheet(
    initialSelectedDateMillis: Long,
    onSave: (Long?) -> Unit,
    onDismiss: () -> Unit,
    onClear: (() -> Unit)? = null,
    confirmLabel: String = "Save",
    clearLabel: String = "Clear",
    dismissLabel: String = "Cancel",
) {
    val datePickerState = rememberDatePickerState(
        initialSelectedDateMillis = initialSelectedDateMillis,
    )
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                onSave(datePickerState.selectedDateMillis)
                onDismiss()
            }) { Text(confirmLabel) }
        },
        dismissButton = {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (onClear != null) {
                    TextButton(onClick = {
                        onClear()
                        onDismiss()
                    }) { Text(clearLabel) }
                }
                TextButton(onClick = onDismiss) { Text(dismissLabel) }
            }
        },
    ) {
        DatePicker(state = datePickerState)
    }
}
