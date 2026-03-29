package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.draw.clip
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import coil.size.Size
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.ui.AppMediaPreviewPlaceholder
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
            AppMediaPreviewPlaceholder(message = emptyMessage)
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
                AppMediaPreviewPlaceholder(showsProgress = true)
            }

            if (showMissingImage) {
                AppMediaPreviewPlaceholder(message = emptyMessage)
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
