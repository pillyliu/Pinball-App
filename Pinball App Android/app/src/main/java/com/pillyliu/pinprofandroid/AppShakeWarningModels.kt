package com.pillyliu.pinprofandroid

import android.os.VibrationEffect
import android.os.Vibrator
import androidx.compose.ui.graphics.Color

internal enum class AppShakeWarningLevel(
    val title: String,
    val subtitle: String,
    val bundledArtAssetPath: String,
    val tint: Color,
    val glow: Color,
    val displayDurationMillis: Long,
    val hapticStartDelayMillis: Long,
) {
    Danger(
        title = "DANGER",
        subtitle = "A little restraint, if you please.",
        bundledArtAssetPath = "shake-warnings/professor-danger_1024.webp",
        tint = Color(0xFFFF9E2E),
        glow = Color(0xFFFFD15C),
        displayDurationMillis = 3_000L,
        hapticStartDelayMillis = 50L,
    ),
    DoubleDanger(
        title = "DANGER DANGER",
        subtitle = "Really, this is most uncivilised shaking.",
        bundledArtAssetPath = "shake-warnings/professor-danger-danger_1024.webp",
        tint = Color(0xFFFF5729),
        glow = Color(0xFFFF852E),
        displayDurationMillis = 3_500L,
        hapticStartDelayMillis = 200L,
    ),
    Tilt(
        title = "TILT",
        subtitle = "That is quite enough! I will not tolerate any further indignity in this cabinet of higher learning.",
        bundledArtAssetPath = "shake-warnings/professor-tilt_1024.webp",
        tint = Color(0xFFFF2424),
        glow = Color(0xFFFF472E),
        displayDurationMillis = 4_500L,
        hapticStartDelayMillis = 200L,
    ),
}

internal object AppShakeMotionTuning {
    const val sampleRateHz = 30
    const val minimumAcceptedShakeIntervalMillis = 850L
    const val candidateWindowMillis = 180L
    const val strongMagnitudeThreshold = 2.45f
    const val combinedMagnitudeThreshold = 1.85f
    const val combinedPeakAxisThreshold = 1.35f
}

internal fun AppShakeWarningLevel.vibrationEffect(vibrator: Vibrator?): VibrationEffect {
    val supportsAmplitude = vibrator?.hasAmplitudeControl() == true
    val dangerAmplitude = if (supportsAmplitude) 189 else VibrationEffect.DEFAULT_AMPLITUDE
    val doubleDangerAmplitude = if (supportsAmplitude) 209 else VibrationEffect.DEFAULT_AMPLITUDE
    val tiltAmplitude = if (supportsAmplitude) 255 else VibrationEffect.DEFAULT_AMPLITUDE
    return when (this) {
        AppShakeWarningLevel.Danger -> {
            VibrationEffect.createWaveform(
                longArrayOf(0L, 110L),
                intArrayOf(0, dangerAmplitude),
                -1,
            )
        }
        AppShakeWarningLevel.DoubleDanger -> {
            VibrationEffect.createWaveform(
                longArrayOf(0L, 110L, 170L, 110L),
                intArrayOf(0, doubleDangerAmplitude, 0, doubleDangerAmplitude),
                -1,
            )
        }
        AppShakeWarningLevel.Tilt -> {
            VibrationEffect.createWaveform(
                longArrayOf(0L, 140L, 150L, 140L, 150L, 140L),
                intArrayOf(0, tiltAmplitude, 0, tiltAmplitude, 0, tiltAmplitude),
                -1,
            )
        }
    }
}
