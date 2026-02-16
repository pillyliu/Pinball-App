package com.pillyliu.pinballandroid.practice

import androidx.compose.runtime.Composable

@Composable
internal fun PracticeDialogHost(
    store: PracticeStore,
    openNamePrompt: Boolean,
    onOpenNamePromptChange: (Boolean) -> Unit,
    openQuickEntry: Boolean,
    onOpenQuickEntryChange: (Boolean) -> Unit,
    selectedGameSlug: String?,
    quickPresetActivity: QuickActivity,
    quickEntryOrigin: QuickEntryOrigin,
    onQuickSave: (String) -> Unit,
    openGroupDateDialog: Boolean,
    onOpenGroupDateDialogChange: (Boolean) -> Unit,
    groupDateDialogGroupID: String?,
    groupDateDialogField: GroupDashboardDateField,
    groupDatePickerInitialMs: Long?,
    openResetDialog: Boolean,
    onOpenResetDialogChange: (Boolean) -> Unit,
) {
    if (openNamePrompt) {
        PracticeNamePromptSheet(
            initialName = store.playerName,
            onSave = { name ->
                store.updatePlayerName(name)
                onOpenNamePromptChange(false)
            },
            onDismiss = { onOpenNamePromptChange(false) },
        )
    }

    if (openQuickEntry) {
        QuickEntrySheet(
            store = store,
            selectedGameSlug = selectedGameSlug,
            presetActivity = quickPresetActivity,
            origin = quickEntryOrigin,
            onDismiss = { onOpenQuickEntryChange(false) },
            onSave = { slug ->
                onQuickSave(slug)
                onOpenQuickEntryChange(false)
            },
        )
    }

    if (openGroupDateDialog) {
        GroupDashboardDateSheet(
            store = store,
            groupId = groupDateDialogGroupID,
            field = groupDateDialogField,
            initialSelectedDateMillis = groupDatePickerInitialMs,
            onDismiss = { onOpenGroupDateDialogChange(false) },
        )
    }

    if (openResetDialog) {
        ResetPracticeLogDialog(
            onConfirmReset = {
                store.resetAllState()
                onOpenResetDialogChange(false)
            },
            onDismiss = { onOpenResetDialogChange(false) },
        )
    }
}
