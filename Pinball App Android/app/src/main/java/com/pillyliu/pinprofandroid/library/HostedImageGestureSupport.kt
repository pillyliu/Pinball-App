package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.PointerId
import androidx.compose.ui.input.pointer.PointerInputScope
import androidx.compose.ui.unit.IntSize
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Stable
internal class ZoomablePlayfieldGestureState {
    var animateTransform by mutableStateOf(false)
    var scale by mutableFloatStateOf(1f)
    var offsetX by mutableFloatStateOf(0f)
    var offsetY by mutableFloatStateOf(0f)
    var containerSize by mutableStateOf(IntSize.Zero)
    var lastTapAtMs by mutableLongStateOf(0L)
    var singleTapJob by mutableStateOf<Job?>(null)
}

@Composable
internal fun rememberZoomablePlayfieldGestureState(): ZoomablePlayfieldGestureState =
    remember { ZoomablePlayfieldGestureState() }

internal suspend fun PointerInputScope.handleZoomablePlayfieldGestures(
    touchSlop: Float,
    state: ZoomablePlayfieldGestureState,
    scope: CoroutineScope,
    onTap: () -> Unit,
) {
    awaitEachGesture {
        var moved = false
        var multiTouch = false
        var transformed = false
        var activePointer: PointerId? = null
        var accumulatedMove = Offset.Zero
        var lastPointerPosition: Offset? = null

        do {
            val event = awaitPointerEvent()
            val pressedChanges = event.changes.filter { it.pressed }
            val pointersDown = pressedChanges.size
            if (pointersDown >= 2) multiTouch = true
            if (activePointer == null && pressedChanges.isNotEmpty()) {
                activePointer = pressedChanges.first().id
            }
            val tracked = pressedChanges.firstOrNull { it.id == activePointer } ?: pressedChanges.firstOrNull()
            if (tracked != null) {
                lastPointerPosition = tracked.position
                accumulatedMove += tracked.position - tracked.previousPosition
                if (accumulatedMove.getDistance() > touchSlop) moved = true
            }

            if (pointersDown >= 2 || state.scale > 1f) {
                if (state.animateTransform) state.animateTransform = false
                val zoom = event.calculateZoom()
                val pan = event.calculatePan()
                if (pointersDown >= 2 || kotlin.math.abs(zoom - 1f) > 0.01f || pan.getDistance() > 0f) {
                    transformed = true
                }
                state.scale = (state.scale * zoom).coerceIn(1f, 6f)
                if (state.scale > 1f) {
                    state.offsetX += pan.x
                    state.offsetY += pan.y
                } else {
                    state.offsetX = 0f
                    state.offsetY = 0f
                }
            }
        } while (event.changes.any { it.pressed })

        if (!multiTouch && !moved && !transformed) {
            val now = android.os.SystemClock.uptimeMillis()
            val isDoubleTap = (now - state.lastTapAtMs) <= 325L
            if (isDoubleTap) {
                state.singleTapJob?.cancel()
                state.singleTapJob = null
                state.animateTransform = true
                if (state.scale > 1f) {
                    state.scale = 1f
                    state.offsetX = 0f
                    state.offsetY = 0f
                } else {
                    val targetScale = 2.5f
                    val size = state.containerSize
                    val tap = lastPointerPosition ?: Offset(size.width / 2f, size.height / 2f)
                    val center = Offset(size.width / 2f, size.height / 2f)
                    val delta = targetScale - state.scale
                    state.scale = targetScale
                    state.offsetX += (center.x - tap.x) * delta
                    state.offsetY += (center.y - tap.y) * delta
                }
                scope.launch {
                    delay(240)
                    state.animateTransform = false
                }
                state.lastTapAtMs = 0L
            } else {
                state.lastTapAtMs = now
                state.singleTapJob?.cancel()
                state.singleTapJob = scope.launch {
                    delay(325)
                    if (state.lastTapAtMs == now) {
                        onTap()
                    }
                }
            }
        }
    }
}
