package com.pillyliu.pinprofandroid

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sqrt

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
