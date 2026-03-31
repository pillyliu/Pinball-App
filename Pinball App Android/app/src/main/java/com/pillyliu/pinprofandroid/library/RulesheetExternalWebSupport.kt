package com.pillyliu.pinprofandroid.library

import android.annotation.SuppressLint
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.pillyliu.pinprofandroid.ui.AppRouteScreen
import com.pillyliu.pinprofandroid.ui.AppScreenHeader

@SuppressLint("SetJavaScriptEnabled")
@Composable
internal fun ExternalRulesheetWebScreen(
    contentPadding: PaddingValues,
    title: String,
    url: String,
    onBack: () -> Unit,
) {
    AppRouteScreen(
        contentPadding = contentPadding,
        canGoBack = true,
        onBack = onBack,
    ) {
        Column(modifier = Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            AppScreenHeader(
                title = title,
                onBack = onBack,
                titleColor = MaterialTheme.colorScheme.onSurface,
            )
            ExternalRulesheetWebView(
                url = url,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
internal fun ExternalRulesheetWebView(url: String, modifier: Modifier = Modifier) {
    var loadedUrl by remember(url) { mutableStateOf<String?>(null) }
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
                webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(view: WebView?, request: android.webkit.WebResourceRequest?): Boolean = false
                    override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean = false
                }
            }
        },
        update = { webView ->
            if (loadedUrl != url) {
                loadedUrl = url
                webView.loadUrl(url)
            }
        },
        onRelease = { webView ->
            webView.stopLoading()
            webView.destroy()
        },
    )
}
