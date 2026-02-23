package com.pillyliu.pinballandroid.library

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.os.Bundle
import android.view.MotionEvent
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.content.edit
import androidx.core.graphics.get
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.graphics.ColorUtils
import coil.compose.AsyncImage
import coil.imageLoader
import coil.request.ImageRequest
import coil.size.Size
import com.halilibo.richtext.markdown.Markdown
import com.halilibo.richtext.ui.RichTextStyle
import com.halilibo.richtext.ui.material3.Material3RichText
import com.halilibo.richtext.ui.string.RichTextStringStyle
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.data.downloadTextAllowMissing
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.CardContainer
import com.pillyliu.pinballandroid.ui.iosEdgeSwipeBack
import com.pillyliu.pinballandroid.ui.LocalBottomBarVisible
import com.pillyliu.pinballandroid.ui.SectionTitle
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.material3.TextButton
import java.util.Locale
import kotlin.math.roundToInt

@Composable
internal fun LibraryDetailScreen(
    contentPadding: PaddingValues,
    game: PinballGame,
    onBack: () -> Unit,
    onOpenRulesheet: () -> Unit,
    onOpenPlayfield: (String) -> Unit,
) {
    val uriHandler = LocalUriHandler.current
    val context = LocalContext.current
    val detailScroll = rememberSaveable(game.slug, saver = androidx.compose.foundation.ScrollState.Saver) {
        androidx.compose.foundation.ScrollState(0)
    }
    var markdown by rememberSaveable(game.slug) { mutableStateOf<String?>(null) }
    var infoStatus by rememberSaveable(game.slug) { mutableStateOf("loading") }
    var activeVideoId by rememberSaveable(game.slug) {
        mutableStateOf<String?>(null)
    }
    val hasRulesheet = !game.rulesheetLocal.isNullOrBlank()

    LaunchedEffect(game.slug) {
        if (infoStatus == "loaded" || infoStatus == "missing") return@LaunchedEffect
        val candidates = listOfNotNull(
            game.resolve(game.gameinfoLocal),
            game.practiceIdentity?.let { "https://pillyliu.com/pinball/gameinfo/${it}-gameinfo.md" },
            "https://pillyliu.com/pinball/gameinfo/${game.slug}.md",
        ).distinct()
        var loaded = false
        var sawError = false
        for (candidate in candidates) {
            val (code, text) = downloadTextAllowMissing(candidate)
            when {
                code in 200..299 && !text.isNullOrBlank() -> {
                    markdown = text
                    infoStatus = "loaded"
                    loaded = true
                    break
                }
                code == 404 -> Unit
                else -> sawError = true
            }
        }
        if (!loaded) infoStatus = if (sawError) "error" else "missing"
    }

    AppScreen(
        contentPadding = contentPadding,
        modifier = Modifier.iosEdgeSwipeBack(enabled = true, onBack = onBack),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(detailScroll),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
            ) {
                GlassBackButton(
                    onClick = onBack,
                    modifier = Modifier.align(Alignment.CenterStart),
                )
                Text(
                    text = if (!game.variant.isNullOrBlank()) "${game.name} • ${game.variant}" else game.name,
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

            CardContainer {
                FallbackAsyncImage(
                    urls = game.gameInlinePlayfieldCandidates(),
                    contentDescription = game.name,
                    modifier = Modifier.fillMaxWidth().aspectRatio(16f / 9f),
                    contentScale = ContentScale.FillWidth,
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        game.name,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    game.variant?.takeIf { it.isNotBlank() }?.let { variant ->
                        Text(
                            text = variant,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier
                                .background(
                                    MaterialTheme.colorScheme.surfaceContainerHigh,
                                    shape = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
                                )
                                .border(
                                    width = 0.75.dp,
                                    color = MaterialTheme.colorScheme.outlineVariant,
                                    shape = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
                                )
                                .padding(horizontal = 10.dp, vertical = 5.dp),
                        )
                    }
                }
                Text(game.metaLine(), color = MaterialTheme.colorScheme.onSurfaceVariant)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = onOpenRulesheet, enabled = hasRulesheet) { Text("Rulesheet") }
                    game.fullscreenPlayfieldCandidates().firstOrNull()?.let { url ->
                        OutlinedButton(onClick = { onOpenPlayfield(url) }) { Text("Playfield") }
                    }
                }
            }

            CardContainer {
                SectionTitle("Videos")
                val playableVideos = game.videos.mapNotNull { v ->
                    youtubeId(v.url)?.let { id ->
                        val fallback = v.kind?.replaceFirstChar { c -> c.titlecase() } ?: "Video"
                        id to (v.label ?: fallback)
                    }
                }
                if (playableVideos.isEmpty()) {
                    Text("No videos listed.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    activeVideoId?.let { id ->
                        EmbeddedYouTubeView(
                            videoId = id,
                            modifier = Modifier.fillMaxWidth().aspectRatio(16f / 9f),
                        )
                    } ?: Text("Tap a video below to load player.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    BoxWithConstraints {
                        val tileWidth = (maxWidth - 10.dp) / 2
                        val rows = playableVideos.chunked(2)
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            rows.forEach { rowItems ->
                                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    rowItems.forEach { (id, label) ->
                                        VideoTile(
                                            videoId = id,
                                            label = label,
                                            selected = activeVideoId == id,
                                            width = tileWidth,
                                            onSelect = {
                                                activeVideoId = id
                                                LibraryActivityLog.log(context, game.slug, game.name, LibraryActivityKind.TapVideo, label)
                                            },
                                        )
                                    }
                                    if (rowItems.size == 1) {
                                        Spacer(Modifier.width(tileWidth))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            CardContainer {
                SectionTitle("Game Info")
                when (infoStatus) {
                    "loading" -> Text("Loading…", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    "missing" -> Text("No game info yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    "error" -> Text("Could not load game info.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    else -> CompositionLocalProvider(LocalContentColor provides MaterialTheme.colorScheme.onSurface) {
                        val linkColor = MaterialTheme.colorScheme.primary
                        val gameInfoStyle = remember {
                            RichTextStyle.Default.copy(
                                stringStyle = RichTextStringStyle.Default.copy(
                                    linkStyle = SpanStyle(color = linkColor),
                                ),
                            )
                        }
                        Material3RichText(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = 20.dp),
                            style = gameInfoStyle,
                        ) {
                            Markdown(markdown.orEmpty())
                        }
                    }
                }
            }

            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.horizontalScroll(rememberScrollState()),
            ) {
                game.rulesheetUrl?.let {
                    OutlinedButton(
                        onClick = { uriHandler.openUri(it) },
                        modifier = Modifier.defaultMinSize(minHeight = 32.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
                            contentColor = MaterialTheme.colorScheme.onSurface,
                        ),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                    ) {
                        Text("Rulesheet (source)", fontSize = 12.sp)
                    }
                }
                game.playfieldImageUrl?.let {
                    OutlinedButton(
                        onClick = { uriHandler.openUri(it) },
                        modifier = Modifier.defaultMinSize(minHeight = 32.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
                            contentColor = MaterialTheme.colorScheme.onSurface,
                        ),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                    ) {
                        Text("Playfield (source)", fontSize = 12.sp)
                    }
                }
            }
            if (game.rulesheetUrl.isNullOrBlank() && game.playfieldImageUrl.isNullOrBlank()) {
                Text(
                    "No sources available.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 12.sp,
                )
            }
            Spacer(Modifier.height(LIBRARY_CONTENT_BOTTOM_FILLER))
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun EmbeddedYouTubeView(videoId: String, modifier: Modifier = Modifier) {
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
                    override fun shouldOverrideUrlLoading(view: WebView?, request: android.webkit.WebResourceRequest?): Boolean = false
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
internal fun RulesheetScreen(
    contentPadding: PaddingValues,
    slug: String,
    remoteCandidates: List<String>? = null,
    onBack: () -> Unit,
    practiceSavedRatio: Float? = null,
    onSavePracticeRatio: ((Float) -> Unit)? = null,
) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("rulesheet-progress-v1", android.content.Context.MODE_PRIVATE) }
    var status by rememberSaveable(slug) { mutableStateOf("loading") }
    var markdown by rememberSaveable(slug) { mutableStateOf("") }
    var chromeVisible by rememberSaveable(slug) { mutableStateOf(false) }
    var progressRatio by rememberSaveable(slug) { mutableStateOf(0f) }
    var savedRatio by rememberSaveable(slug) { mutableStateOf(0f) }
    var showResumePrompt by rememberSaveable(slug) { mutableStateOf(false) }
    var evaluatedResumePrompt by rememberSaveable(slug) { mutableStateOf(false) }
    var resumeTargetRatio by rememberSaveable(slug) { mutableStateOf<Float?>(null) }
    var resumeRequestId by rememberSaveable(slug) { mutableIntStateOf(0) }

    LaunchedEffect(slug, practiceSavedRatio) {
        val key = "rulesheet-last-progress-$slug"
        val stored = prefs.getFloat(key, 0f).coerceIn(0f, 1f)
        savedRatio = (practiceSavedRatio ?: stored).coerceIn(0f, 1f)
    }

    LaunchedEffect(slug) {
        if (status == "loaded" || status == "missing") return@LaunchedEffect
        val urls = (remoteCandidates?.filter { it.isNotBlank() } ?: emptyList())
            .ifEmpty { listOf("https://pillyliu.com/pinball/rulesheets/$slug.md") }
        var saw404 = false
        for (url in urls) {
            val (code, text) = downloadTextAllowMissing(url)
            when {
                code == 404 -> {
                    saw404 = true
                }
                code in 200..299 && !text.isNullOrBlank() -> {
                    status = "loaded"
                    markdown = normalizeRulesheet(text) + RULESHEET_BOTTOM_MARKDOWN_FILLER
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
                else -> MarkdownWebView(
                    markdown,
                    Modifier.fillMaxSize(),
                    stateKey = "rulesheet-$slug",
                    resumeRequestId = resumeRequestId,
                    resumeTargetRatio = resumeTargetRatio,
                    onTap = { chromeVisible = !chromeVisible },
                    onProgressChange = { progressRatio = it },
                )
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
                        .then(
                            if (needsSave) Modifier else Modifier
                        )
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
                Row(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(top = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    GlassBackButton(onClick = onBack)
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

@Composable
internal fun PlayfieldScreen(contentPadding: PaddingValues, title: String, imageUrls: List<String>, onBack: () -> Unit) {
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
private fun GlassBackButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    FilledTonalIconButton(
        onClick = onClick,
        modifier = modifier.size(40.dp),
        colors = androidx.compose.material3.IconButtonDefaults.filledTonalIconButtonColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = 0.92f),
            contentColor = MaterialTheme.colorScheme.onSurface,
        ),
    ) {
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = "Back",
            modifier = Modifier.size(18.dp),
        )
    }
}

@Composable
private fun ZoomablePlayfieldImage(
    imageUrls: List<String>,
    title: String,
    modifier: Modifier = Modifier,
    onTap: () -> Unit = {},
) {
    val context = LocalContext.current
    val candidates = imageUrls.filter { it.isNotBlank() }.distinct()
    var activeImageIndex by remember(candidates) { mutableStateOf(0) }
    var scale by remember { mutableStateOf(1f) }
    var offsetX by remember { mutableStateOf(0f) }
    var offsetY by remember { mutableStateOf(0f) }
    val touchSlop = LocalViewConfiguration.current.touchSlop

    Box(
        modifier = modifier
            .clipToBounds()
            .pointerInput(touchSlop) {
                awaitEachGesture {
                    var moved = false
                    var multiTouch = false
                    var transformed = false
                    var activePointer: androidx.compose.ui.input.pointer.PointerId? = null
                    var accumulatedMove = Offset.Zero

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
                            accumulatedMove += tracked.position - tracked.previousPosition
                            if (accumulatedMove.getDistance() > touchSlop) moved = true
                        }

                        if (pointersDown >= 2 || scale > 1f) {
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
                        onTap()
                    }
                }
            },
    ) {
        val activeUrl = candidates.getOrNull(activeImageIndex)
        val cachedModel = rememberCachedImageModel(activeUrl)
        AsyncImage(
            model = cachedModel?.let { model ->
                ImageRequest.Builder(context)
                    .data(model)
                    .size(Size.ORIGINAL)
                    .build()
            },
            contentDescription = title,
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                    translationX = offsetX
                    translationY = offsetY
                },
            contentScale = ContentScale.Fit,
            onError = {
                if (activeImageIndex < candidates.lastIndex) {
                    activeImageIndex += 1
                }
            },
        )
    }
}

@Composable
private fun FallbackAsyncImage(
    urls: List<String>,
    contentDescription: String,
    modifier: Modifier,
    contentScale: ContentScale,
) {
    val candidates = urls.filter { it.isNotBlank() }.distinct()
    var activeIndex by remember(candidates) { mutableStateOf(0) }
    val model = rememberCachedImageModel(candidates.getOrNull(activeIndex))
    AsyncImage(
        model = model,
        contentDescription = contentDescription,
        modifier = modifier,
        contentScale = contentScale,
        onError = {
            if (activeIndex < candidates.lastIndex) {
                activeIndex += 1
            }
        },
    )
}

@Composable
private fun rememberCachedImageModel(url: String?): Any? {
    if (url.isNullOrBlank()) return null
    val model by produceState<Any?>(initialValue = url, key1 = url) {
        value = try {
            PinballDataCache.resolveImageModel(url)
        } catch (_: Throwable) {
            url
        }
    }
    return model
}

@Composable
private fun VideoTile(
    videoId: String,
    label: String,
    selected: Boolean,
    width: androidx.compose.ui.unit.Dp,
    onSelect: () -> Unit,
) {
    Column(
        modifier = Modifier
            .width(width)
            .clickable(onClick = onSelect)
            .background(if (selected) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceContainerLow, RoundedCornerShape(8.dp))
            .border(1.dp, if (selected) MaterialTheme.colorScheme.outline else MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(8.dp))
            .padding(8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        AsyncImage(
            model = "https://i.ytimg.com/vi/$videoId/hqdefault.jpg",
            contentDescription = label,
            modifier = Modifier.fillMaxWidth().aspectRatio(16f / 9f),
            contentScale = ContentScale.Crop,
        )
        Text(label, color = MaterialTheme.colorScheme.onSurface, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun MarkdownWebView(
    markdown: String,
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
    var savedScrollRatio by rememberSaveable(stateKey) { mutableStateOf(0f) }
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
            val newHash = markdown.hashCode()
            if (loadedHash == null && !webViewState.isEmpty) {
                loadedHash = newHash
            }
            if (loadedHash != newHash) {
                if (!webViewState.isEmpty) {
                    webViewState.clear()
                }
                val renderedHtml = renderMarkdownHtml(markdown)
                val html = """
                    <!doctype html>
                    <html>
                    <head>
                        <meta charset=\"utf-8\" />
                        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
                        <style>
                            html, body { margin:0; padding:0; background:transparent !important; color:$bodyColorHex !important; overflow-x:hidden !important; width:100%; }
                            body { padding:14px 16px; line-height:1.45; font-size:17px; box-sizing:border-box; }
                            *, *:before, *:after { box-sizing:border-box; }
                            * { color:$bodyColorHex !important; background: transparent !important; }
                            p, li, dd, dt { color:$bodyColorHex !important; }
                            blockquote { color:$mutedColorHex !important; border-left:3px solid $tableBorderHex !important; padding-left:10px; }
                            a { color:$linkColorHex !important; text-decoration:underline !important; text-underline-offset:2px; font-weight:600; }
                            code, pre { background:$codeBgHex !important; border-radius:6px !important; color:$bodyColorHex !important; }
                            pre { padding:10px; white-space:pre-wrap; overflow-wrap:anywhere; word-break:break-word; }
                            table { border-collapse:collapse; width:100%; max-width:100%; table-layout:fixed; }
                            th, td { border:1px solid $tableBorderHex; padding:6px 8px; word-break:break-word; overflow-wrap:anywhere; }
                            img { max-width:100%; height:auto; display:block; }
                            .rulesheet-attribution {
                                display:block;
                                font-size:0.78rem;
                                line-height:1.35;
                                opacity:0.78;
                                margin-bottom:0.8rem;
                            }
                        </style>
                    </head>
                    <body>
                        <article id=\"content\">$renderedHtml</article>
                    </body>
                    </html>
                """.trimIndent()
                webView.loadDataWithBaseURL("https://pillyliu.com", html, "text/html", "utf-8", null)
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
