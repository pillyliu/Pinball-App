package com.pillyliu.pinprofandroid.practice

import androidx.compose.runtime.Composable
import com.pillyliu.pinprofandroid.ui.AppConfirmDialog

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
        AppConfirmDialog(
            title = "Delete entry?",
            message = "This will remove the selected journal entry and linked practice data.",
            confirmLabel = "Delete",
            onConfirm = {
                store.deleteJournalEntry(entry.id)
                onPendingDeleteEntryChange(null)
                onEntryDeleted()
            },
            onDismiss = { onPendingDeleteEntryChange(null) },
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
