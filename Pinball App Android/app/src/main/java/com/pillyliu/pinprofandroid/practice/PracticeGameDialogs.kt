package com.pillyliu.pinprofandroid.practice

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable

@Composable
internal fun PracticeGameDialogs(
    store: PracticeStore,
    pendingDeleteEntry: JournalEntry?,
    onPendingDeleteEntryChange: (JournalEntry?) -> Unit,
    editingDraft: PracticeJournalEditDraft?,
    onEditingDraftChange: (PracticeJournalEditDraft?) -> Unit,
    editValidation: String?,
    onEditValidationChange: (String?) -> Unit,
    onEntryDeleted: () -> Unit,
    onEntryEdited: () -> Unit,
) {
    pendingDeleteEntry?.let { entry ->
        AlertDialog(
            onDismissRequest = { onPendingDeleteEntryChange(null) },
            title = { Text("Delete entry?") },
            text = { Text("This will remove the selected journal entry and linked practice data.") },
            confirmButton = {
                TextButton(onClick = {
                    store.deleteJournalEntry(entry.id)
                    onPendingDeleteEntryChange(null)
                    onEntryDeleted()
                }) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { onPendingDeleteEntryChange(null) }) { Text("Cancel") }
            },
        )
    }

    editingDraft?.let { draft ->
        JournalEditDialog(
            store = store,
            initial = draft,
            validationMessage = editValidation,
            onDismiss = {
                onEditingDraftChange(null)
                onEditValidationChange(null)
            },
            onSave = { updated ->
                if (store.updateJournalEntry(updated)) {
                    onEditingDraftChange(null)
                    onEditValidationChange(null)
                    onEntryEdited()
                } else {
                    onEditValidationChange("Could not save changes.")
                }
            },
        )
    }
}
