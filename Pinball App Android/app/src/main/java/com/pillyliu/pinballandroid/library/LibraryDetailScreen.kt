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
import androidx.compose.foundation.Image
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
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
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
import com.halilibo.richtext.ui.material3.RichText
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
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.tween
import androidx.compose.material3.TextButton
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.max
import kotlin.math.roundToInt

@Composable
internal fun LibraryDetailScreen(
    contentPadding: PaddingValues,
    game: PinballGame,
    onBack: () -> Unit,
    onOpenRulesheet: (RulesheetRemoteSource?) -> Unit,
    onOpenExternalRulesheet: (String) -> Unit,
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
    val hasRulesheet = game.hasRulesheetResource

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
                    text = if (game.normalizedVariant != null) "${game.name} • ${game.normalizedVariant}" else game.name,
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

            LibraryDetailScreenshotSection(game = game)

            LibraryDetailSummaryCard(
                game = game,
                hasRulesheet = hasRulesheet,
                onOpenRulesheet = onOpenRulesheet,
                onOpenExternalRulesheet = onOpenExternalRulesheet,
                onOpenPlayfield = onOpenPlayfield,
            )

            LibraryDetailVideosCard(
                game = game,
                activeVideoId = activeVideoId,
                onActiveVideoIdChange = { activeVideoId = it },
            )

            LibraryDetailGameInfoCard(
                infoStatus = infoStatus,
                markdown = markdown,
            )

            LibraryDetailSourcesSection(
                game = game,
                hasRulesheet = hasRulesheet,
                onOpenRulesheet = onOpenRulesheet,
                onOpenExternalRulesheet = onOpenExternalRulesheet,
                onOpenPlayfield = onOpenPlayfield,
            )
            if (!game.hasRulesheetResource && !game.hasPlayfieldResource) {
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

@Composable
internal fun GlassBackButton(
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
private fun FallbackAsyncImage(
    urls: List<String>,
    contentDescription: String,
    modifier: Modifier,
    contentScale: ContentScale,
) {
    val candidates = urls.filter { it.isNotBlank() }.distinct()
    var activeIndex by remember(candidates) { mutableIntStateOf(0) }
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
internal fun VideoTile(
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
