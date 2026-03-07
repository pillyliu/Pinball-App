package com.pillyliu.pinprofandroid.practice

import androidx.compose.ui.Modifier

internal data class PracticeJournalRouteContext(
    val store: PracticeStore,
    val journalFilter: JournalFilter,
    val onJournalFilterChange: (JournalFilter) -> Unit,
    val journalSelectionMode: Boolean,
    val selectedJournalRowIds: Set<String>,
    val onJournalSelectionModeChange: (Boolean) -> Unit,
    val onSelectedJournalRowIdsChange: (Set<String>) -> Unit,
    val onOpenGame: (String) -> Unit,
    val timelineModifier: Modifier,
)
