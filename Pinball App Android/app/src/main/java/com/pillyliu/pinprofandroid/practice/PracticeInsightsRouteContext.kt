package com.pillyliu.pinprofandroid.practice

internal data class PracticeInsightsRouteContext(
    val store: PracticeStore,
    val selectedGameSlug: String?,
    val onSelectGameSlug: (String) -> Unit,
    val insightsOpponentName: String,
    val insightsOpponentOptions: List<String>,
    val onInsightsOpponentNameChange: (String) -> Unit,
    val headToHead: HeadToHeadComparison?,
    val isLoadingHeadToHead: Boolean,
    val onRefreshHeadToHead: () -> Unit,
)
