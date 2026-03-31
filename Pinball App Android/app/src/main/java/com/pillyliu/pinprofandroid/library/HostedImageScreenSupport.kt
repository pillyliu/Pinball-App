package com.pillyliu.pinprofandroid.library

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import coil.compose.AsyncImage
import kotlinx.coroutines.delay

@Composable
internal fun ZoomablePlayfieldImage(
    imageUrls: List<String>,
    title: String,
    modifier: Modifier = Modifier,
    onTap: () -> Unit = {},
) {
    val scope = rememberCoroutineScope()
    val candidates = prioritizeHostedImageCandidates(
        imageUrls.filter { it.isNotBlank() }.distinct(),
    )
    var activeImageIndex by remember(candidates) { mutableIntStateOf(0) }
    var imageLoaded by remember(candidates, activeImageIndex) { mutableStateOf(false) }
    var showFailure by remember(candidates, activeImageIndex) { mutableStateOf(false) }
    val gestureState = rememberZoomablePlayfieldGestureState()
    val touchSlop = androidx.compose.ui.platform.LocalViewConfiguration.current.touchSlop
    val displayScale by animateFloatAsState(
        targetValue = gestureState.scale,
        animationSpec = if (gestureState.animateTransform) tween(durationMillis = 220) else snap(),
        label = "playfieldScale",
    )
    val displayOffsetX by animateFloatAsState(
        targetValue = gestureState.offsetX,
        animationSpec = if (gestureState.animateTransform) tween(durationMillis = 220) else snap(),
        label = "playfieldOffsetX",
    )
    val displayOffsetY by animateFloatAsState(
        targetValue = gestureState.offsetY,
        animationSpec = if (gestureState.animateTransform) tween(durationMillis = 220) else snap(),
        label = "playfieldOffsetY",
    )

    LaunchedEffect(candidates, activeImageIndex) {
        imageLoaded = false
        showFailure = false
        val url = candidates.getOrNull(activeImageIndex) ?: return@LaunchedEffect
        val timeoutMs = hostedImageLoadTimeoutMs(url) ?: return@LaunchedEffect
        delay(timeoutMs)
        if (!imageLoaded) {
            if (activeImageIndex < candidates.lastIndex) {
                activeImageIndex += 1
            } else {
                showFailure = true
            }
        }
    }

    Box(
        modifier = modifier
            .clipToBounds()
            .onSizeChanged { gestureState.containerSize = it }
            .pointerInput(touchSlop) {
                handleZoomablePlayfieldGestures(
                    touchSlop = touchSlop,
                    state = gestureState,
                    scope = scope,
                    onTap = onTap,
                )
            },
    ) {
        val activeUrl = candidates.getOrNull(activeImageIndex)
        val imageRequest = rememberPlayfieldImageRequest(activeUrl)
        if (showFailure || candidates.isEmpty()) {
            Box(modifier = Modifier.align(Alignment.Center)) {
                PlayfieldImageFailureOverlay(
                    sourceUrl = candidates.getOrNull(activeImageIndex) ?: candidates.firstOrNull(),
                )
            }
        } else {
            AsyncImage(
                model = imageRequest,
                contentDescription = title,
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        scaleX = displayScale
                        scaleY = displayScale
                        translationX = displayOffsetX
                        translationY = displayOffsetY
                    },
                contentScale = ContentScale.Fit,
                onLoading = {
                    imageLoaded = false
                    showFailure = false
                },
                onSuccess = {
                    imageLoaded = true
                    showFailure = false
                },
                onError = {
                    if (activeImageIndex < candidates.lastIndex) {
                        activeImageIndex += 1
                    } else {
                        showFailure = true
                    }
                },
            )

            if (!imageLoaded) {
                Box(modifier = Modifier.align(Alignment.Center)) {
                    PlayfieldImageLoadingOverlay()
                }
            }
        }
    }
}
