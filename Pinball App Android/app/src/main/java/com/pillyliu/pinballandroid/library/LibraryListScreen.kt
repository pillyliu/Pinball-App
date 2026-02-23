package com.pillyliu.pinballandroid.library

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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.CompactDropdownFilter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun LibraryList(
    contentPadding: PaddingValues,
    games: List<PinballGame>,
    sources: List<LibrarySource>,
    selectedSourceId: String,
    query: String,
    sortOptionName: String,
    selectedBank: Int?,
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
    val searchContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh
    val searchTextStyle = TextStyle(color = MaterialTheme.colorScheme.onSurface, fontSize = searchFontSize)
    val selectedSource = remember(sources, selectedSourceId) {
        sources.firstOrNull { it.id == selectedSourceId } ?: sources.firstOrNull()
    }
    val sourceScopedGames = remember(games, selectedSource?.id) {
        val sid = selectedSource?.id
        if (sid == null) games else games.filter { it.sourceId == sid }
    }
    val sortOptions = remember(selectedSource, sourceScopedGames) {
        selectedSource?.let { sortOptionsForSource(it, sourceScopedGames) }
            ?: listOf(LibrarySortOption.AREA, LibrarySortOption.ALPHABETICAL)
    }
    val fallbackSort = remember(selectedSource, sortOptions) {
        selectedSource?.defaultSortOption?.takeIf { sortOptions.contains(it) } ?: sortOptions.first()
    }
    val sortOption = remember(sortOptionName, sortOptions, fallbackSort) {
        LibrarySortOption.entries.firstOrNull { it.name == sortOptionName }
            ?.takeIf { sortOptions.contains(it) }
            ?: fallbackSort
    }
    var showFilterSheet by remember { mutableStateOf(false) }
    val supportsBankFilter = selectedSource?.type == LibrarySourceType.VENUE && sourceScopedGames.any { (it.bank ?: 0) > 0 }
    val effectiveSelectedBank = if (supportsBankFilter) selectedBank else null
    val bankOptions = sourceScopedGames.mapNotNull { it.bank }.filter { it > 0 }.toSet().sorted()
    val filtered = sourceScopedGames.filter { game ->
        val q = query.trim().lowercase()
        val queryMatch = if (q.isBlank()) true else {
            "${game.name} ${game.manufacturer.orEmpty()} ${game.year?.toString().orEmpty()}".lowercase().contains(q)
        }
        val bankMatch = effectiveSelectedBank == null || game.bank == effectiveSelectedBank
        queryMatch && bankMatch
    }
    val sortedGames = remember(filtered, sortOption) { sortLibraryGames(filtered, sortOption) }
    val showGroupedView = effectiveSelectedBank == null && (sortOption == LibrarySortOption.AREA || sortOption == LibrarySortOption.BANK)
    val groupedSections = remember(sortedGames, sortOption) {
        when (sortOption) {
            LibrarySortOption.AREA -> buildSections(sortedGames) { it.group }
            LibrarySortOption.BANK -> buildSections(sortedGames) { it.bank }
            LibrarySortOption.ALPHABETICAL, LibrarySortOption.YEAR -> emptyList()
        }
    }

    AppScreen(contentPadding) {
        val controlsTopOffset = 2.dp
        val controlsTopInset = if (isLandscape) 64.dp else 64.dp
        Box(modifier = Modifier.fillMaxSize()) {
            if (games.isNotEmpty()) {
                Column(
                    modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(top = controlsTopInset),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    if (showGroupedView) {
                        groupedSections.forEachIndexed { idx, section ->
                            if (idx > 0) {
                                HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f), thickness = 1.dp)
                            }
                            LibrarySectionGrid(games = section.games, onOpenGame = onOpenGame)
                        }
                    } else {
                        LibrarySectionGrid(games = sortedGames, onOpenGame = onOpenGame)
                    }
                    Spacer(Modifier.height(LIBRARY_CONTENT_BOTTOM_FILLER))
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = controlsTopOffset),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    OutlinedTextField(
                        value = query,
                        onValueChange = onQueryChange,
                        placeholder = {
                            Text(
                                "Search games...",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = searchTextStyle,
                                maxLines = 1,
                            )
                        },
                        modifier = Modifier
                            .weight(1f)
                            .height(searchControlMinHeight)
                            .shadow(10.dp, RoundedCornerShape(14.dp), clip = false),
                        shape = RoundedCornerShape(14.dp),
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None),
                        textStyle = searchTextStyle,
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = MaterialTheme.colorScheme.onSurface,
                            unfocusedTextColor = MaterialTheme.colorScheme.onSurface,
                            focusedLabelColor = MaterialTheme.colorScheme.onSurface,
                            unfocusedLabelColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            cursorColor = MaterialTheme.colorScheme.onSurface,
                            focusedContainerColor = searchContainerColor,
                            unfocusedContainerColor = searchContainerColor,
                            focusedBorderColor = MaterialTheme.colorScheme.outlineVariant,
                            unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant,
                        ),
                    )
                    FilledTonalIconButton(
                        onClick = { showFilterSheet = true },
                        shape = RoundedCornerShape(14.dp),
                        colors = IconButtonDefaults.filledTonalIconButtonColors(
                            containerColor = searchContainerColor,
                            contentColor = MaterialTheme.colorScheme.onSurface,
                        ),
                        modifier = Modifier
                            .height(searchControlMinHeight)
                            .shadow(10.dp, RoundedCornerShape(14.dp), clip = false),
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.FilterList,
                            contentDescription = "Filters",
                        )
                    }
                }
            }
        }
    }

    if (showFilterSheet) {
        ModalBottomSheet(onDismissRequest = { showFilterSheet = false }) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text("Library filters", style = MaterialTheme.typography.titleSmall)
                if (sources.isNotEmpty()) {
                    CompactDropdownFilter(
                        selectedText = selectedSource?.name ?: "Library",
                        options = sources.map { it.name },
                        onSelect = { selected ->
                            val source = sources.firstOrNull { it.name == selected } ?: return@CompactDropdownFilter
                            onSourceChange(source.id)
                        },
                        modifier = Modifier.fillMaxWidth(),
                        minHeight = 38.dp,
                        textSize = 12.sp,
                        itemTextSize = 12.sp,
                    )
                }
                CompactDropdownFilter(
                    selectedText = sortOption.label,
                    options = sortOptions.map { it.label },
                    onSelect = { selected ->
                        val option = sortOptions.firstOrNull { it.label == selected } ?: fallbackSort
                        onSortOptionChange(option.name)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    minHeight = 38.dp,
                    textSize = 12.sp,
                    itemTextSize = 12.sp,
                )
                if (supportsBankFilter) {
                    CompactDropdownFilter(
                        selectedText = effectiveSelectedBank?.let { "Bank $it" } ?: "All banks",
                        options = listOf("All banks") + bankOptions.map { "Bank $it" },
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
                TextButton(onClick = { showFilterSheet = false }, modifier = Modifier.align(Alignment.End)) {
                    Text("Done")
                }
            }
        }
    }
}

