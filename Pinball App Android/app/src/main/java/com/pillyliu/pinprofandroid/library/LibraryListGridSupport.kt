package com.pillyliu.pinprofandroid.library

import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.pillyliu.pinprofandroid.ui.AppMediaPreviewPlaceholder
import com.pillyliu.pinprofandroid.ui.AppOverlaySubtitle
import com.pillyliu.pinprofandroid.ui.AppOverlayTitleWithVariant

@Composable
internal fun LibrarySectionGrid(
    games: List<PinballGame>,
    onOpenGame: (PinballGame) -> Unit,
    onGameAppear: (PinballGame) -> Unit,
) {
    val configuration = LocalConfiguration.current
    BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
        val columnCount = if (configuration.orientation == Configuration.ORIENTATION_LANDSCAPE) 4 else 2
        val spacing = 12.dp
        val tileWidth = (maxWidth - (spacing * (columnCount - 1))) / columnCount
        val rows = games.chunked(columnCount)
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            rows.forEach { rowGames ->
                Row(horizontalArrangement = Arrangement.spacedBy(spacing)) {
                    rowGames.forEach { game ->
                        Box(modifier = Modifier.width(tileWidth)) {
                            LibraryGameCard(
                                game = game,
                                onClick = { onOpenGame(game) },
                                onAppear = { onGameAppear(game) },
                            )
                        }
                    }
                    repeat(columnCount - rowGames.size) {
                        Spacer(Modifier.width(tileWidth))
                    }
                }
            }
        }
    }
}

@Composable
private fun LibraryGameCard(game: PinballGame, onClick: () -> Unit, onAppear: () -> Unit) {
    Box(
        modifier = Modifier
            .background(MaterialTheme.colorScheme.surfaceContainerLow, RoundedCornerShape(12.dp))
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(12.dp))
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .aspectRatio(4f / 3f),
    ) {
        LaunchedEffect(game.libraryRouteId) {
            onAppear()
        }
        Box(modifier = Modifier.fillMaxSize()) {
            val artworkCandidates = game.cardArtworkCandidates()
            var activeIndex by remember(artworkCandidates) { mutableIntStateOf(0) }
            val imageModel = rememberCachedImageModel(artworkCandidates.getOrNull(activeIndex))
            var imageLoaded by remember(artworkCandidates, activeIndex) { mutableStateOf(false) }
            var showMissingImage by remember(artworkCandidates, activeIndex) { mutableStateOf(artworkCandidates.isEmpty()) }
            if (artworkCandidates.isNotEmpty()) {
                AsyncImage(
                    model = imageModel,
                    contentDescription = game.name,
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.Center),
                    contentScale = ContentScale.FillWidth,
                    alignment = Alignment.Center,
                    onLoading = {
                        imageLoaded = false
                        showMissingImage = false
                    },
                    onSuccess = {
                        imageLoaded = true
                        showMissingImage = false
                    },
                    onError = {
                        if (activeIndex < artworkCandidates.lastIndex) {
                            activeIndex += 1
                        } else {
                            imageLoaded = false
                            showMissingImage = true
                        }
                    },
                )
            }
            when {
                artworkCandidates.isEmpty() -> AppMediaPreviewPlaceholder(message = "No image")
                !imageLoaded && !showMissingImage -> AppMediaPreviewPlaceholder(showsProgress = true)
                showMissingImage -> AppMediaPreviewPlaceholder()
            }
        }
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        0f to androidx.compose.ui.graphics.Color.Transparent,
                        0.18f to androidx.compose.ui.graphics.Color.Transparent,
                        0.4f to androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.50f),
                        1f to androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.78f),
                    ),
                ),
        )
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(horizontal = 8.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp),
                contentAlignment = Alignment.TopStart,
            ) {
                AppOverlayTitleWithVariant(
                    text = game.name,
                    variant = game.normalizedVariant,
                    modifier = Modifier.fillMaxWidth(),
                    lineHeight = 20.sp,
                )
            }
            AppOverlaySubtitle(
                text = game.manufacturerYearCardLine(),
                modifier = Modifier.fillMaxWidth(),
                alpha = 0.95f,
            )
            AppOverlaySubtitle(
                text = game.locationBankLine().ifBlank { " " },
                alpha = 0.88f,
            )
        }
    }
}
