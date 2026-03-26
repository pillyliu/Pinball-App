package com.pillyliu.pinprofandroid.practice

internal data class PracticeSettingsRouteContext(
    val store: PracticeStore,
    val importStatus: String,
    val importedLeagueScoreCount: Int,
    val onImportLplCsv: () -> Unit,
    val onOpenClearImportedLeagueScoresDialog: () -> Unit,
    val onOpenResetDialog: () -> Unit,
)