@Composable
private fun LibrarySectionGrid(games: List<PinballGame>, onOpenGame: (PinballGame) -> Unit) {
    BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
        val tileWidth = (maxWidth - 12.dp) / 2
        val rows = games.chunked(2)
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            rows.forEach { rowGames ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    rowGames.forEach { game ->
                        Box(modifier = Modifier.width(tileWidth)) {
                            LibraryGameCard(game = game, onClick = { onOpenGame(game) })
                        }
                    }
                    if (rowGames.size == 1) {
                        Spacer(Modifier.width(tileWidth))
                    }
                }
            }
        }
    }
}

@Composable
private fun LibraryGameCard(game: PinballGame, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .background(MaterialTheme.colorScheme.surfaceContainerLow, RoundedCornerShape(12.dp))
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(12.dp))
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick),
    ) {
        AsyncImage(
            model = game.libraryPlayfieldCandidate(),
            contentDescription = game.name,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 96.dp)
                .aspectRatio(16f / 9f),
            contentScale = ContentScale.FillWidth,
        )

        Column(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(38.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.Top,
            ) {
                Text(
                    game.name,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 2,
                    minLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    lineHeight = 16.sp,
                    modifier = Modifier.weight(1f),
                )
            }
            BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
                val variantText = game.variant?.takeIf { it.isNotBlank() && !it.equals("null", ignoreCase = true) }
                val variantMaxWidth = 84.dp
                val makerMaxWidth = if (variantText != null) (maxWidth - variantMaxWidth - 4.dp) else maxWidth
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        game.manufacturerYearLine(),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 12.sp,
                        lineHeight = 14.sp,
                        modifier = Modifier.widthIn(max = if (makerMaxWidth > 48.dp) makerMaxWidth else 48.dp),
                    )
                    variantText?.let { variant ->
                        Text(
                            text = variant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontSize = 9.sp,
                            lineHeight = 10.sp,
                            modifier = Modifier
                                .widthIn(max = variantMaxWidth)
                                .border(
                                    width = 0.75.dp,
                                    color = MaterialTheme.colorScheme.outlineVariant,
                                    shape = RoundedCornerShape(999.dp),
                                )
                                .padding(horizontal = 5.dp, vertical = 2.dp),
                        )
                    }
                }
            }
            Text(game.locationBankLine(), color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, fontSize = 12.sp, lineHeight = 14.sp)
        }
    }
}
