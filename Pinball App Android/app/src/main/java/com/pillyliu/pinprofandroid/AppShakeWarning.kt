package com.pillyliu.pinprofandroid

import android.content.Context
import android.graphics.BitmapFactory
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Photo
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.library.libraryMissingArtworkPath
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sqrt

internal enum class AppShakeWarningLevel(
    val title: String,
    val subtitle: String,
    val bundledArtPath: String,
    val tint: Color,
    val glow: Color,
    val displayDurationMillis: Long,
    val hapticStartDelayMillis: Long,
) {
    Danger(
        title = "DANGER",
        subtitle = "A little restraint, if you please.",
        bundledArtPath = "/pinball/images/ui/shake-warnings/professor-danger_1024.webp",
        tint = Color(0xFFFF9E2E),
        glow = Color(0xFFFFD15C),
        displayDurationMillis = 3_000L,
        hapticStartDelayMillis = 50L,
    ),
    DoubleDanger(
        title = "DANGER DANGER",
        subtitle = "Really, this is most uncivilised shaking.",
        bundledArtPath = "/pinball/images/ui/shake-warnings/professor-danger-danger_1024.webp",
        tint = Color(0xFFFF5729),
        glow = Color(0xFFFF852E),
        displayDurationMillis = 3_500L,
        hapticStartDelayMillis = 200L,
    ),
    Tilt(
        title = "TILT",
        subtitle = "That is quite enough! I will not tolerate any further indignity in this cabinet of higher learning.",
        bundledArtPath = "/pinball/images/ui/shake-warnings/professor-tilt_1024.webp",
        tint = Color(0xFFFF2424),
        glow = Color(0xFFFF472E),
        displayDurationMillis = 4_500L,
        hapticStartDelayMillis = 200L,
    ),
    ;
}

internal object AppShakeMotionTuning {
    const val sampleRateHz = 30
    const val minimumAcceptedShakeIntervalMillis = 850L
    const val candidateWindowMillis = 180L
    const val strongMagnitudeThreshold = 2.45f
    const val combinedMagnitudeThreshold = 1.85f
    const val combinedPeakAxisThreshold = 1.35f
}

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

