package com.pillyliu.pinprofandroid.practice

internal const val PRACTICE_ALL_GAMES_SOURCE_ID = "__practice_all_games__"

internal fun normalizePracticeLibrarySourceId(sourceId: String?): String? {
    return if (sourceId == PRACTICE_ALL_GAMES_SOURCE_ID) null else sourceId
}
