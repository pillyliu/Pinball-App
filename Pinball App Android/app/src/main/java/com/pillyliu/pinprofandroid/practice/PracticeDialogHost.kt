package com.pillyliu.pinprofandroid.practice

import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch

@Composable
internal fun PracticeDialogHost(
    context: PracticePresentationContext,
) {
    val scope = rememberCoroutineScope()

    if (context.openNamePrompt) {
        PracticeNamePromptSheet(
            initialName = context.store.playerName,
            onSave = { name, shouldImportLpl ->
                context.store.updatePlayerName(name)
                context.onOpenNamePromptChange(false)
                if (!shouldImportLpl) return@PracticeNamePromptSheet
                scope.launch {
                    val normalizedInput = normalizeHumanName(name)
                    val matchedPlayer = context.store.availableLeaguePlayers().firstOrNull { candidate ->
                        normalizeHumanName(candidate) == normalizedInput
                    } ?: return@launch
                    context.store.updateLeaguePlayerName(matchedPlayer)
                    val importStatus = context.store.importLeagueScoresFromCsv()
                    context.onImportStatusChange(importStatus)
                }
            },
            onDismiss = { context.onOpenNamePromptChange(false) },
        )
    }

    if (context.openQuickEntry) {
        val useDedicatedGameScoreSheet = context.quickPresetActivity == QuickActivity.Score &&
            context.quickEntryOrigin == QuickEntryOrigin.Score &&
            context.quickEntryFromGameView &&
            !context.selectedGameSlug.isNullOrBlank()
        if (useDedicatedGameScoreSheet) {
            PracticeGameScoreEntrySheet(
                store = context.store,
                selectedGameSlug = context.selectedGameSlug!!,
                onDismiss = { context.onOpenQuickEntryChange(false) },
                onSave = { slug ->
                    context.onQuickSave(slug)
                    context.onOpenQuickEntryChange(false)
                },
            )
        } else {
            QuickEntrySheet(
                store = context.store,
                selectedGameSlug = context.selectedGameSlug,
                presetActivity = context.quickPresetActivity,
                origin = context.quickEntryOrigin,
                fromGameView = context.quickEntryFromGameView,
                onDismiss = { context.onOpenQuickEntryChange(false) },
                onSave = { slug ->
                    context.onQuickSave(slug)
                    context.onOpenQuickEntryChange(false)
                },
            )
        }
    }

    if (context.openGroupDateDialog) {
        GroupDashboardDateSheet(
            store = context.store,
            groupId = context.groupDateDialogGroupID,
            field = context.groupDateDialogField,
            initialSelectedDateMillis = context.groupDatePickerInitialMs,
            onDismiss = { context.onOpenGroupDateDialogChange(false) },
        )
    }

    if (context.openResetDialog) {
        ResetPracticeLogDialog(
            onConfirmReset = {
                context.store.resetAllState()
                context.onOpenResetDialogChange(false)
            },
            onDismiss = { context.onOpenResetDialogChange(false) },
        )
    }
}
