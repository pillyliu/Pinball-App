package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.pillyliu.pinprofandroid.ui.AppMediaPreviewPlaceholder
import com.pillyliu.pinprofandroid.ui.appVideoTileBorderColor
import com.pillyliu.pinprofandroid.ui.appVideoTileContainerColor
import com.pillyliu.pinprofandroid.ui.appVideoTileLabelColor

@Composable
internal fun FallbackAsyncImage(
    urls: List<String>,
    contentDescription: String,
    modifier: Modifier,
    contentScale: ContentScale,
) {
    val candidates = urls.filter { it.isNotBlank() }.distinct()
    var activeIndex by remember(candidates) { mutableIntStateOf(0) }
    val model = rememberCachedImageModel(candidates.getOrNull(activeIndex))
    var imageLoaded by remember(candidates, activeIndex) { mutableStateOf(false) }
    var showMissingImage by remember(candidates, activeIndex) { mutableStateOf(candidates.isEmpty()) }
    Box(modifier = modifier) {
        if (candidates.isNotEmpty()) {
            AsyncImage(
                model = model,
                contentDescription = contentDescription,
                modifier = Modifier.fillMaxSize(),
                contentScale = contentScale,
                onLoading = {
                    imageLoaded = false
                    showMissingImage = false
                },
                onSuccess = {
                    imageLoaded = true
                    showMissingImage = false
                },
                onError = {
                    if (activeIndex < candidates.lastIndex) {
                        activeIndex += 1
                    } else {
                        imageLoaded = false
                        showMissingImage = true
                    }
                },
            )
        }

        when {
            candidates.isEmpty() -> AppMediaPreviewPlaceholder(message = "No image")
            !imageLoaded && !showMissingImage -> AppMediaPreviewPlaceholder(showsProgress = true)
            showMissingImage -> AppMediaPreviewPlaceholder(message = "No image")
        }
    }
}

@Composable
private fun VideoTileThumbnail(
    thumbnailUrl: String,
    label: String,
    modifier: Modifier,
) {
    var imageLoaded by remember(thumbnailUrl) { mutableStateOf(false) }
    var showMissingImage by remember(thumbnailUrl) { mutableStateOf(thumbnailUrl.isBlank()) }
    Box(modifier = modifier) {
        if (thumbnailUrl.isNotBlank()) {
            AsyncImage(
                model = thumbnailUrl,
                contentDescription = label,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
                onLoading = {
                    imageLoaded = false
                    showMissingImage = false
                },
                onSuccess = {
                    imageLoaded = true
                    showMissingImage = false
                },
                onError = {
                    imageLoaded = false
                    showMissingImage = true
                },
            )
        }

        when {
            thumbnailUrl.isBlank() -> AppMediaPreviewPlaceholder(message = "No image")
            !imageLoaded && !showMissingImage -> AppMediaPreviewPlaceholder(showsProgress = true)
            showMissingImage -> AppMediaPreviewPlaceholder()
        }
    }
}

@Composable
internal fun VideoTile(
    video: PlayableVideo,
    selected: Boolean,
    width: Dp,
    onSelect: () -> Unit,
) {
    androidx.compose.foundation.layout.Column(
        modifier = Modifier
            .width(width)
            .clickable(onClick = onSelect)
            .background(appVideoTileContainerColor(selected), RoundedCornerShape(8.dp))
            .border(1.dp, appVideoTileBorderColor(selected), RoundedCornerShape(8.dp))
            .padding(8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        VideoTileThumbnail(
            thumbnailUrl = video.thumbnailUrl,
            label = video.label,
            modifier = Modifier.fillMaxWidth().aspectRatio(16f / 9f),
        )
        Text(video.label, color = appVideoTileLabelColor(selected), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}
