package com.pillyliu.pinballandroid.practice

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit

internal data class LoadedPracticeStatePayload(
    val payload: ParsedPracticeStatePayload,
    val usedLegacyKey: Boolean,
)

internal fun practiceSharedPreferences(context: Context): SharedPreferences {
    return context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE)
}

internal fun loadPracticeStatePayload(
    prefs: SharedPreferences,
    gameNameForKey: (String) -> String,
): LoadedPracticeStatePayload? {
    val current = prefs.getString(PRACTICE_STATE_KEY, null)
    val raw = when {
        !current.isNullOrBlank() -> current
        else -> prefs.getString(LEGACY_PRACTICE_STATE_KEY, null) ?: return null
    }
    val payload = parsePracticeStatePayloadJson(raw, gameNameForKey) ?: return null
    return LoadedPracticeStatePayload(
        payload = payload,
        usedLegacyKey = current.isNullOrBlank(),
    )
}

internal fun clearPracticeState(prefs: SharedPreferences, stateKey: String) {
    prefs.edit { remove(stateKey) }
}

internal fun savePracticeState(prefs: SharedPreferences, stateKey: String, serialized: String) {
    prefs.edit { putString(stateKey, serialized) }
}

internal fun loadPracticeState(prefs: SharedPreferences, stateKey: String): String? {
    return prefs.getString(stateKey, null)
}

internal fun markPracticeLastViewedGame(
    prefs: SharedPreferences,
    slug: String,
    nowMs: Long,
) {
    prefs.edit {
        putString(KEY_PRACTICE_LAST_VIEWED_SLUG, slug)
        putLong(KEY_PRACTICE_LAST_VIEWED_TS, nowMs)
    }
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

internal fun loadPreferredLeaguePlayerName(prefs: SharedPreferences): String? {
    val payload = loadPracticeStatePayload(prefs) { it }?.payload ?: return null
    val canonicalName = payload.canonical.leagueSettings.playerName.trim()
    if (canonicalName.isNotEmpty()) return canonicalName
    val runtimeName = payload.runtime.leaguePlayerName.trim()
    return runtimeName.ifEmpty { null }
}
