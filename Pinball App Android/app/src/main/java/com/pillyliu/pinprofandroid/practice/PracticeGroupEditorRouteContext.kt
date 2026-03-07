package com.pillyliu.pinprofandroid.practice

internal data class PracticeGroupEditorRouteContext(
    val store: PracticeStore,
    val editingGroupID: String?,
    val onBack: () -> Unit,
)
