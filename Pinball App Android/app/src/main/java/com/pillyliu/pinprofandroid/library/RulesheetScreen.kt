package com.pillyliu.pinprofandroid.library

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
import androidx.compose.ui.graphics.Brush
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
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.ui.AppFullscreenStatusOverlay
import com.pillyliu.pinprofandroid.ui.AppReadingProgressPill
import com.pillyliu.pinprofandroid.ui.AppRouteScreen
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.AppTextAction
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
    gameId: String,
    title: String? = null,
    pathCandidates: List<String>? = null,
    externalSource: RulesheetRemoteSource? = null,
    onBack: () -> Unit,
    practiceSavedRatio: Float? = null,
    onSavePracticeRatio: ((Float) -> Unit)? = null,
) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("rulesheet-progress-v1", android.content.Context.MODE_PRIVATE) }
    var status by rememberSaveable(gameId) { mutableStateOf("loading") }
    var content by rememberSaveable(gameId) { mutableStateOf<RulesheetRenderContent?>(null) }
    var chromeVisible by rememberSaveable(gameId) { mutableStateOf(false) }
    var progressRatio by rememberSaveable(gameId) { mutableFloatStateOf(0f) }
    var savedRatio by rememberSaveable(gameId) { mutableFloatStateOf(0f) }
    var showResumePrompt by rememberSaveable(gameId) { mutableStateOf(false) }
    var evaluatedResumePrompt by rememberSaveable(gameId) { mutableStateOf(false) }
    var resumeTargetRatio by rememberSaveable(gameId) { mutableStateOf<Float?>(null) }
    var resumeRequestId by rememberSaveable(gameId) { mutableIntStateOf(0) }

    androidx.compose.runtime.LaunchedEffect(gameId, practiceSavedRatio) {
        val key = "rulesheet-last-progress-$gameId"
        val stored = prefs.getFloat(key, 0f).coerceIn(0f, 1f)
        savedRatio = (practiceSavedRatio ?: stored).coerceIn(0f, 1f)
    }

    androidx.compose.runtime.LaunchedEffect(gameId, externalSource?.url) {
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
        val candidates = (pathCandidates?.filter { it.isNotBlank() } ?: emptyList())
            .ifEmpty { listOf("/pinball/rulesheets/$gameId.md") }
        var sawMissing = false
        for (candidate in candidates) {
            val cached = PinballDataCache.loadText(candidate, allowMissing = true)
            if (cached.isMissing) {
                sawMissing = true
                continue
            }
            val text = cached.text
            if (!text.isNullOrBlank()) {
                content = RulesheetRenderContent(
                    kind = RulesheetRenderKind.MARKDOWN,
                    body = normalizeRulesheet(text) + RULESHEET_BOTTOM_MARKDOWN_FILLER,
                    baseUrl = "https://pillyliu.com",
                )
                status = "loaded"
                return@LaunchedEffect
            }
        }
        status = if (sawMissing) "missing" else "error"
    }

    AppRouteScreen(
        contentPadding = contentPadding,
        canGoBack = true,
        onBack = onBack,
        horizontalPadding = 8.dp,
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
        ) {
            when (status) {
                "loading" -> AppFullscreenStatusOverlay(text = "Loading rulesheet…", showsProgress = true)
                "missing" -> AppFullscreenStatusOverlay(text = "Rulesheet not available.")
                "error" -> AppFullscreenStatusOverlay(text = "Could not load rulesheet.")
                else -> content?.let {
                    RulesheetContentWebView(
                        content = it,
                        modifier = Modifier.fillMaxSize(),
                        stateKey = "rulesheet-$gameId-${externalSource?.url.orEmpty()}",
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
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = 12.dp, end = 12.dp)
                        .clickable {
                            val clamped = progressRatio.coerceIn(0f, 1f)
                            savedRatio = clamped
                            prefs.edit { putFloat("rulesheet-last-progress-$gameId", clamped) }
                            onSavePracticeRatio?.invoke(clamped)
                        },
                ) {
                    AppReadingProgressPill(
                        text = percentText,
                        saved = !needsSave && savedRatio > 0f,
                        alpha = if (needsSave) pulseAlpha else 1f,
                    )
                }
            }
            if (chromeVisible) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 14.dp, end = 14.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.Center)
                            .fillMaxWidth()
                            .background(
                                Brush.verticalGradient(
                                    colors = listOf(
                                        Color.Black.copy(alpha = 0.52f),
                                        Color.Black.copy(alpha = 0.22f),
                                        Color.Transparent,
                                    ),
                                ),
                                RoundedCornerShape(16.dp),
                            )
                            .border(
                                1.dp,
                                MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.28f),
                                RoundedCornerShape(16.dp),
                            )
                            .padding(horizontal = 6.dp, vertical = 4.dp),
                    ) {
                        AppScreenHeader(
                            title = title ?: gameId.replace('-', ' ').replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.US) else it.toString() },
                            onBack = onBack,
                            titleColor = Color.White,
                        )
                    }
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
                AppTextAction(text = "Yes", onClick = {
                    resumeTargetRatio = savedRatio
                    resumeRequestId += 1
                    showResumePrompt = false
                })
            },
            dismissButton = {
                AppTextAction(text = "No", onClick = { showResumePrompt = false })
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

private fun buildRulesheetHtml(
    renderedBody: String,
    bodyColorHex: String,
    mutedColorHex: String,
    linkColorHex: String,
    linkSoftHex: String,
    codeBgHex: String,
    panelHex: String,
    panelStrongHex: String,
    tableBorderHex: String,
    blockquoteBarHex: String,
): String {
    return """
        <!doctype html>
        <html>
        <head>
            <meta charset=\"utf-8\" />
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
            <style>
                :root {
                    --text: $bodyColorHex;
                    --text-muted: $mutedColorHex;
                    --link: $linkColorHex;
                    --link-soft: $linkSoftHex;
                    --panel: $panelHex;
                    --panel-strong: $panelStrongHex;
                    --code-bg: $codeBgHex;
                    --code-text: $bodyColorHex;
                    --rule: $tableBorderHex;
                    --table-border: $tableBorderHex;
                    --blockquote-bar: $blockquoteBarHex;
                }
                html, body {
                    margin: 0;
                    padding: 0;
                    background: transparent;
                }
                body {
                    padding: 76px 16px 28px;
                    font-family: sans-serif;
                    -webkit-text-size-adjust: 100%;
                    text-size-adjust: 100%;
                    color: var(--text);
                    line-height: 1.5;
                    font-size: 16px;
                    box-sizing: border-box;
                }
                *, *:before, *:after {
                    box-sizing: border-box;
                }
                #content {
                    margin: 0 auto;
                    max-width: 44rem;
                    overflow-x: hidden;
                    overflow-wrap: anywhere;
                    word-break: normal;
                }
                #content > :first-child { margin-top: 0 !important; }
                #content > :last-child { margin-bottom: 0 !important; }
                p, ul, ol, blockquote, pre, table, hr {
                    margin: 0 0 0.95rem;
                }
                p, li, dd, dt, small, div, span {
                    max-width: 100%;
                    overflow-wrap: anywhere;
                    word-wrap: break-word;
                    word-break: break-word;
                    white-space: normal;
                }
                a {
                    color: var(--link);
                    text-decoration: underline;
                    text-decoration-thickness: 0.08em;
                    text-underline-offset: 0.14em;
                    overflow-wrap: anywhere;
                    word-break: break-word;
                }
                a:hover {
                    background: var(--link-soft);
                }
                h1, h2, h3, h4, h5, h6 {
                    color: var(--text);
                    line-height: 1.2;
                    margin: 1.35rem 0 0.55rem;
                }
                h1 { font-size: 1.8rem; letter-spacing: -0.02em; }
                h2 {
                    font-size: 1.35rem;
                    letter-spacing: -0.015em;
                    padding-bottom: 0.2rem;
                    border-bottom: 1px solid var(--rule);
                }
                h3 { font-size: 1.08rem; }
                h4, h5, h6 { font-size: 0.98rem; }
                strong { color: var(--text); }
                small, .bodySmall, .rulesheet-attribution {
                    color: var(--text-muted);
                }
                ul, ol {
                    padding-left: 1.35rem;
                }
                li {
                    margin: 0.18rem 0;
                }
                li > ul, li > ol {
                    margin-top: 0.28rem;
                    margin-bottom: 0.28rem;
                }
                blockquote {
                    margin-left: 0;
                    padding: 0.15rem 0 0.15rem 0.95rem;
                    border-left: 3px solid var(--blockquote-bar);
                    color: var(--text-muted);
                    background: transparent;
                }
                code, pre {
                    background: var(--code-bg);
                    border-radius: 10px;
                    color: var(--code-text);
                }
                code {
                    padding: 0.12rem 0.34rem;
                    overflow-wrap: anywhere;
                    word-break: break-word;
                }
                pre {
                    padding: 12px 14px;
                    overflow-x: auto;
                    border: 1px solid var(--rule);
                }
                pre code {
                    padding: 0;
                    background: transparent;
                    border-radius: 0;
                }
                .table-scroll {
                    overflow-x: auto;
                    overflow-y: visible;
                    -webkit-overflow-scrolling: touch;
                    margin: 0 0 1rem;
                    padding-bottom: 0.1rem;
                    border: 1px solid var(--table-border);
                    border-radius: 12px;
                    background: var(--panel);
                }
                table {
                    border-collapse: separate;
                    border-spacing: 0;
                    width: 100%;
                    table-layout: auto;
                    margin-bottom: 0;
                }
                th, td {
                    border-right: 1px solid var(--table-border);
                    border-bottom: 1px solid var(--table-border);
                    padding: 8px 10px;
                    vertical-align: top;
                    word-break: normal;
                    overflow-wrap: normal;
                    white-space: normal;
                }
                tr > :last-child {
                    border-right: none;
                }
                tbody tr:last-child td,
                table tr:last-child td {
                    border-bottom: none;
                }
                th {
                    background: var(--panel-strong);
                    text-align: left;
                }
                thead tr:first-child th:first-child,
                table tr:first-child > *:first-child {
                    border-top-left-radius: 12px;
                }
                thead tr:first-child th:last-child,
                table tr:first-child > *:last-child {
                    border-top-right-radius: 12px;
                }
                tbody tr:last-child td:first-child,
                table tr:last-child td:first-child {
                    border-bottom-left-radius: 12px;
                }
                tbody tr:last-child td:last-child,
                table tr:last-child td:last-child {
                    border-bottom-right-radius: 12px;
                }
                .primer-rulesheet table td:first-child,
                .primer-rulesheet table th:first-child {
                    width: 34%;
                    min-width: 7.5rem;
                }
                .primer-rulesheet table td:last-child,
                .primer-rulesheet table th:last-child {
                    width: 66%;
                }
                img {
                    display: block;
                    max-width: 100%;
                    height: auto;
                    margin: 0.5rem auto;
                    border-radius: 10px;
                }
                table img,
                .table-scroll img {
                    width: auto;
                    max-height: min(42vh, 24rem);
                    object-fit: contain;
                }
                hr {
                    border: none;
                    border-top: 1px solid var(--rule);
                }
                .pinball-rulesheet, .remote-rulesheet {
                    display: block;
                }
                .legacy-rulesheet .bodyTitle {
                    display: block;
                    font-size: 1.08rem;
                    font-weight: 700;
                    margin: 1rem 0 0.4rem;
                }
                .legacy-rulesheet .bodySmall {
                    display: block;
                    font-size: 0.92rem;
                    opacity: 0.88;
                }
                .legacy-rulesheet pre.rulesheet-preformatted {
                    white-space: pre-wrap;
                    font: inherit;
                    background: transparent;
                    padding: 0;
                    border-radius: 0;
                    border: none;
                }
                .rulesheet-attribution {
                    display: block;
                    font-size: 0.78rem;
                    line-height: 1.35;
                    opacity: 0.92;
                    margin-bottom: 0.8rem;
                }
                .rulesheet-attribution, .rulesheet-attribution * {
                    overflow-wrap: anywhere;
                    word-break: break-word;
                }
                @media (orientation: landscape) {
                    body {
                        padding-top: 19px;
                    }
                }
                @media (min-width: 820px) {
                    body {
                        padding-left: 24px;
                        padding-right: 24px;
                    }
                }
            </style>
        </head>
        <body>
            <article id=\"content\">$renderedBody</article>
            <script>
                document.querySelectorAll('table').forEach((table) => {
                    if (table.parentElement && table.parentElement.classList.contains('table-scroll')) return;
                    const wrapper = document.createElement('div');
                    wrapper.className = 'table-scroll';
                    table.parentNode.insertBefore(wrapper, table);
                    wrapper.appendChild(table);
                });
            </script>
        </body>
        </html>
    """.trimIndent()
}

private fun Color.toCssHex(): String {
    val argb = toArgb()
    val red = (argb shr 16) and 0xFF
    val green = (argb shr 8) and 0xFF
    val blue = argb and 0xFF
    return String.format(Locale.US, "#%02X%02X%02X", red, green, blue)
}
