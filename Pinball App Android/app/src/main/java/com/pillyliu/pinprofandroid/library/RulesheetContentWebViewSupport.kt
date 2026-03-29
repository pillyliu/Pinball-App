package com.pillyliu.pinprofandroid.library

import android.annotation.SuppressLint
import android.os.Bundle
import android.view.MotionEvent
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView

@SuppressLint("SetJavaScriptEnabled")
@Composable
internal fun RulesheetContentWebView(
    content: RulesheetRenderContent,
    modifier: Modifier = Modifier,
    stateKey: String = "default",
    resumeRequestId: Int = 0,
    resumeTargetRatio: Float? = null,
    onTap: (() -> Unit)? = null,
    onProgressChange: (Float) -> Unit = {},
) {
    val bodyColorHex = MaterialTheme.colorScheme.onSurface.toCssHex()
    val mutedColorHex = MaterialTheme.colorScheme.onSurfaceVariant.toCssHex()
    val linkColorHex = MaterialTheme.colorScheme.primary.toCssHex()
    val linkSoftHex = MaterialTheme.colorScheme.primary.copy(alpha = 0.14f).toCssHex()
    val codeBgHex = MaterialTheme.colorScheme.surfaceContainerLowest.toCssHex()
    val panelHex = MaterialTheme.colorScheme.surfaceContainerHigh.toCssHex()
    val panelStrongHex = MaterialTheme.colorScheme.surfaceContainerHighest.toCssHex()
    val tableBorderHex = MaterialTheme.colorScheme.outlineVariant.toCssHex()
    val blockquoteBarHex = MaterialTheme.colorScheme.primary.copy(alpha = 0.42f).toCssHex()
    val webViewState = rememberSaveable(stateKey, saver = bundleParcelSaver) { Bundle() }
    var savedScrollRatio by rememberSaveable(stateKey) { mutableFloatStateOf(0f) }
    var loadedHash by remember(stateKey) { mutableStateOf<Int?>(null) }
    var lastAppliedResumeRequestId by remember(stateKey) { mutableIntStateOf(-1) }
    AndroidView(
        modifier = modifier,
        factory = { context ->
            WebView(context).apply {
                var downX = 0f
                var downY = 0f
                setBackgroundColor(android.graphics.Color.TRANSPARENT)
                settings.javaScriptEnabled = false
                settings.cacheMode = WebSettings.LOAD_NO_CACHE
                settings.domStorageEnabled = true
                isVerticalScrollBarEnabled = true
                overScrollMode = WebView.OVER_SCROLL_IF_CONTENT_SCROLLS
                setOnTouchListener { view, event ->
                    when (event.actionMasked) {
                        MotionEvent.ACTION_DOWN -> {
                            downX = event.x
                            downY = event.y
                        }
                        MotionEvent.ACTION_UP -> {
                            val dx = kotlin.math.abs(event.x - downX)
                            val dy = kotlin.math.abs(event.y - downY)
                            if (dx < 12f && dy < 12f) {
                                val webView = view as? WebView
                                val hitType = webView?.hitTestResult?.type
                                val isLinkTap = hitType == WebView.HitTestResult.SRC_ANCHOR_TYPE ||
                                    hitType == WebView.HitTestResult.SRC_IMAGE_ANCHOR_TYPE
                                if (!isLinkTap) {
                                    onTap?.invoke()
                                    view.performClick()
                                }
                            }
                        }
                    }
                    if (event.action == MotionEvent.ACTION_DOWN || event.action == MotionEvent.ACTION_MOVE) {
                        view.parent?.requestDisallowInterceptTouchEvent(true)
                    }
                    false
                }
                webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, url: String?) {
                        super.onPageFinished(view, url)
                        view?.post {
                            view.requestLayout()
                            view.invalidate()
                        }
                    }
                }
                setOnScrollChangeListener { view, _, scrollY, _, _ ->
                    val webView = view as? WebView ?: return@setOnScrollChangeListener
                    val contentPx = (webView.contentHeight * webView.resources.displayMetrics.density).toInt()
                    val maxScroll = (contentPx - view.height).coerceAtLeast(1)
                    savedScrollRatio = (scrollY.toFloat() / maxScroll.toFloat()).coerceIn(0f, 1f)
                    onProgressChange(savedScrollRatio)
                }
                if (!webViewState.isEmpty) {
                    restoreState(webViewState)
                    post {
                        val contentPx = (contentHeight * resources.displayMetrics.density).toInt()
                        val maxScroll = (contentPx - height).coerceAtLeast(0)
                        val contextOffset = (24f * resources.displayMetrics.density).toInt()
                        val target = ((savedScrollRatio * maxScroll).toInt() - contextOffset).coerceAtLeast(0)
                        scrollTo(0, target)
                        onProgressChange(savedScrollRatio)
                    }
                }
            }
        },
        update = { webView ->
            val newHash = (content.kind.name + content.body + content.baseUrl).hashCode()
            if (loadedHash == null && !webViewState.isEmpty) {
                loadedHash = newHash
            }
            if (loadedHash != newHash) {
                if (!webViewState.isEmpty) {
                    webViewState.clear()
                }
                val renderedBody = when (content.kind) {
                    RulesheetRenderKind.MARKDOWN -> renderMarkdownHtml(content.body)
                    RulesheetRenderKind.HTML -> content.body
                }
                val html = buildRulesheetHtml(
                    renderedBody = renderedBody,
                    bodyColorHex = bodyColorHex,
                    mutedColorHex = mutedColorHex,
                    linkColorHex = linkColorHex,
                    linkSoftHex = linkSoftHex,
                    codeBgHex = codeBgHex,
                    panelHex = panelHex,
                    panelStrongHex = panelStrongHex,
                    tableBorderHex = tableBorderHex,
                    blockquoteBarHex = blockquoteBarHex,
                )
                webView.loadDataWithBaseURL(content.baseUrl, html, "text/html", "utf-8", null)
                loadedHash = newHash
                webView.post {
                    val contentPx = (webView.contentHeight * webView.resources.displayMetrics.density).toInt()
                    val maxScroll = (contentPx - webView.height).coerceAtLeast(0)
                    val contextOffset = (24f * webView.resources.displayMetrics.density).toInt()
                    val target = ((savedScrollRatio * maxScroll).toInt() - contextOffset).coerceAtLeast(0)
                    webView.scrollTo(0, target)
                    onProgressChange(savedScrollRatio)
                }
            }
            if (resumeTargetRatio != null && resumeRequestId != lastAppliedResumeRequestId) {
                val clamped = resumeTargetRatio.coerceIn(0f, 1f)
                savedScrollRatio = clamped
                webView.post {
                    val contentPx = (webView.contentHeight * webView.resources.displayMetrics.density).toInt()
                    val maxScroll = (contentPx - webView.height).coerceAtLeast(0)
                    val contextOffset = (24f * webView.resources.displayMetrics.density).toInt()
                    val target = ((clamped * maxScroll).toInt() - contextOffset).coerceAtLeast(0)
                    webView.scrollTo(0, target)
                    onProgressChange(clamped)
                }
                lastAppliedResumeRequestId = resumeRequestId
            }
        },
        onRelease = { webView ->
            val contentPx = (webView.contentHeight * webView.resources.displayMetrics.density).toInt()
            val maxScroll = (contentPx - webView.height).coerceAtLeast(1)
            savedScrollRatio = (webView.scrollY.toFloat() / maxScroll.toFloat()).coerceIn(0f, 1f)
            val out = Bundle()
            val backStack = webView.saveState(out)
            if (backStack != null && !out.isEmpty) {
                webViewState.clear()
                webViewState.putAll(out)
            }
        },
    )
}
