package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.pillyliu.pinprofandroid.ui.AppOverlaySubtitle
import com.pillyliu.pinprofandroid.ui.AppOverlayTitle
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle

@Composable
internal fun LibraryDetailVideosCard(
    game: PinballGame,
    activeVideoId: String?,
    onActiveVideoIdChange: (String?) -> Unit,
) {
    val context = LocalContext.current
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
                                        LibraryActivityLog.log(context, game.libraryRouteId, game.name, LibraryActivityKind.TapVideo, video.label)
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
    minHeight: Dp = 0.dp,
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
                androidx.compose.material3.MaterialTheme.colorScheme.surfaceContainerLow,
                RoundedCornerShape(10.dp),
            )
            .border(1.dp, androidx.compose.material3.MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(10.dp)),
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
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    lineHeight = 18.sp,
                )
            }
        }
    }
}
