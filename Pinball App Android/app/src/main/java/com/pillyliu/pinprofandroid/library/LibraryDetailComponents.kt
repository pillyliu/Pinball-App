package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.halilibo.richtext.markdown.Markdown
import com.halilibo.richtext.ui.RichTextStyle
import com.halilibo.richtext.ui.material3.RichText
import com.halilibo.richtext.ui.string.RichTextStringStyle
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppCardTitle
import com.pillyliu.pinprofandroid.ui.AppOverlaySubtitle
import com.pillyliu.pinprofandroid.ui.AppOverlayTitle
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppResourceChip
import com.pillyliu.pinprofandroid.ui.AppResourceRow
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.AppUnavailableResourceChip
import com.pillyliu.pinprofandroid.ui.AppVariantBadge
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle
import com.pillyliu.pinprofandroid.ui.appShortRulesheetTitle

@Composable
internal fun LibraryDetailScreenshotSection(game: PinballGame) {
    ConstrainedAsyncImagePreview(
        urls = game.detailArtworkCandidates(),
        contentDescription = game.name,
        emptyMessage = "No image",
    )
}

@Composable
internal fun LibraryDetailSummaryCard(
    game: PinballGame,
    hasRulesheet: Boolean,
    onOpenRulesheet: (RulesheetRemoteSource?) -> Unit,
    onOpenExternalRulesheet: (String) -> Unit,
    onOpenPlayfield: (String) -> Unit,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    CardContainer {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            AppCardTitle(
                text = game.name,
                maxLines = 2,
                modifier = Modifier.weight(1f),
            )
            game.normalizedVariant?.let { variant ->
                AppVariantBadge(variant)
            }
        }
        Text(game.metaLine(), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Column(
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            AppResourceRow(label = "Rulesheet:") {
                if (game.rulesheetLinks.isEmpty()) {
                    if (hasRulesheet) {
                        AppResourceChip(label = "Local") { onOpenRulesheet(null) }
                    } else {
                        AppUnavailableResourceChip()
                    }
                } else {
                    game.rulesheetLinks.forEach { link ->
                        val destination = link.destinationUrl
                        val embedded = link.embeddedRulesheetSource
                        AppResourceChip(label = appShortRulesheetTitle(link)) {
                            LibraryActivityLog.log(context, game.slug, game.name, LibraryActivityKind.OpenRulesheet, link.label)
                            when {
                                embedded != null -> onOpenRulesheet(embedded)
                                destination != null -> onOpenExternalRulesheet(destination)
                                else -> onOpenRulesheet(null)
                            }
                        }
                    }
                }
            }
            AppResourceRow(label = "Playfield:") {
                val playfieldCandidates = game.actualFullscreenPlayfieldCandidates
                if (playfieldCandidates.isNotEmpty()) {
                    AppResourceChip(label = game.playfieldButtonLabel) {
                        playfieldCandidates.firstOrNull()?.let(onOpenPlayfield)
                    }
                } else {
                    AppUnavailableResourceChip()
                }
            }
        }
    }
}

