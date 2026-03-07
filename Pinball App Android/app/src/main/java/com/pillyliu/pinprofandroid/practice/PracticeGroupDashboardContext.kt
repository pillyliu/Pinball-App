package com.pillyliu.pinprofandroid.practice

internal data class PracticeGroupDashboardContext(
    val store: PracticeStore,
    val onCreateGroup: () -> Unit,
    val onEditSelectedGroup: (String) -> Unit,
    val onOpenGroupDatePicker: (String, GroupDashboardDateField, Long) -> Unit,
    val onOpenGame: (String) -> Unit,
)
