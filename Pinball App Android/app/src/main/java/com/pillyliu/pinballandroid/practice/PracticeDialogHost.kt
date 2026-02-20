package com.pillyliu.pinballandroid.practice

import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch

@Composable
internal fun PracticeDialogHost(
    store: PracticeStore,
    openNamePrompt: Boolean,
    onOpenNamePromptChange: (Boolean) -> Unit,
    onImportStatusChange: (String) -> Unit,
    openQuickEntry: Boolean,
    onOpenQuickEntryChange: (Boolean) -> Unit,
    selectedGameSlug: String?,
    quickPresetActivity: QuickActivity,
    quickEntryOrigin: QuickEntryOrigin,
    quickEntryFromGameView: Boolean,
    onQuickSave: (String) -> Unit,
    openGroupDateDialog: Boolean,
    onOpenGroupDateDialogChange: (Boolean) -> Unit,
    groupDateDialogGroupID: String?,
    groupDateDialogField: GroupDashboardDateField,
    groupDatePickerInitialMs: Long?,
    openResetDialog: Boolean,
    onOpenResetDialogChange: (Boolean) -> Unit,
) {
    val scope = rememberCoroutineScope()

    if (openNamePrompt) {
        PracticeNamePromptSheet(
            initialName = store.playerName,
            onSave = { name, shouldImportLpl ->
                store.updatePlayerName(name)
                onOpenNamePromptChange(false)
                if (!shouldImportLpl) return@PracticeNamePromptSheet
                scope.launch {
                    val normalizedInput = normalizeHumanName(name)
                    val matchedPlayer = store.availableLeaguePlayers().firstOrNull { candidate ->
                        normalizeHumanName(candidate) == normalizedInput
                    } ?: return@launch
                    store.updateLeaguePlayerName(matchedPlayer)
                    val importStatus = store.importLeagueScoresFromCsv()
                    onImportStatusChange(importStatus)
                }
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
            fromGameView = quickEntryFromGameView,
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