private fun AppShakeWarningLevel.vibrationEffect(vibrator: Vibrator?): VibrationEffect {
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

private class AppShakeMotionObserver(context: Context) : SensorEventListener {
    private val sensorManager = context.applicationContext.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    private val linearAccelerationSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
    private val accelerometerSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val gravity = FloatArray(3)
    private var activeSensorType: Int? = null
    private var lastShakeAtMs: Long = 0L
    private var candidateShakeAtMs: Long? = null
    private var onShake: (() -> Unit)? = null

    fun update(isEnabled: Boolean, onShake: () -> Unit) {
        this.onShake = onShake
        if (isEnabled) {
            startIfNeeded()
        } else {
            stop()
        }
    }

    fun stop() {
        if (activeSensorType != null) {
            sensorManager?.unregisterListener(this)
        }
        activeSensorType = null
        candidateShakeAtMs = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val accelerationG = normalizedAcceleration(event) ?: return
        val x = accelerationG[0]
        val y = accelerationG[1]
        val z = accelerationG[2]
        val magnitude = sqrt((x * x) + (y * y) + (z * z))
        val peakAxis = max(abs(x), max(abs(y), abs(z)))
        val now = SystemClock.elapsedRealtime()

        if (now - lastShakeAtMs <= AppShakeMotionTuning.minimumAcceptedShakeIntervalMillis) return
        val exceedsThreshold =
            magnitude > AppShakeMotionTuning.strongMagnitudeThreshold ||
                (magnitude > AppShakeMotionTuning.combinedMagnitudeThreshold &&
                    peakAxis > AppShakeMotionTuning.combinedPeakAxisThreshold)
        if (!exceedsThreshold) {
            val pendingCandidateShakeAtMs = candidateShakeAtMs
            if (pendingCandidateShakeAtMs != null &&
                now - pendingCandidateShakeAtMs > AppShakeMotionTuning.candidateWindowMillis
            ) {
                this.candidateShakeAtMs = null
            }
            return
        }

        val pendingCandidateShakeAtMs = candidateShakeAtMs
        if (pendingCandidateShakeAtMs != null &&
            now - pendingCandidateShakeAtMs <= AppShakeMotionTuning.candidateWindowMillis
        ) {
            this.candidateShakeAtMs = null
            lastShakeAtMs = now
            onShake?.invoke()
            return
        }

        candidateShakeAtMs = now
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun startIfNeeded() {
        val manager = sensorManager ?: return
        if (activeSensorType != null) return
        val sensor = linearAccelerationSensor ?: accelerometerSensor ?: return
        gravity.fill(0f)
        val samplePeriodUs = (1_000_000f / AppShakeMotionTuning.sampleRateHz.toFloat()).toInt()
        if (manager.registerListener(this, sensor, samplePeriodUs)) {
            activeSensorType = sensor.type
        }
    }

    private fun normalizedAcceleration(event: SensorEvent): FloatArray? {
        val values = event.values
        return when (event.sensor.type) {
            Sensor.TYPE_LINEAR_ACCELERATION -> {
                floatArrayOf(
                    values[0] / SensorManager.GRAVITY_EARTH,
                    values[1] / SensorManager.GRAVITY_EARTH,
                    values[2] / SensorManager.GRAVITY_EARTH,
                )
            }
            Sensor.TYPE_ACCELEROMETER -> {
                val alpha = 0.8f
                gravity[0] = alpha * gravity[0] + (1 - alpha) * values[0]
                gravity[1] = alpha * gravity[1] + (1 - alpha) * values[1]
                gravity[2] = alpha * gravity[2] + (1 - alpha) * values[2]
                floatArrayOf(
                    (values[0] - gravity[0]) / SensorManager.GRAVITY_EARTH,
                    (values[1] - gravity[1]) / SensorManager.GRAVITY_EARTH,
                    (values[2] - gravity[2]) / SensorManager.GRAVITY_EARTH,
                )
            }
            else -> null
        }
    }
}

@Composable
internal fun AppShakeMotionEffect(
    isEnabled: Boolean = true,
    onShake: () -> Unit,
) {
    val context = LocalContext.current.applicationContext
    val currentOnShake by rememberUpdatedState(onShake)
    val observer = remember(context) { AppShakeMotionObserver(context) }
    val lifecycleResumed = rememberLifecycleResumed()

    SideEffect {
        observer.update(isEnabled = isEnabled && lifecycleResumed) {
            currentOnShake()
        }
    }

    DisposableEffect(observer) {
        onDispose { observer.stop() }
    }
}

@Composable
private fun rememberLifecycleResumed(): Boolean {
    val lifecycleOwner = LocalLifecycleOwner.current
    var resumed by remember(lifecycleOwner) {
        mutableStateOf(lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED))
    }

    DisposableEffect(lifecycleOwner) {
        val lifecycle = lifecycleOwner.lifecycle
        val observer = LifecycleEventObserver { _, _ ->
            resumed = lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }

    return resumed
}

@Composable
internal fun AppShakeWarningHost(
    overlayLevel: AppShakeWarningLevel?,
    modifier: Modifier = Modifier,
) {
    AnimatedVisibility(
        visible = overlayLevel != null,
        modifier = modifier,
        enter = fadeIn(animationSpec = tween(durationMillis = 180)),
        exit = fadeOut(animationSpec = tween(durationMillis = 300)),
    ) {
        overlayLevel?.let { level ->
            AppShakeWarningOverlay(
                level = level,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

@Composable
private fun AppShakeWarningOverlay(
    level: AppShakeWarningLevel,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val isLandscape = maxWidth > maxHeight
        val outerHorizontalPadding = 28.dp
        val outerVerticalPadding = 24.dp
        val cardHorizontalPadding = if (isLandscape) 22.dp else 28.dp
        val cardVerticalPadding = if (isLandscape) 20.dp else 24.dp
        val landscapeSpacing = 20.dp
        val maxLandscapeCardWidth = (maxWidth - (outerHorizontalPadding * 2)).coerceAtMost(760.dp)
        val maxLandscapeCardHeight = (maxHeight - (outerVerticalPadding * 2)).coerceAtMost(340.dp)
        val landscapePaneWidth = minOf(
            (maxLandscapeCardWidth - (cardHorizontalPadding * 2) - landscapeSpacing) / 2,
            maxLandscapeCardHeight - (cardVerticalPadding * 2),
        )
        val landscapeCardWidth = (landscapePaneWidth * 2) + landscapeSpacing + (cardHorizontalPadding * 2)
        val landscapeCardHeight = landscapePaneWidth + (cardVerticalPadding * 2)
        val portraitCardWidth = (maxWidth - (outerHorizontalPadding * 2))
            .coerceAtLeast(280.dp)
            .coerceAtMost(420.dp)
        val portraitImageSide = minOf(portraitCardWidth - (cardHorizontalPadding * 2), 360.dp)
        val cardShape = RoundedCornerShape(28.dp)

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            level.tint.copy(alpha = if (level == AppShakeWarningLevel.Tilt) 0.32f else 0.20f),
                            Color.Black.copy(alpha = if (level == AppShakeWarningLevel.Tilt) 0.58f else 0.42f),
                        ),
                    ),
                ),
        )

        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .padding(horizontal = outerHorizontalPadding, vertical = outerVerticalPadding)
                    .then(
                        if (isLandscape) {
                            Modifier
                                .width(landscapeCardWidth)
                                .height(landscapeCardHeight)
                        } else {
                            Modifier.width(portraitCardWidth)
                        },
                    )
                    .shadow(28.dp, cardShape)
                    .clip(cardShape)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                colors.panel.copy(alpha = 0.94f),
                                colors.atmosphereBottom.copy(alpha = 0.96f),
                            ),
                        ),
                    )
                    .border(1.2.dp, level.glow.copy(alpha = 0.78f), cardShape),
            ) {
                Box(
                    modifier = Modifier
                        .matchParentSize()
                        .background(
                            Brush.linearGradient(
                                colors = listOf(
                                    level.glow.copy(alpha = 0.34f),
                                    Color.Transparent,
                                    level.tint.copy(alpha = 0.22f),
                                ),
                                start = Offset.Zero,
                                end = Offset(1600f, 1600f),
                            ),
                        ),
                )

                if (isLandscape) {
                    Row(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = cardHorizontalPadding, vertical = cardVerticalPadding),
                        horizontalArrangement = Arrangement.spacedBy(landscapeSpacing, Alignment.CenterHorizontally),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        AppShakeProfessorArt(
                            level = level,
                            boxSide = landscapePaneWidth,
                        )
                        AppShakeWarningCopy(
                            level = level,
                            isLandscape = true,
                            modifier = Modifier
                                .width(landscapePaneWidth)
                                .height(landscapePaneWidth),
                        )
                    }
                } else {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = cardHorizontalPadding, vertical = cardVerticalPadding),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(18.dp),
                    ) {
                        AppShakeProfessorArt(
                            level = level,
                            boxSide = portraitImageSide,
                        )
                        AppShakeWarningCopy(
                            level = level,
                            isLandscape = false,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AppShakeWarningCopy(
    level: AppShakeWarningLevel,
    isLandscape: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = if (isLandscape) Alignment.Start else Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            repeat(AppShakeWarningLevel.entries.size) { index ->
                Box(
                    modifier = Modifier
                        .width(if (isLandscape) 44.dp else 52.dp)
                        .height(8.dp)
                        .clip(RoundedCornerShape(999.dp))
                        .background(
                            if (index < level.ordinal + 1) {
                                level.glow
                            } else {
                                Color.White.copy(alpha = 0.14f)
                            },
                        ),
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = level.title,
            color = level.glow,
            style = TextStyle(
                fontSize = 34.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = 2.5.sp,
            ),
            textAlign = if (isLandscape) TextAlign.Start else TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = level.subtitle,
            color = Color.White.copy(alpha = 0.88f),
            style = appShakeProfessorSubtitleStyle(),
            textAlign = if (isLandscape) TextAlign.Start else TextAlign.Center,
            modifier = if (isLandscape) Modifier else Modifier.widthIn(max = 320.dp),
        )
    }
}

@Composable
private fun appShakeProfessorSubtitleStyle(): TextStyle {
    return MaterialTheme.typography.bodyMedium.copy(
        fontSize = 17.sp,
        fontWeight = FontWeight.SemiBold,
        fontFamily = FontFamily.Serif,
        fontStyle = FontStyle.Italic,
        lineHeight = 22.sp,
    )
}

@Composable
private fun AppShakeProfessorArt(
    level: AppShakeWarningLevel,
    boxSide: Dp,
) {
    val colors = PinballThemeTokens.colors
    val shape = RoundedCornerShape(24.dp)
    val image = rememberAppShakeProfessorArt(level)

    Box(
        modifier = Modifier
            .size(boxSide)
            .shadow(18.dp, shape)
            .clip(shape)
            .background(colors.atmosphereBottom.copy(alpha = 0.96f))
            .border(1.2.dp, level.glow.copy(alpha = 0.72f), shape),
        contentAlignment = Alignment.Center,
    ) {
        if (image != null) {
            Image(
                bitmap = image,
                contentDescription = level.title,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        } else {
            AppShakeProfessorEmergencyPlaceholder(
                level = level,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(14.dp),
            )
        }
    }
}

@Composable
private fun rememberAppShakeProfessorArt(level: AppShakeWarningLevel): ImageBitmap? {
    val context = LocalContext.current.applicationContext
    val image by produceState<ImageBitmap?>(initialValue = null, key1 = context, key2 = level) {
        value = withContext(Dispatchers.IO) {
            decodeStarterPackImage(context, level.bundledArtPath)
                ?: decodeStarterPackImage(context, libraryMissingArtworkPath)
        }
    }
    return image
}

private fun decodeStarterPackImage(context: Context, path: String): ImageBitmap? {
    val bytes = PinballDataCache.loadBundledStarterBytes(path) ?: return null
    val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
    return bitmap.asImageBitmap()
}

@Composable
private fun AppShakeProfessorEmergencyPlaceholder(
    level: AppShakeWarningLevel,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color.Black.copy(alpha = 0.76f),
                        level.tint.copy(alpha = 0.18f),
                        colors.brandInk.copy(alpha = 0.92f),
                    ),
                    start = Offset.Zero,
                    end = Offset(1200f, 1200f),
                ),
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically),
        ) {
            Icon(
                imageVector = Icons.Outlined.Photo,
                contentDescription = null,
                tint = level.glow.copy(alpha = 0.94f),
                modifier = Modifier.size(56.dp),
            )
            Box(
                modifier = Modifier
                    .widthIn(max = 220.dp)
                    .heightIn(min = 92.dp),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(RoundedCornerShape(12.dp))
                        .background(colors.atmosphereBottom)
                        .border(1.dp, colors.brandChalk.copy(alpha = 0.2f), RoundedCornerShape(12.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Sorry, no image available",
                        color = colors.brandChalk,
                        style = MaterialTheme.typography.bodySmall,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 12.dp),
                    )
                }
            }
            Text(
                text = "Shared warning art failed to load.",
                color = Color.White.copy(alpha = 0.7f),
                style = MaterialTheme.typography.labelSmall,
                textAlign = TextAlign.Center,
            )
        }
    }
}
