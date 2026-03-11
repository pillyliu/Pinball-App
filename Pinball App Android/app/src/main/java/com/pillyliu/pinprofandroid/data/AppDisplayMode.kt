package com.pillyliu.pinprofandroid.data

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.edit
import com.pillyliu.pinprofandroid.practice.PRACTICE_PREFS

enum class AppDisplayMode(
    val storageValue: String,
    val label: String,
) {
    SYSTEM("system", "System"),
    LIGHT("light", "Light"),
    DARK("dark", "Dark");

    companion object {
        private const val DISPLAY_MODE_KEY = "app-display-mode"

        fun fromStorageValue(value: String?): AppDisplayMode {
            return entries.firstOrNull { it.storageValue == value } ?: SYSTEM
        }

        fun preferenceKey(): String = DISPLAY_MODE_KEY
    }
}

private fun appDisplayModePreferences(context: Context): SharedPreferences {
    return context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE)
}

fun getAppDisplayMode(context: Context): AppDisplayMode {
    val stored = appDisplayModePreferences(context).getString(AppDisplayMode.preferenceKey(), null)
    return AppDisplayMode.fromStorageValue(stored)
}

fun setAppDisplayMode(context: Context, mode: AppDisplayMode) {
    appDisplayModePreferences(context).edit {
        putString(AppDisplayMode.preferenceKey(), mode.storageValue)
    }
}

@Composable
fun rememberAppDisplayMode(): AppDisplayMode {
    val context = LocalContext.current
    val prefs = remember(context) { appDisplayModePreferences(context) }
    var displayMode by remember(context) { mutableStateOf(getAppDisplayMode(context)) }

    DisposableEffect(prefs) {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == AppDisplayMode.preferenceKey()) {
                displayMode = AppDisplayMode.fromStorageValue(
                    prefs.getString(AppDisplayMode.preferenceKey(), null),
                )
            }
        }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        onDispose {
            prefs.unregisterOnSharedPreferenceChangeListener(listener)
        }
    }

    return displayMode
}
