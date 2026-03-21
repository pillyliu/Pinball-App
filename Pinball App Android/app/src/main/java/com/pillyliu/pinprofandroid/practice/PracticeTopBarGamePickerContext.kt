package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.PinballGame

internal data class PracticeTopBarGamePickerContext(
    val selectedGameName: String?,
    val games: List<PinballGame>,
    val librarySources: List<LibrarySource>,
    val selectedLibrarySourceId: String?,
    val expanded: Boolean,
    val onExpandedChange: (Boolean) -> Unit,
    val onLibrarySourceSelected: (String) -> Unit,
    val onGameSelected: (String) -> Unit,
)
