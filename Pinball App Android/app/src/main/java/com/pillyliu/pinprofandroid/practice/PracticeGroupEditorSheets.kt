package com.pillyliu.pinprofandroid.practice

import androidx.compose.runtime.Composable
import com.pillyliu.pinprofandroid.ui.AppConfirmDialog
import com.pillyliu.pinprofandroid.ui.AppDatePickerSheet

@Composable
internal fun GroupEditorScheduleDateSheet(
    field: GroupEditorDateField,
    initialSelectedDateMillis: Long,
    onSave: (Long, GroupEditorDateField) -> Unit,
    onClear: (GroupEditorDateField) -> Unit,
    onDismiss: () -> Unit,
) {
    AppDatePickerSheet(
        initialSelectedDateMillis = localDisplayMillisToDatePickerUtcMillis(initialSelectedDateMillis),
        onSave = { selectedDate ->
            selectedDate?.let { onSave(datePickerUtcMillisToLocalDisplayMillis(it), field) }
        },
        onDismiss = onDismiss,
        onClear = { onClear(field) },
    )
}

@Composable
internal fun DeleteGroupConfirmSheet(
    onConfirmDelete: () -> Unit,
    onDismiss: () -> Unit,
) {
    AppConfirmDialog(
        title = "Delete this group?",
        message = "This removes the group and its title list.",
        confirmLabel = "Delete",
        onConfirm = onConfirmDelete,
        onDismiss = onDismiss,
    )
}

@Composable
internal fun DeleteTitleConfirmSheet(
    onConfirmDelete: () -> Unit,
    onDismiss: () -> Unit,
) {
    AppConfirmDialog(
        title = "Remove this title from the group?",
        message = "This only removes the title from this group.",
        confirmLabel = "Delete",
        onConfirm = onConfirmDelete,
        onDismiss = onDismiss,
    )
}
