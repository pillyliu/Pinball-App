package com.pillyliu.pinprofandroid

import android.content.Context
import android.content.ContextWrapper
import android.content.res.Configuration
import android.graphics.Color as AndroidColor
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalContext
import com.pillyliu.pinprofandroid.data.AppDisplayMode

private val pinballLightNavigationScrim = AndroidColor.argb(0xE6, 0xFF, 0xFF, 0xFF)
private val pinballDarkNavigationScrim = AndroidColor.argb(0x80, 0x1B, 0x1B, 0x1B)

internal fun appUsesDarkTheme(
    displayMode: AppDisplayMode,
    context: Context,
): Boolean {
    return when (displayMode) {
        AppDisplayMode.SYSTEM -> {
            (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
        AppDisplayMode.LIGHT -> false
        AppDisplayMode.DARK -> true
    }
}

internal fun applyPinballEdgeToEdge(
    activity: ComponentActivity,
    darkTheme: Boolean,
) {
    activity.enableEdgeToEdge(
        statusBarStyle = SystemBarStyle.auto(
            lightScrim = AndroidColor.TRANSPARENT,
            darkScrim = AndroidColor.TRANSPARENT,
            detectDarkMode = { darkTheme },
        ),
        navigationBarStyle = SystemBarStyle.auto(
            lightScrim = pinballLightNavigationScrim,
            darkScrim = pinballDarkNavigationScrim,
            detectDarkMode = { darkTheme },
        ),
    )
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        activity.window.isNavigationBarContrastEnforced = false
    }
}

@Composable
internal fun PinballEdgeToEdgeEffect(darkTheme: Boolean) {
    val context = LocalContext.current
    val activity = context.findComponentActivity()
    DisposableEffect(activity, darkTheme) {
        if (activity != null) {
            applyPinballEdgeToEdge(activity, darkTheme)
        }
        onDispose { }
    }
}

private tailrec fun Context.findComponentActivity(): ComponentActivity? {
    return when (this) {
        is ComponentActivity -> this
        is ContextWrapper -> baseContext.findComponentActivity()
        else -> null
    }
}