@Composable
internal fun LibraryDetailVideosCard(
    game: PinballGame,
    activeVideoId: String?,
    onActiveVideoIdChange: (String?) -> Unit,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    CardContainer {
        SectionTitle("Video References")
        val playableVideos = game.videos.mapNotNull { v ->
            youtubeId(v.url)?.let { id ->
                val fallback = v.kind?.replaceFirstChar { c -> c.titlecase() } ?: "Video"
                PlayableVideo(id = id, label = v.label ?: fallback)
            }
        }
        if (playableVideos.isEmpty()) {
            AppPanelEmptyCard(text = "No video references listed.")
        } else {
            val selectedVideo = playableVideos.firstOrNull { it.id == activeVideoId } ?: playableVideos.firstOrNull()
            PinballVideoLaunchPanel(
                selectedVideo = selectedVideo,
                onOpenVideo = { video ->
                    openYoutubeInApp(
                        context = context,
                        url = video.watchUrl,
                        fallbackVideoId = video.id,
                    )
                },
            )
            BoxWithConstraints {
                val columnCount = 2
                val tileWidth = (maxWidth - 10.dp) / columnCount
                val rows = playableVideos.chunked(columnCount)
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    rows.forEach { rowItems ->
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            rowItems.forEach { video ->
                                VideoTile(
                                    video = video,
                                    selected = activeVideoId == video.id,
                                    width = tileWidth,
                                    onSelect = {
                                        onActiveVideoIdChange(video.id)
                                        LibraryActivityLog.log(context, game.slug, game.name, LibraryActivityKind.TapVideo, video.label)
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
}

@Composable
internal fun PinballVideoLaunchPanel(
    selectedVideo: PlayableVideo?,
    onOpenVideo: (PlayableVideo) -> Unit,
    minHeight: androidx.compose.ui.unit.Dp = 0.dp,
) {
    val metadata by produceState<YouTubeVideoMetadata?>(initialValue = null, key1 = selectedVideo?.id) {
        value = selectedVideo?.id?.let { loadYouTubeVideoMetadata(it) }
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(16f / 9f)
            .defaultMinSize(minHeight = minHeight)
            .background(
                MaterialTheme.colorScheme.surfaceContainerLow,
                RoundedCornerShape(10.dp),
            )
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(10.dp)),
        contentAlignment = Alignment.Center,
    ) {
        selectedVideo?.let { video ->
            AsyncImage(
                model = video.thumbnailUrl,
                contentDescription = video.label,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(10.dp)),
            )
        }
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Black.copy(alpha = 0.3f),
                            Color.Black.copy(alpha = 0.56f),
                            Color.Black.copy(alpha = 0.86f),
                        ),
                    ),
                    RoundedCornerShape(10.dp),
                ),
        )
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.padding(16.dp),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                AppOverlayTitle(
                    text = selectedVideo?.label ?: "Tap a video thumbnail",
                    modifier = Modifier.fillMaxWidth(),
                )
                metadata?.title?.let { title ->
                    AppOverlaySubtitle(
                        text = title,
                        alpha = 1f,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                metadata?.channelName?.let { channelName ->
                    AppOverlaySubtitle(
                        text = channelName,
                        alpha = 0.9f,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            Icon(
                imageVector = Icons.Outlined.PlayArrow,
                contentDescription = null,
                modifier = Modifier.size(28.dp),
            )

            AppSecondaryButton(
                onClick = { selectedVideo?.let(onOpenVideo) },
                enabled = selectedVideo != null,
                modifier = Modifier.defaultMinSize(minHeight = 40.dp),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            ) {
                Text(
                    text = "Open in YouTube",
                    maxLines = 1,
                    textAlign = TextAlign.Center,
                    lineHeight = 18.sp,
                )
            }
        }
    }
}

@Composable
internal fun LibraryDetailGameInfoCard(
    infoStatus: String,
    markdown: String?,
) {
    CardContainer {
        SectionTitle("Game Info")
        when (infoStatus) {
            "loading" -> AppInlineTaskStatus(text = "Loading…", showsProgress = true)
            "missing" -> AppPanelEmptyCard(text = "No game info yet.")
            "error" -> AppInlineTaskStatus(text = "Could not load game info.", isError = true)
            else -> CompositionLocalProvider(LocalContentColor provides MaterialTheme.colorScheme.onSurface) {
                val linkColor = MaterialTheme.colorScheme.primary
                val gameInfoStyle = remember {
                    RichTextStyle.Default.copy(
                        stringStyle = RichTextStringStyle.Default.copy(
                            linkStyle = SpanStyle(color = linkColor),
                        ),
                    )
                }
                RichText(
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
}

@Composable
internal fun LibraryDetailSourcesSection(
    game: PinballGame,
    hasRulesheet: Boolean,
    onOpenRulesheet: (RulesheetRemoteSource?) -> Unit,
    onOpenExternalRulesheet: (String) -> Unit,
    onOpenPlayfield: (String) -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        SectionTitle("Sources")
        AppResourceRow(label = "Rulesheet:") {
            if (game.rulesheetLinks.isNotEmpty()) {
                game.rulesheetLinks.forEach { link ->
                    val destination = link.destinationUrl
                    val embedded = link.embeddedRulesheetSource
                    AppResourceChip(label = appShortRulesheetTitle(link)) {
                        when {
                            embedded != null -> onOpenRulesheet(embedded)
                            destination != null -> onOpenExternalRulesheet(destination)
                            else -> onOpenRulesheet(null)
                        }
                    }
                }
            } else if (hasRulesheet) {
                AppResourceChip(label = "Local") { onOpenRulesheet(null) }
            }
        }
        AppResourceRow(label = "Playfield:") {
            if (game.hasPlayfieldResource) {
                AppResourceChip(label = game.playfieldButtonLabel) {
                    game.actualFullscreenPlayfieldCandidates.firstOrNull()?.let(onOpenPlayfield)
                }
            } else {
                AppUnavailableResourceChip()
            }
        }
    }
}
