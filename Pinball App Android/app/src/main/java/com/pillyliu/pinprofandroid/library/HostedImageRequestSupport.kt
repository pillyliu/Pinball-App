package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import coil.request.ImageRequest
import coil.size.Size
import com.pillyliu.pinprofandroid.ui.AppFullscreenStatusOverlay

@Composable
internal fun rememberPlayfieldImageRequest(activeUrl: String?): ImageRequest? {
    val context = LocalContext.current
    return remember(activeUrl, context) {
        activeUrl?.let { url ->
            ImageRequest.Builder(context)
                .data(url)
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

@Composable
internal fun PlayfieldImageFailureOverlay(sourceUrl: String?) {
    val uriHandler = LocalUriHandler.current
    Box(modifier = Modifier.fillMaxSize()) {
        AppFullscreenStatusOverlay(
            text = "Could not load image.",
            modifier = Modifier,
            foregroundColor = Color.White.copy(alpha = 0.9f),
        )

        if (!sourceUrl.isNullOrBlank()) {
            TextButton(
                onClick = { uriHandler.openUri(sourceUrl) },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 34.dp),
            ) {
                Text(
                    text = "Open Original URL",
                    color = Color.White.copy(alpha = 0.92f),
                )
            }
        }
    }
}
