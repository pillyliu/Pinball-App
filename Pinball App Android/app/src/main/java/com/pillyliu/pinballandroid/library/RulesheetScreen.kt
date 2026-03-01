package com.pillyliu.pinballandroid.library

import android.annotation.SuppressLint
import android.os.Bundle
import android.view.MotionEvent
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.content.edit
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.pillyliu.pinballandroid.data.downloadTextAllowMissing
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.iosEdgeSwipeBack
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.Locale
import kotlin.math.roundToInt

@SuppressLint("SetJavaScriptEnabled")
@Composable
internal fun ExternalRulesheetWebScreen(
    contentPadding: PaddingValues,
    title: String,
    url: String,
    onBack: () -> Unit,
) {
    AppScreen(
        contentPadding = contentPadding,
        modifier = Modifier.iosEdgeSwipeBack(enabled = true, onBack = onBack),
    ) {
        Column(modifier = Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
            ) {
                GlassBackButton(onClick = onBack, modifier = Modifier.align(Alignment.CenterStart))
                Text(
                    text = title,
                    color = MaterialTheme.colorScheme.onSurface,
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
            ExternalRulesheetWebView(
                url = url,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun ExternalRulesheetWebView(url: String, modifier: Modifier = Modifier) {
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

@Composable
internal fun RulesheetScreen(
    contentPadding: PaddingValues,
    slug: String,
    remoteCandidates: List<String>? = null,
    externalSource: RulesheetRemoteSource? = null,
    onBack: () -> Unit,
    practiceSavedRatio: Float? = null,
    onSavePracticeRatio: ((Float) -> Unit)? = null,
) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("rulesheet-progress-v1", android.content.Context.MODE_PRIVATE) }
    var status by rememberSaveable(slug) { mutableStateOf("loading") }
    var content by rememberSaveable(slug) { mutableStateOf<RulesheetRenderContent?>(null) }
    var chromeVisible by rememberSaveable(slug) { mutableStateOf(false) }
    var progressRatio by rememberSaveable(slug) { mutableFloatStateOf(0f) }
    var savedRatio by rememberSaveable(slug) { mutableFloatStateOf(0f) }
    var showResumePrompt by rememberSaveable(slug) { mutableStateOf(false) }
    var evaluatedResumePrompt by rememberSaveable(slug) { mutableStateOf(false) }
    var resumeTargetRatio by rememberSaveable(slug) { mutableStateOf<Float?>(null) }
    var resumeRequestId by rememberSaveable(slug) { mutableIntStateOf(0) }

    androidx.compose.runtime.LaunchedEffect(slug, practiceSavedRatio) {
        val key = "rulesheet-last-progress-$slug"
        val stored = prefs.getFloat(key, 0f).coerceIn(0f, 1f)
        savedRatio = (practiceSavedRatio ?: stored).coerceIn(0f, 1f)
    }

    androidx.compose.runtime.LaunchedEffect(slug, externalSource?.url) {
        if (status == "loaded" || status == "missing") return@LaunchedEffect
        externalSource?.let { source ->
            runCatching { withContext(Dispatchers.IO) { RemoteRulesheetLoader.load(source) } }
                .onSuccess {
                    content = it
                    status = "loaded"
                }
                .onFailure {
                    status = "error"
                }
            return@LaunchedEffect
        }
        val urls = (remoteCandidates?.filter { it.isNotBlank() } ?: emptyList())
            .ifEmpty { listOf("https://pillyliu.com/pinball/rulesheets/$slug.md") }
        var saw404 = false
        for (url in urls) {
            val (code, text) = downloadTextAllowMissing(url)
            when {
                code == 404 -> saw404 = true
                code in 200..299 && !text.isNullOrBlank() -> {
                    content = RulesheetRenderContent(
                        kind = RulesheetRenderKind.MARKDOWN,
                        body = normalizeRulesheet(text) + RULESHEET_BOTTOM_MARKDOWN_FILLER,
                        baseUrl = "https://pillyliu.com",
                    )
                    status = "loaded"
                    return@LaunchedEffect
                }
            }
        }
        status = if (saw404) "missing" else "error"
    }

    AppScreen(contentPadding, horizontalPadding = 8.dp) {
        Box(
            modifier = Modifier.fillMaxSize(),
        ) {
            when (status) {
                "loading" -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("Loading rulesheet...", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                "missing" -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("Rulesheet not available.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                "error" -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("Could not load rulesheet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                else -> content?.let {
                    RulesheetContentWebView(
                        content = it,
                        modifier = Modifier.fillMaxSize(),
                        stateKey = "rulesheet-$slug-${externalSource?.url.orEmpty()}",
                        resumeRequestId = resumeRequestId,
                        resumeTargetRatio = resumeTargetRatio,
                        onTap = { chromeVisible = !chromeVisible },
                        onProgressChange = { progressRatio = it },
                    )
                }
            }
            if (status == "loaded" && !evaluatedResumePrompt) {
                evaluatedResumePrompt = true
                if (savedRatio > 0.001f) {
                    showResumePrompt = true
                }
            }
            if (status == "loaded") {
                val percentText = "${(progressRatio.coerceIn(0f, 1f) * 100f).roundToInt()}%"
                val savedPercent = (savedRatio.coerceIn(0f, 1f) * 100f).roundToInt()
                val needsSave = savedPercent != (progressRatio.coerceIn(0f, 1f) * 100f).roundToInt()
                val pulse = rememberInfiniteTransition(label = "rulesheetPercentPulse")
                val pulseAlpha by pulse.animateFloat(
                    initialValue = 1f,
                    targetValue = 0.5f,
                    animationSpec = infiniteRepeatable(
                        animation = tween(durationMillis = 1050),
                        repeatMode = RepeatMode.Reverse,
                    ),
                    label = "pulseAlpha",
                )
                Text(
                    text = percentText,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = 12.dp, end = 12.dp)
                        .clickable {
                            val clamped = progressRatio.coerceIn(0f, 1f)
                            savedRatio = clamped
                            prefs.edit { putFloat("rulesheet-last-progress-$slug", clamped) }
                            onSavePracticeRatio?.invoke(clamped)
                        }
                        .background(
                            if (needsSave) {
                                MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = 0.76f)
                            } else {
                                MaterialTheme.colorScheme.tertiary.copy(alpha = 0.84f)
                            },
                            RoundedCornerShape(999.dp),
                        )
                        .border(
                            width = 0.5.dp,
                            color = if (needsSave) {
                                MaterialTheme.colorScheme.outline.copy(alpha = 0.45f)
                            } else {
                                MaterialTheme.colorScheme.tertiary.copy(alpha = 0.9f)
                            },
                            shape = RoundedCornerShape(999.dp),
                        )
                        .graphicsLayer {
                            alpha = if (needsSave) pulseAlpha else 1f
                        }
                        .padding(horizontal = 9.dp, vertical = 4.dp),
                )
            }
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
                        text = slug.replace('-', ' ').replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.US) else it.toString() },
                        color = MaterialTheme.colorScheme.onSurface,
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
    if (showResumePrompt) {
        AlertDialog(
            onDismissRequest = { showResumePrompt = false },
            title = { Text("Return to last saved position?") },
            text = { Text("Return to ${(savedRatio * 100f).roundToInt()}%?") },
            confirmButton = {
                TextButton(onClick = {
                    resumeTargetRatio = savedRatio
                    resumeRequestId += 1
                    showResumePrompt = false
                }) { Text("Yes") }
            },
            dismissButton = {
                TextButton(onClick = { showResumePrompt = false }) { Text("No") }
            },
        )
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun RulesheetContentWebView(
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
    val codeBgHex = MaterialTheme.colorScheme.surfaceContainerLowest.toCssHex()
    val tableBorderHex = MaterialTheme.colorScheme.outlineVariant.toCssHex()
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
                val html = """
                    <!doctype html>
                    <html>
                    <head>
                        <meta charset=\"utf-8\" />
                        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
                        <style>
                            html, body { margin:0; padding:0; background:transparent !important; color:$bodyColorHex !important; overflow-x:hidden !important; width:100%; }
                            body { padding:14px 16px; line-height:1.45; font-size:16px; box-sizing:border-box; }
                            *, *:before, *:after { box-sizing:border-box; }
                            * { color:$bodyColorHex !important; background: transparent !important; }
                            #content { max-width:100%; overflow-x:hidden !important; overflow-wrap:anywhere !important; word-break:break-word !important; word-wrap:break-word !important; }
                            p, li, dd, dt, small, div, span { color:$bodyColorHex !important; max-width:100% !important; overflow-wrap:anywhere !important; word-wrap:break-word !important; word-break:break-word !important; white-space:normal !important; }
                            blockquote { color:$mutedColorHex !important; border-left:3px solid $tableBorderHex !important; padding-left:10px; }
                            a { color:$linkColorHex !important; text-decoration:underline !important; text-underline-offset:2px; font-weight:600; max-width:100% !important; white-space:normal !important; overflow-wrap:anywhere !important; word-wrap:break-word !important; word-break:break-all !important; }
                            code, pre { background:$codeBgHex !important; border-radius:6px !important; color:$bodyColorHex !important; }
                            code { overflow-wrap:anywhere; word-break:break-all; white-space:pre-wrap; }
                            pre { padding:10px; max-width:100%; overflow-x:hidden; white-space:pre-wrap; overflow-wrap:anywhere; word-break:break-all; }
                            pre code { white-space:pre-wrap !important; overflow-wrap:anywhere !important; word-break:break-all !important; }
                            .legacy-rulesheet .bodyTitle { display:block; font-size:1.1rem; font-weight:700; margin:1rem 0 0.4rem; }
                            .legacy-rulesheet .bodySmall { display:block; font-size:0.92rem; opacity:0.88; }
                            .legacy-rulesheet pre.rulesheet-preformatted { white-space:pre-wrap; font-size:0.92rem; line-height:1.4; background:transparent !important; padding:0; border-radius:0 !important; }
                            table { border-collapse:collapse; width:100%; max-width:100%; table-layout:fixed; }
                            th, td { border:1px solid $tableBorderHex; padding:6px 8px; word-break:break-word; overflow-wrap:anywhere; }
                            img { max-width:100%; height:auto; display:block; }
                            .rulesheet-attribution { display:block; font-size:0.78rem; line-height:1.35; opacity:0.78; margin-bottom:0.8rem; }
                            .rulesheet-attribution, .rulesheet-attribution * { overflow-wrap:anywhere; word-break:break-word; }
                        </style>
                    </head>
                    <body>
                        <article id=\"content\">$renderedBody</article>
                    </body>
                    </html>
                """.trimIndent()
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

private fun Color.toCssHex(): String {
    val argb = toArgb()
    val red = (argb shr 16) and 0xFF
    val green = (argb shr 8) and 0xFF
    val blue = argb and 0xFF
    return String.format(Locale.US, "#%02X%02X%02X", red, green, blue)
}
