package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.LibrarySource

internal data class PracticeHomeRouteContext(
    val store: PracticeStore,
    val resumeOtherExpanded: Boolean,
    val onResumeOtherExpandedChange: (Boolean) -> Unit,
    val librarySources: List<LibrarySource>,
    val selectedLibrarySourceId: String?,
    val onSelectLibrarySourceId: (String) -> Unit,
    val onOpenGame: (String) -> Unit,
    val onOpenQuickEntry: (QuickActivity, QuickEntryOrigin) -> Unit,
    val onOpenGroupDashboard: () -> Unit,
    val onOpenJournal: () -> Unit,
    val onOpenInsights: () -> Unit,
    val onOpenMechanics: () -> Unit,
)
