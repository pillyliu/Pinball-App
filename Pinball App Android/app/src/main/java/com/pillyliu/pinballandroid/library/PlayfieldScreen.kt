package com.pillyliu.pinballandroid.library

import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.graphics.ColorUtils
import androidx.core.graphics.get
import coil.compose.AsyncImage
import coil.imageLoader
import coil.request.ImageRequest
import coil.size.Size
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.ui.LocalBottomBarVisible
import com.pillyliu.pinballandroid.ui.iosEdgeSwipeBack
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.max

@Composable
internal fun ConstrainedAsyncImagePreview(
    urls: List<String>,
    contentDescription: String,
    emptyMessage: String = "No image",
    maxAspectRatio: Float = 4f / 3f,
    imagePadding: Dp = 0.dp,
) {
    val candidates = urls.filter { it.isNotBlank() }.distinct()
    var activeIndex by remember(candidates) { mutableIntStateOf(0) }
    val model = rememberCachedImageModel(candidates.getOrNull(activeIndex))
    val context = LocalContext.current
    val imageRequest = remember(model, context) {
        model?.let { resolvedModel ->
            ImageRequest.Builder(context)
                .data(resolvedModel)
                .size(Size.ORIGINAL)
                .build()
        }
    }
    var aspectRatio by remember(candidates) { mutableFloatStateOf(maxAspectRatio) }
    var imageLoaded by remember(candidates, activeIndex) { mutableStateOf(false) }
    var showMissingImage by remember(candidates, activeIndex) { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(aspectRatio)
            .background(Color.Black, RoundedCornerShape(12.dp))
            .clip(RoundedCornerShape(12.dp)),
        contentAlignment = Alignment.Center,
    ) {
        if (candidates.isEmpty()) {
            Text(emptyMessage, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else {
            AsyncImage(
                model = imageRequest,
                contentDescription = contentDescription,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(imagePadding),
                contentScale = ContentScale.Fit,
                onLoading = {
                    imageLoaded = false
                    showMissingImage = false
                },
                onSuccess = { state ->
                    imageLoaded = true
                    showMissingImage = false
                    val width = state.result.drawable.intrinsicWidth
                    val height = state.result.drawable.intrinsicHeight
                    aspectRatio = if (width > 0 && height > 0) {
                        max(maxAspectRatio, width.toFloat() / height.toFloat())
                    } else {
                        maxAspectRatio
                    }
                },
                onError = {
                    if (activeIndex < candidates.lastIndex) {
                        activeIndex += 1
                        aspectRatio = maxAspectRatio
                    } else {
                        imageLoaded = false
                        showMissingImage = true
                    }
                },
            )

            if (!imageLoaded && !showMissingImage) {
                CircularProgressIndicator()
            }

            if (showMissingImage) {
                Text(emptyMessage, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
internal fun rememberCachedImageModel(url: String?): Any? {
    if (url.isNullOrBlank()) return null
    val model by produceState<Any?>(initialValue = url, key1 = url) {
        value = try {
            withContext(Dispatchers.IO) { PinballDataCache.resolveImageModel(url) }
        } catch (_: Throwable) {
            url
        }
    }
    return model
}

@Composable
internal fun PlayfieldScreen(
    contentPadding: PaddingValues,
    title: String,
    imageUrls: List<String>,
    onBack: () -> Unit,
) {
    val bottomBarVisible = LocalBottomBarVisible.current
    var chromeVisible by rememberSaveable(title) { mutableStateOf(false) }
    val adaptiveTitleColor = rememberPlayfieldTitleColor(imageUrls)

    LaunchedEffect(chromeVisible) {
        bottomBarVisible.value = chromeVisible
    }
    DisposableEffect(Unit) {
        onDispose { bottomBarVisible.value = true }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .iosEdgeSwipeBack(enabled = true, onBack = onBack),
    ) {
        ZoomablePlayfieldImage(
            imageUrls = imageUrls,
            title = title,
            modifier = Modifier.fillMaxSize(),
            onTap = { chromeVisible = !chromeVisible },
        )

        if (chromeVisible) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(contentPadding)
                    .padding(start = 14.dp, end = 14.dp, top = 8.dp),
            ) {
                GlassBackButton(
                    onClick = onBack,
                    modifier = Modifier.align(Alignment.CenterStart),
                )
                Text(
                    text = title,
                    color = adaptiveTitleColor,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .fillMaxWidth()
                        .padding(horizontal = 50.dp),
                )
            }
        }
    }
}

@Composable
private fun rememberPlayfieldTitleColor(imageUrls: List<String>): Color {
    val context = LocalContext.current
    val fallback = MaterialTheme.colorScheme.onSurface
    val candidates = imageUrls.filter { it.isNotBlank() }.distinct()
    val primaryModel = rememberCachedImageModel(candidates.firstOrNull())
    val titleColor by produceState(initialValue = fallback, key1 = primaryModel) {
        value = fallback
        val model = primaryModel ?: return@produceState
        val request = ImageRequest.Builder(context)
            .data(model)
            .allowHardware(false)
            .size(Size.ORIGINAL)
            .build()
        val result = runCatching { context.imageLoader.execute(request) }.getOrNull() ?: return@produceState
        val bitmap = (result.drawable as? BitmapDrawable)?.bitmap ?: return@produceState
        val luma = sampleTopCenterLuma(bitmap)
        value = if (luma < 0.46) Color(0xFFF8FAFC) else Color(0xFF111827)
    }
    return titleColor
}

private fun sampleTopCenterLuma(bitmap: Bitmap): Double {
    val width = bitmap.width
    val height = bitmap.height
    if (width <= 0 || height <= 0) return 0.5

    val left = (width * 0.2f).toInt().coerceIn(0, width - 1)
    val right = (width * 0.8f).toInt().coerceIn(left + 1, width)
    val bottom = (height * 0.22f).toInt().coerceIn(1, height)
    val stepX = maxOf(1, (right - left) / 36)
    val stepY = maxOf(1, bottom / 18)

    var total = 0.0
    var count = 0
    for (y in 0 until bottom step stepY) {
        for (x in left until right step stepX) {
            total += ColorUtils.calculateLuminance(bitmap[x, y])
            count++
        }
    }
    return if (count == 0) 0.5 else total / count
}

@Composable
private fun ZoomablePlayfieldImage(
    imageUrls: List<String>,
    title: String,
    modifier: Modifier = Modifier,
    onTap: () -> Unit = {},
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val candidates = imageUrls.filter { it.isNotBlank() }.distinct()
    var activeImageIndex by remember(candidates) { mutableIntStateOf(0) }
    var imageLoaded by remember(candidates, activeImageIndex) { mutableStateOf(false) }
    var lastTapAtMs by remember { mutableLongStateOf(0L) }
    var singleTapJob by remember { mutableStateOf<Job?>(null) }
    var animateTransform by remember { mutableStateOf(false) }
    var scale by remember { mutableFloatStateOf(1f) }
    var offsetX by remember { mutableFloatStateOf(0f) }
    var offsetY by remember { mutableFloatStateOf(0f) }
    var containerSize by remember { mutableStateOf(androidx.compose.ui.unit.IntSize.Zero) }
    val touchSlop = LocalViewConfiguration.current.touchSlop
    val displayScale by animateFloatAsState(
        targetValue = scale,
        animationSpec = if (animateTransform) tween(durationMillis = 220) else snap(),
        label = "playfieldScale",
    )
    val displayOffsetX by animateFloatAsState(
        targetValue = offsetX,
        animationSpec = if (animateTransform) tween(durationMillis = 220) else snap(),
        label = "playfieldOffsetX",
    )
    val displayOffsetY by animateFloatAsState(
        targetValue = offsetY,
        animationSpec = if (animateTransform) tween(durationMillis = 220) else snap(),
        label = "playfieldOffsetY",
    )

    LaunchedEffect(candidates, activeImageIndex) {
        imageLoaded = false
        val url = candidates.getOrNull(activeImageIndex) ?: return@LaunchedEffect
        if (activeImageIndex >= candidates.lastIndex) return@LaunchedEffect
        val timeoutMs = when {
            url.contains("/pinball/images/playfields/") && !url.contains("_1400.") && !url.contains("_700.") -> 5000L
            url.contains("_1400.") -> 2500L
            else -> return@LaunchedEffect
        }
        delay(timeoutMs)
        if (!imageLoaded && activeImageIndex < candidates.lastIndex) {
            activeImageIndex += 1
        }
    }

    Box(
        modifier = modifier
            .clipToBounds()
            .onSizeChanged { containerSize = it }
            .pointerInput(touchSlop) {
                awaitEachGesture {
                    var moved = false
                    var multiTouch = false
                    var transformed = false
                    var activePointer: androidx.compose.ui.input.pointer.PointerId? = null
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

                        if (pointersDown >= 2 || scale > 1f) {
                            if (animateTransform) animateTransform = false
                            val zoom = event.calculateZoom()
                            val pan = event.calculatePan()
                            if (pointersDown >= 2 || kotlin.math.abs(zoom - 1f) > 0.01f || pan.getDistance() > 0f) {
                                transformed = true
                            }
                            scale = (scale * zoom).coerceIn(1f, 6f)
                            if (scale > 1f) {
                                offsetX += pan.x
                                offsetY += pan.y
                            } else {
                                offsetX = 0f
                                offsetY = 0f
                            }
                        }
                    } while (event.changes.any { it.pressed })

                    if (!multiTouch && !moved && !transformed) {
                        val now = android.os.SystemClock.uptimeMillis()
                        val isDoubleTap = (now - lastTapAtMs) <= 325L
                        if (isDoubleTap) {
                            singleTapJob?.cancel()
                            singleTapJob = null
                            animateTransform = true
                            if (scale > 1f) {
                                scale = 1f
                                offsetX = 0f
                                offsetY = 0f
                            } else {
                                val targetScale = 2.5f
                                val tap = lastPointerPosition ?: Offset(containerSize.width / 2f, containerSize.height / 2f)
                                val center = Offset(containerSize.width / 2f, containerSize.height / 2f)
                                val delta = targetScale - scale
                                scale = targetScale
                                offsetX += (center.x - tap.x) * delta
                                offsetY += (center.y - tap.y) * delta
                            }
                            scope.launch {
                                delay(240)
                                animateTransform = false
                            }
                            lastTapAtMs = 0L
                        } else {
                            lastTapAtMs = now
                            singleTapJob?.cancel()
                            singleTapJob = scope.launch {
                                delay(325)
                                if (lastTapAtMs == now) {
                                    onTap()
                                }
                            }
                        }
                    }
                }
            },
    ) {
        val activeUrl = candidates.getOrNull(activeImageIndex)
        val cachedModel = rememberCachedImageModel(activeUrl)
        val imageRequest = remember(cachedModel) {
            cachedModel?.let { model ->
                ImageRequest.Builder(context)
                    .data(model)
                    .size(Size.ORIGINAL)
                    .build()
            }
        }
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
            onLoading = { imageLoaded = false },
            onSuccess = { imageLoaded = true },
            onError = {
                if (activeImageIndex < candidates.lastIndex) {
                    activeImageIndex += 1
                }
            },
        )

        if (!imageLoaded) {
            CircularProgressIndicator(
                modifier = Modifier.align(Alignment.Center),
                color = Color.White.copy(alpha = 0.9f),
                trackColor = Color.White.copy(alpha = 0.2f),
            )
        }
    }
}
