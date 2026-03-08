package com.pillyliu.pinprofandroid.library

import android.content.res.Configuration
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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.pillyliu.pinprofandroid.ui.AppFilterSheet
import com.pillyliu.pinprofandroid.ui.AppMediaPreviewPlaceholder
import com.pillyliu.pinprofandroid.ui.AppVariantPill
import com.pillyliu.pinprofandroid.ui.AppVariantPillStyle
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPanelStatusCard
import com.pillyliu.pinprofandroid.ui.AppSearchFilterBar
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.CompactDropdownFilter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun LibraryList(
    contentPadding: PaddingValues,
    isLoading: Boolean,
    errorMessage: String?,
    browseState: LibraryBrowseState,
    onSourceChange: (String) -> Unit,
    onQueryChange: (String) -> Unit,
    onSortOptionChange: (String) -> Unit,
    onBankChange: (Int?) -> Unit,
    onOpenGame: (PinballGame) -> Unit,
) {
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
    val searchFontSize = if (isLandscape) 14.sp else 13.sp
    val searchControlMinHeight = if (isLandscape) 48.dp else 48.dp
    val selectedSource = browseState.selectedSource
    val sortOptions = browseState.sortOptions
    val fallbackSort = browseState.fallbackSort
    val sortOption = browseState.sortOption
    var visibleCount by remember(
        browseState.selectedSourceId,
        browseState.query,
        browseState.sortOptionName,
        browseState.yearSortDescending,
        browseState.selectedBank,
        browseState.games,
    ) { mutableIntStateOf(48) }
    var showFilterSheet by remember { mutableStateOf(false) }
    val visibleGames = remember(browseState, visibleCount) { browseState.visibleGames(visibleCount) }
    val hasMoreGames = remember(browseState, visibleCount) { browseState.hasMoreGames(visibleCount) }
    val showGroupedView = browseState.showGroupedView
    val groupedSections = remember(browseState, visibleCount) { browseState.groupedSections(visibleCount) }

    AppScreen(contentPadding) {
        val controlsTopOffset = 2.dp
        val controlsTopInset = if (isLandscape) 64.dp else 64.dp
        Box(modifier = Modifier.fillMaxSize()) {
            if (browseState.games.isNotEmpty()) {
                Column(
                    modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(top = controlsTopInset),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    if (showGroupedView) {
                        groupedSections.forEachIndexed { idx, section ->
                            if (idx > 0) {
                                HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f), thickness = 1.dp)
                            }
                            LibrarySectionGrid(
                                games = section.games,
                                onOpenGame = onOpenGame,
                                onGameAppear = { game ->
                                    if (hasMoreGames && visibleGames.lastOrNull()?.slug == game.slug) {
                                        visibleCount += 36
                                    }
                                },
                            )
                        }
                    } else {
                        LibrarySectionGrid(
                            games = visibleGames,
                            onOpenGame = onOpenGame,
                            onGameAppear = { game ->
                                if (hasMoreGames && visibleGames.lastOrNull()?.slug == game.slug) {
                                    visibleCount += 36
                                }
                            },
                        )
                    }
                    Spacer(Modifier.height(LIBRARY_CONTENT_BOTTOM_FILLER))
                }
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = controlsTopInset),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    when {
                        isLoading -> AppPanelStatusCard(
                            text = "Loading library…",
                            showsProgress = true,
                        )
                        !errorMessage.isNullOrBlank() -> AppPanelStatusCard(
                            text = errorMessage,
                            isError = true,
                        )
                        else -> AppPanelEmptyCard(text = "No data loaded.")
                    }
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = controlsTopOffset),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                AppSearchFilterBar(
                    query = browseState.query,
                    onQueryChange = onQueryChange,
                    placeholder = "Search games...",
                    onFilterClick = { showFilterSheet = true },
                    minHeight = searchControlMinHeight,
                    textStyle = MaterialTheme.typography.bodyMedium.copy(fontSize = searchFontSize),
                    placeholderTextStyle = MaterialTheme.typography.bodyMedium.copy(fontSize = searchFontSize),
                )
            }
        }
    }

    if (showFilterSheet) {
        AppFilterSheet(
            title = "Library filters",
            onDismissRequest = { showFilterSheet = false },
        ) {
            if (browseState.visibleSources.isNotEmpty()) {
                CompactDropdownFilter(
                    selectedText = selectedSource?.name ?: "Library",
                    options = browseState.visibleSources.map { it.name },
                    onSelect = { selected ->
                        val source = browseState.visibleSources.firstOrNull { it.name == selected } ?: return@CompactDropdownFilter
                        onSourceChange(source.id)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    minHeight = 38.dp,
                    textSize = 12.sp,
                    itemTextSize = 12.sp,
                )
            }
            CompactDropdownFilter(
                selectedText = browseState.selectedSortLabel,
                options = sortOptions.flatMap {
                    if (it == LibrarySortOption.YEAR) listOf("Sort: Year (Old-New)", "Sort: Year (New-Old)") else listOf(it.label)
                },
                onSelect = { selected ->
                    when (selected) {
                        "Sort: Year (New-Old)" -> onSortOptionChange("YEAR_DESC")
                        "Sort: Year (Old-New)" -> onSortOptionChange(LibrarySortOption.YEAR.name)
                        else -> {
                            val option = sortOptions.firstOrNull { it.label == selected } ?: fallbackSort
                            onSortOptionChange(option.name)
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                minHeight = 38.dp,
                textSize = 12.sp,
                itemTextSize = 12.sp,
            )
            if (browseState.supportsBankFilter) {
                CompactDropdownFilter(
                    selectedText = browseState.selectedBankLabel,
                    options = listOf("All banks") + browseState.bankOptions.map { "Bank $it" },
                    onSelect = { selected ->
                        val bank = selected.removePrefix("Bank ").trim().toIntOrNull()
                        onBankChange(bank)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    minHeight = 38.dp,
                    textSize = 12.sp,
                    itemTextSize = 12.sp,
                )
            }
        }
    }
}

@Composable
private fun LibrarySectionGrid(
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
        androidx.compose.runtime.LaunchedEffect(game.slug) {
            onAppear()
        }
        Box(modifier = Modifier.fillMaxSize()) {
            val artworkCandidates = game.cardArtworkCandidates()
            var imageLoaded by remember(artworkCandidates) { mutableStateOf(false) }
            var showMissingImage by remember(artworkCandidates) { mutableStateOf(artworkCandidates.isEmpty()) }
            if (artworkCandidates.isNotEmpty()) {
                AsyncImage(
                    model = artworkCandidates.firstOrNull(),
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
                        imageLoaded = false
                        showMissingImage = true
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
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(42.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.Top,
            ) {
                Text(
                    game.name,
                    color = androidx.compose.ui.graphics.Color.White,
                    maxLines = 2,
                    minLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    fontSize = 16.sp,
                    lineHeight = 17.sp,
                    modifier = Modifier.weight(1f),
                )
            }
            BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
                val variantText = game.normalizedVariant
                val variantMaxWidth = 84.dp
                val makerMaxWidth = if (variantText != null) (maxWidth - variantMaxWidth - 4.dp) else maxWidth
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        game.manufacturerYearLine(),
                        color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.95f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 12.sp,
                        lineHeight = 14.sp,
                        modifier = Modifier.widthIn(max = if (makerMaxWidth > 48.dp) makerMaxWidth else 48.dp),
                    )
                    variantText?.let { variant ->
                        AppVariantPill(
                            label = variant,
                            style = AppVariantPillStyle.Standard,
                            modifier = Modifier.widthIn(max = variantMaxWidth),
                        )
                    }
                }
            }
            Text(
                game.locationBankLine().ifBlank { " " },
                color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.88f),
                maxLines = 1,
                fontSize = 12.sp,
                lineHeight = 14.sp,
            )
        }
    }
}
