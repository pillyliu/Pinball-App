package com.pillyliu.pinprofandroid.library

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import coil.request.ImageRequest
import coil.size.Size
import com.pillyliu.pinprofandroid.ui.AppFullscreenStatusOverlay

@Composable
internal fun rememberPlayfieldImageRequest(activeUrl: String?): ImageRequest? {
    val context = LocalContext.current
    val cachedModel = rememberCachedImageModel(activeUrl)
    return remember(cachedModel) {
        cachedModel?.let { model ->
            ImageRequest.Builder(context)
                .data(model)
                .size(Size.ORIGINAL)
                .build()
        }
    }
}

@Composable
internal fun PlayfieldImageLoadingOverlay() {
    AppFullscreenStatusOverlay(
        text = "Loading image…",
        modifier = Modifier,
        showsProgress = true,
        foregroundColor = Color.White.copy(alpha = 0.9f),
    )
}
