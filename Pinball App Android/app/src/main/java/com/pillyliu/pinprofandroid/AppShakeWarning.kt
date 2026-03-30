package com.pillyliu.pinprofandroid

import android.content.Context
import android.os.Build
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

@Stable
internal class AppShakeCoordinator(
    private val nativeUndoAvailabilityProvider: () -> Boolean = { false },
    private val hapticsPlayer: (AppShakeWarningLevel) -> Unit = {},
    dispatcher: CoroutineDispatcher = Dispatchers.Main.immediate,
) {
    var overlayLevel by mutableStateOf<AppShakeWarningLevel?>(null)
        private set

    private val scope = CoroutineScope(SupervisorJob() + dispatcher)
    private var fallbackShakeCount = 0
    private var overlayToken = 0L

    fun handleDetectedShake() {
        if (nativeUndoAvailabilityProvider()) return
        if (overlayLevel == AppShakeWarningLevel.Tilt) return

        fallbackShakeCount = minOf(fallbackShakeCount + 1, AppShakeWarningLevel.Tilt.ordinal + 1)
        val level = when (fallbackShakeCount) {
            1 -> AppShakeWarningLevel.Danger
            2 -> AppShakeWarningLevel.DoubleDanger
            else -> AppShakeWarningLevel.Tilt
        }
        if (level == AppShakeWarningLevel.Tilt) {
            fallbackShakeCount = 0
        }
        present(level)
    }

    fun dispose() {
        scope.cancel()
    }

    private fun present(level: AppShakeWarningLevel) {
        overlayToken += 1
        val currentToken = overlayToken
        overlayLevel = level
        try {
            hapticsPlayer(level)
        } catch (_: SecurityException) {
            // Some devices reject vibration without permission or user allowance; the overlay should still show.
        } catch (_: RuntimeException) {
            // Keep the warning flow alive even if the platform vibrator service misbehaves.
        }

        scope.launch {
            delay(level.displayDurationMillis)
            if (!isActive) return@launch
            if (currentToken != overlayToken) return@launch
            overlayLevel = null
        }
    }
}

internal class AppShakeWarningHaptics(
    context: Context,
    dispatcher: CoroutineDispatcher = Dispatchers.Main.immediate,
) {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + dispatcher)
    private val vibrator: Vibrator? = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val manager = appContext.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator
        }
        else -> {
            @Suppress("DEPRECATION")
            appContext.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }?.takeIf { it.hasVibrator() }

    private var playbackJob: Job? = null

    fun play(level: AppShakeWarningLevel) {
        playbackJob?.cancel()
        cancelVibrationSafely()
        playbackJob = scope.launch {
            delay(level.hapticStartDelayMillis)
            if (!isActive) return@launch
            vibrateSafely(level)
        }
    }

    fun dispose() {
        playbackJob?.cancel()
        cancelVibrationSafely()
        scope.cancel()
    }

    private fun cancelVibrationSafely() {
        val activeVibrator = vibrator ?: return
        try {
            activeVibrator.cancel()
        } catch (_: SecurityException) {
            // Ignore device-specific vibration permission failures during cleanup.
        } catch (_: RuntimeException) {
            // Some vendor services can throw when the vibrator is unavailable; cleanup should stay best effort.
        }
    }

    private fun vibrateSafely(level: AppShakeWarningLevel) {
        val activeVibrator = vibrator ?: return
        try {
            activeVibrator.vibrate(level.vibrationEffect(activeVibrator))
        } catch (_: SecurityException) {
            // Ignore missing vibration permission and keep the overlay visible.
        } catch (_: RuntimeException) {
            // Guard against vendor-specific vibrator service failures.
        }
    }
}
