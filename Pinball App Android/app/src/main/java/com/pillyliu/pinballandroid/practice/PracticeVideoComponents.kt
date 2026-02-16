package com.pillyliu.pinballandroid.practice

import android.annotation.SuppressLint
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import coil.compose.AsyncImage

@SuppressLint("SetJavaScriptEnabled")
@Composable
internal fun PracticeEmbeddedYouTubeView(videoId: String, modifier: Modifier = Modifier) {
    var loadedVideoId by remember(videoId) { mutableStateOf<String?>(null) }
    AndroidView(
        modifier = modifier,
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.mediaPlaybackRequiresUserGesture = false
                settings.loadsImagesAutomatically = true
                settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                settings.useWideViewPort = false
                settings.loadWithOverviewMode = false
                setBackgroundColor(android.graphics.Color.BLACK)
                webChromeClient = WebChromeClient()
                webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean = false
                    override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean = false
                }
            }
        },
        update = { webView ->
            if (loadedVideoId != videoId) {
                loadedVideoId = videoId
                webView.loadUrl("https://m.youtube.com/watch?v=$videoId&app=m")
            }
        },
        onRelease = { webView ->
            webView.stopLoading()
            webView.destroy()
        },
    )
}

@Composable
internal fun PracticeVideoTile(
    videoId: String,
    label: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val shape = androidx.compose.foundation.shape.RoundedCornerShape(10.dp)
    Column(
        modifier = modifier
            .clip(shape)
            .clickable(onClick = onClick)
            .background(
                if (selected) MaterialTheme.colorScheme.surfaceContainerHigh else MaterialTheme.colorScheme.surfaceContainerLow,
                shape = shape,
            )
            .border(
                width = 1.dp,
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = if (selected) 0.85f else 0.6f),
                shape = shape,
            )
            .padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        AsyncImage(
            model = "https://i.ytimg.com/vi/$videoId/hqdefault.jpg",
            contentDescription = label,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp)),
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
