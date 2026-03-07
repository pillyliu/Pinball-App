package com.pillyliu.pinprofandroid.practice

internal data class PracticePresentationContext(
    val store: PracticeStore,
    val openNamePrompt: Boolean,
    val onOpenNamePromptChange: (Boolean) -> Unit,
    val onImportStatusChange: (String) -> Unit,
    val openQuickEntry: Boolean,
    val onOpenQuickEntryChange: (Boolean) -> Unit,
    val selectedGameSlug: String?,
    val quickPresetActivity: QuickActivity,
    val quickEntryOrigin: QuickEntryOrigin,
    val quickEntryFromGameView: Boolean,
    val onQuickSave: (String) -> Unit,
    val openGroupDateDialog: Boolean,
    val onOpenGroupDateDialogChange: (Boolean) -> Unit,
    val groupDateDialogGroupID: String?,
    val groupDateDialogField: GroupDashboardDateField,
    val groupDatePickerInitialMs: Long?,
    val openResetDialog: Boolean,
    val onOpenResetDialogChange: (Boolean) -> Unit,
)
