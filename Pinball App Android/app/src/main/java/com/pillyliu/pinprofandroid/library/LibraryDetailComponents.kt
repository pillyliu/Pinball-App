package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle
import java.util.Locale

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
            Text(
                game.name,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            game.normalizedVariant?.let { variant ->
                Text(
                    text = variant,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .background(
                            MaterialTheme.colorScheme.surfaceContainerHigh,
                            shape = RoundedCornerShape(999.dp),
                        )
                        .border(
                            width = 0.75.dp,
                            color = MaterialTheme.colorScheme.outlineVariant,
                            shape = RoundedCornerShape(999.dp),
                        )
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                )
            }
        }
        Text(game.metaLine(), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Column(
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            ResourceRow(label = "Rulesheet:") {
                if (game.rulesheetLinks.isEmpty()) {
                    if (hasRulesheet) {
                        ResourceChipButton(label = "Local") { onOpenRulesheet(null) }
                    } else {
                        UnavailableResourceChip()
                    }
                } else {
                    game.rulesheetLinks.forEach { link ->
                        val destination = link.destinationUrl
                        val embedded = link.embeddedRulesheetSource
                        ResourceChipButton(label = shortRulesheetTitle(link)) {
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
            ResourceRow(label = "Playfield:") {
                val playfieldCandidates = game.actualFullscreenPlayfieldCandidates
                if (playfieldCandidates.isNotEmpty()) {
                    ResourceChipButton(label = game.playfieldButtonLabel) {
                        playfieldCandidates.firstOrNull()?.let(onOpenPlayfield)
                    }
                } else {
                    UnavailableResourceChip()
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
    val overlayTextShadow = Shadow(
        color = Color.Black.copy(alpha = 0.9f),
        offset = Offset(0f, 2f),
        blurRadius = 6f,
    )

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
                Text(
                    text = selectedVideo?.label ?: "Tap a video thumbnail",
                    style = MaterialTheme.typography.titleMedium.copy(shadow = overlayTextShadow),
                    color = Color.White,
                    textAlign = TextAlign.Start,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                metadata?.title?.let { title ->
                    Text(
                        text = title,
                        style = MaterialTheme.typography.bodyLarge.copy(
                            fontWeight = FontWeight.SemiBold,
                            shadow = overlayTextShadow,
                        ),
                        color = Color.White,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                metadata?.channelName?.let { channelName ->
                    Text(
                        text = channelName,
                        style = MaterialTheme.typography.bodySmall.copy(shadow = overlayTextShadow),
                        color = Color.White.copy(alpha = 0.9f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }

            Icon(
                imageVector = Icons.Outlined.PlayArrow,
                contentDescription = null,
                modifier = Modifier.size(28.dp),
            )

            OutlinedButton(
                onClick = { selectedVideo?.let(onOpenVideo) },
                enabled = selectedVideo != null,
                modifier = Modifier.defaultMinSize(minHeight = 40.dp),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            ) {
                Text(
                    text = "Open in YouTube",
                    color = MaterialTheme.colorScheme.onSurface,
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
        ResourceRow(label = "Rulesheet:") {
            if (game.rulesheetLinks.isNotEmpty()) {
                game.rulesheetLinks.forEach { link ->
                    val destination = link.destinationUrl
                    val embedded = link.embeddedRulesheetSource
                    ResourceChipButton(label = shortRulesheetTitle(link)) {
                        when {
                            embedded != null -> onOpenRulesheet(embedded)
                            destination != null -> onOpenExternalRulesheet(destination)
                            else -> onOpenRulesheet(null)
                        }
                    }
                }
            } else if (hasRulesheet) {
                ResourceChipButton(label = "Local") { onOpenRulesheet(null) }
            }
        }
        ResourceRow(label = "Playfield:") {
            if (game.hasPlayfieldResource) {
                ResourceChipButton(label = game.playfieldButtonLabel) {
                    game.actualFullscreenPlayfieldCandidates.firstOrNull()?.let(onOpenPlayfield)
                }
            } else {
                UnavailableResourceChip()
            }
        }
    }
}

@Composable
internal fun ResourceRow(
    label: String,
    content: @Composable () -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .weight(1f, fill = false)
                .horizontalScroll(rememberScrollState()),
        ) {
            content()
        }
        Spacer(modifier = Modifier.weight(1f))
    }
}

@Composable
internal fun ResourceChipButton(
    label: String,
    onClick: () -> Unit,
) {
    OutlinedButton(
        onClick = onClick,
        modifier = Modifier.defaultMinSize(minHeight = 32.dp),
        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            contentColor = MaterialTheme.colorScheme.onSurface,
        ),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
    ) {
        Text(label, fontSize = 12.sp)
    }
}

@Composable
internal fun UnavailableResourceChip() {
    Text(
        "Unavailable",
        fontSize = 12.sp,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier
            .background(
                MaterialTheme.colorScheme.surfaceContainerLow,
                RoundedCornerShape(999.dp),
            )
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(999.dp))
            .padding(horizontal = 10.dp, vertical = 7.dp),
    )
}

internal fun shortRulesheetTitle(link: ReferenceLink): String {
    val label = link.label.lowercase(Locale.US)
    return when {
        "(tf)" in label -> "TF"
        "(pp)" in label -> "PP"
        "(papa)" in label -> "PAPA"
        "(bob)" in label -> "Bob"
        "(local)" in label || "(source)" in label -> "Local"
        else -> "Local"
    }
}
