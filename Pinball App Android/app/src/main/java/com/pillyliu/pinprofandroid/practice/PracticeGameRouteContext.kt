package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.RulesheetRemoteSource

internal data class PracticeGameRouteContext(
    val store: PracticeStore,
    val selectedGame: PinballGame?,
    val gameSubview: PracticeGameSubview,
    val onGameSubviewChange: (PracticeGameSubview) -> Unit,
    val gameSummaryDraft: String,
    val onGameSummaryDraftChange: (String) -> Unit,
    val activeGameVideoId: String?,
    val onActiveGameVideoIdChange: (String?) -> Unit,
    val onOpenQuickEntry: (QuickActivity, QuickEntryOrigin) -> Unit,
    val onOpenRulesheet: (RulesheetRemoteSource?) -> Unit,
    val onOpenExternalRulesheet: (String) -> Unit,
    val onOpenPlayfield: (List<String>) -> Unit,
)
