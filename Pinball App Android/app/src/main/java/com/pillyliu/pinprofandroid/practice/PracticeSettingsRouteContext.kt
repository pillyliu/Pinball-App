package com.pillyliu.pinprofandroid.practice

internal data class PracticeSettingsRouteContext(
    val store: PracticeStore,
    val importStatus: String,
    val onImportLplCsv: () -> Unit,
    val onOpenResetDialog: () -> Unit,
)
