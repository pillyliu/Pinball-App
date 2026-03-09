package com.pillyliu.pinprofandroid.practice

import android.content.SharedPreferences

internal data class PracticeLifecycleContext(
    val store: PracticeStore,
    val uiState: PracticeScreenState,
    val prefs: SharedPreferences,
    val sourceVersion: Long,
    val onRefreshHeadToHead: suspend () -> Unit,
)
