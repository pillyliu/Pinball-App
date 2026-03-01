package com.pillyliu.pinballandroid.data

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.edit
import com.pillyliu.pinballandroid.practice.PRACTICE_PREFS

private const val LPL_FULL_NAME_ACCESS_UNLOCKED_KEY = "lpl-name-privacy.full-access-unlocked"
private const val LPL_SHOW_FULL_LAST_NAME_KEY = "lpl-name-privacy.show-full-last-name"
private const val LPL_FULL_NAME_PASSWORD = "Stephen"

private fun lplNamePrivacyPreferences(context: Context): SharedPreferences {
    return context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE)
}

fun formatLplPlayerNameForDisplay(raw: String, showFullLastName: Boolean): String {
    val trimmed = raw.trim()
    if (shouldRedactPlayerName(trimmed)) {
        return "Redacted ${redactionToken(trimmed)}"
    }
    if (trimmed.isEmpty()) return trimmed

    val suffixMatch = Regex("\\s\\([^)]*\\)$").find(trimmed)
    val namePortion = suffixMatch?.let { trimmed.removeRange(it.range) } ?: trimmed
    val suffix = suffixMatch?.value.orEmpty()

    if (showFullLastName) return namePortion + suffix

    val parts = namePortion.split(Regex("\\s+")).filter { it.isNotBlank() }
    if (parts.isEmpty()) return ""
    if (parts.size == 1) return parts.first() + suffix

    val first = parts.first()
    val initial = parts.last().firstOrNull() ?: return first
    return "$first $initial$suffix"
}

fun isLplFullNameAccessUnlocked(context: Context): Boolean {
    return lplNamePrivacyPreferences(context).getBoolean(LPL_FULL_NAME_ACCESS_UNLOCKED_KEY, false)
}

fun unlockLplFullNameAccess(context: Context, password: String): Boolean {
    if (password != LPL_FULL_NAME_PASSWORD) return false
    lplNamePrivacyPreferences(context).edit {
        putBoolean(LPL_FULL_NAME_ACCESS_UNLOCKED_KEY, true)
    }
    return true
}

fun setShowFullLplLastName(context: Context, showFullLastName: Boolean) {
    lplNamePrivacyPreferences(context).edit {
        putBoolean(LPL_SHOW_FULL_LAST_NAME_KEY, showFullLastName)
    }
}

fun shouldShowFullLplLastName(context: Context): Boolean {
    return lplNamePrivacyPreferences(context).getBoolean(LPL_SHOW_FULL_LAST_NAME_KEY, false)
}

@Composable
fun rememberShowFullLplLastName(): Boolean {
    val context = LocalContext.current
    val prefs = remember(context) { lplNamePrivacyPreferences(context) }
    var showFullLastName by remember(context) { mutableStateOf(shouldShowFullLplLastName(context)) }

    DisposableEffect(prefs) {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == LPL_SHOW_FULL_LAST_NAME_KEY) {
                showFullLastName = prefs.getBoolean(LPL_SHOW_FULL_LAST_NAME_KEY, false)
            }
        }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        onDispose {
            prefs.unregisterOnSharedPreferenceChangeListener(listener)
        }
    }

    return showFullLastName
}

@Composable
fun rememberLplFullNameAccessUnlocked(): Boolean {
    val context = LocalContext.current
    val prefs = remember(context) { lplNamePrivacyPreferences(context) }
    var unlocked by remember(context) { mutableStateOf(isLplFullNameAccessUnlocked(context)) }

    DisposableEffect(prefs) {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == LPL_FULL_NAME_ACCESS_UNLOCKED_KEY) {
                unlocked = prefs.getBoolean(LPL_FULL_NAME_ACCESS_UNLOCKED_KEY, false)
            }
        }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        onDispose {
            prefs.unregisterOnSharedPreferenceChangeListener(listener)
        }
    }

    return unlocked
}
