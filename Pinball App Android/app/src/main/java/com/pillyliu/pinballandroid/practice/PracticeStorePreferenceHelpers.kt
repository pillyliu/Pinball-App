package com.pillyliu.pinballandroid.practice

import android.content.SharedPreferences

internal fun clearPracticeState(prefs: SharedPreferences, stateKey: String) {
    prefs.edit().remove(stateKey).apply()
}

internal fun savePracticeState(prefs: SharedPreferences, stateKey: String, serialized: String) {
    prefs.edit().putString(stateKey, serialized).apply()
}

internal fun loadPracticeState(prefs: SharedPreferences, stateKey: String): String? {
    return prefs.getString(stateKey, null)
}

internal fun markPracticeLastViewedGame(
    prefs: SharedPreferences,
    slug: String,
    nowMs: Long,
) {
    prefs.edit()
        .putString(KEY_PRACTICE_LAST_VIEWED_SLUG, slug)
        .putLong(KEY_PRACTICE_LAST_VIEWED_TS, nowMs)
        .apply()
}

internal fun resumeSlugFromLibraryOrPractice(prefs: SharedPreferences): String? {
    val practiceSlug = prefs.getString(KEY_PRACTICE_LAST_VIEWED_SLUG, null)
    val practiceTs = prefs.getLong(KEY_PRACTICE_LAST_VIEWED_TS, 0L)
    val librarySlug = prefs.getString(KEY_LIBRARY_LAST_VIEWED_SLUG, null)
    val libraryTs = prefs.getLong(KEY_LIBRARY_LAST_VIEWED_TS, 0L)
    return if (libraryTs >= practiceTs) {
        librarySlug ?: practiceSlug
    } else {
        practiceSlug ?: librarySlug
    }
}
