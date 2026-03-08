package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
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
    val colors = PinballThemeTokens.colors
    val typography = PinballThemeTokens.typography
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.panel,
        title = { Text(title, color = colors.brandInk, style = typography.sectionTitle) },
        text = { Text(message, color = colors.brandChalk, style = typography.emptyState) },
        confirmButton = {
            AppTextAction(text = confirmLabel, onClick = onConfirm)
        },
        dismissButton = {
            AppTextAction(text = dismissLabel, onClick = onDismiss)
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
    val colors = PinballThemeTokens.colors
    val typography = PinballThemeTokens.typography
    val datePickerState = rememberDatePickerState(
        initialSelectedDateMillis = initialSelectedDateMillis,
    )
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            AppTextAction(
                text = confirmLabel,
                onClick = {
                    onSave(datePickerState.selectedDateMillis)
                    onDismiss()
                },
            )
        },
        dismissButton = {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (onClear != null) {
                    AppTextAction(
                        text = clearLabel,
                        onClick = {
                            onClear()
                            onDismiss()
                        },
                    )
                }
                AppTextAction(text = dismissLabel, onClick = onDismiss)
            }
        },
    ) {
        DatePicker(state = datePickerState)
    }
}
