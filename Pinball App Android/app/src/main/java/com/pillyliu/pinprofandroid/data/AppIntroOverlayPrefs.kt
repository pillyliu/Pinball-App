package com.pillyliu.pinprofandroid.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import com.pillyliu.pinprofandroid.practice.PRACTICE_PREFS

const val APP_INTRO_OVERLAY_CURRENT_VERSION = 1

private const val APP_INTRO_SEEN_VERSION_KEY = "app-intro-seen-version"
private const val APP_INTRO_SHOW_ON_NEXT_LAUNCH_KEY = "app-intro-show-on-next-launch"

private fun appIntroOverlayPreferences(context: Context): SharedPreferences {
    return context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE)
}

fun shouldShowAppIntroOverlayThisLaunch(context: Context): Boolean {
    val prefs = appIntroOverlayPreferences(context)
    val seenVersion = prefs.getInt(APP_INTRO_SEEN_VERSION_KEY, 0)
    val showOnNextLaunch = prefs.getBoolean(APP_INTRO_SHOW_ON_NEXT_LAUNCH_KEY, false)
    return showOnNextLaunch || seenVersion < APP_INTRO_OVERLAY_CURRENT_VERSION
}

fun shouldShowAppIntroOverlayOnNextLaunch(context: Context): Boolean {
    return appIntroOverlayPreferences(context).getBoolean(APP_INTRO_SHOW_ON_NEXT_LAUNCH_KEY, false)
}

fun setShowAppIntroOverlayOnNextLaunch(context: Context, enabled: Boolean) {
    appIntroOverlayPreferences(context).edit {
        putBoolean(APP_INTRO_SHOW_ON_NEXT_LAUNCH_KEY, enabled)
    }
}

fun toggleShowAppIntroOverlayOnNextLaunch(context: Context): Boolean {
    val nextValue = !shouldShowAppIntroOverlayOnNextLaunch(context)
    setShowAppIntroOverlayOnNextLaunch(context, nextValue)
    return nextValue
}

fun completeAppIntroOverlay(context: Context) {
    appIntroOverlayPreferences(context).edit {
        putInt(APP_INTRO_SEEN_VERSION_KEY, APP_INTRO_OVERLAY_CURRENT_VERSION)
        putBoolean(APP_INTRO_SHOW_ON_NEXT_LAUNCH_KEY, false)
    }
}
