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
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.ControlBg
import com.pillyliu.pinballandroid.ui.ControlBorder

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun LibraryList(
    contentPadding: PaddingValues,
    games: List<PinballGame>,
    query: String,
    sortOptionName: String,
    selectedBank: Int?,
    onQueryChange: (String) -> Unit,
    onSortOptionChange: (String) -> Unit,
    onBankChange: (Int?) -> Unit,
    onOpenGame: (PinballGame) -> Unit,
) {
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
    val searchFontSize = if (isLandscape) 14.sp else 13.sp
    val searchControlMinHeight = if (isLandscape) 48.dp else 48.dp
    val searchTextStyle = TextStyle(color = Color.White, fontSize = searchFontSize)
    val sortOption = remember(sortOptionName) {
        LibrarySortOption.entries.firstOrNull { it.name == sortOptionName } ?: LibrarySortOption.LOCATION
    }
    val bankOptions = games.mapNotNull { it.bank }.toSet().sorted()
    val filtered = games.filter { game ->
        val q = query.trim().lowercase()
        val queryMatch = if (q.isBlank()) true else {
            "${game.name} ${game.manufacturer.orEmpty()} ${game.year?.toString().orEmpty()}".lowercase().contains(q)
        }
        val bankMatch = selectedBank == null || game.bank == selectedBank
        queryMatch && bankMatch
    }
    val sortedGames = remember(filtered, sortOption) { sortLibraryGames(filtered, sortOption) }
    val showGroupedView = selectedBank == null && (sortOption == LibrarySortOption.LOCATION || sortOption == LibrarySortOption.BANK)
    val groupedSections = remember(sortedGames, sortOption) {
        when (sortOption) {
            LibrarySortOption.LOCATION -> buildSections(sortedGames) { it.group }
            LibrarySortOption.BANK -> buildSections(sortedGames) { it.bank }
            LibrarySortOption.ALPHABETICAL -> emptyList()
        }
    }

    AppScreen(contentPadding) {
        val controlsTopOffset = 4.dp
        val controlsTopInset = if (isLandscape) 76.dp else 120.dp
        Box(modifier = Modifier.fillMaxSize()) {
            if (games.isNotEmpty()) {
                Column(
                    modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(top = controlsTopInset),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    if (showGroupedView) {
                        groupedSections.forEachIndexed { idx, section ->
                            if (idx > 0) {
                                HorizontalDivider(color = Color.White.copy(alpha = 0.7f), thickness = 1.dp)
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
                if (isLandscape) {
                    BoxWithConstraints {
                        val spacing = 8.dp
                        val totalWidth = maxWidth - (spacing * 2)
                        val searchWidth = totalWidth * 0.5f
                        val sortWidth = totalWidth * 0.25f
                        val bankWidth = totalWidth - searchWidth - sortWidth
                        Row(horizontalArrangement = Arrangement.spacedBy(spacing)) {
                            OutlinedTextField(
                                value = query,
                                onValueChange = onQueryChange,
                                placeholder = {
                                    Text(
                                        "Search games...",
                                        color = Color(0xFFCECECE),
                                        style = searchTextStyle,
                                        maxLines = 1,
                                    )
                                },
                                modifier = Modifier
                                    .width(searchWidth)
                                    .height(searchControlMinHeight)
                                    .shadow(10.dp, RoundedCornerShape(14.dp), clip = false),
                                shape = RoundedCornerShape(14.dp),
                                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None),
                                textStyle = searchTextStyle,
                                singleLine = true,
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedTextColor = Color.White,
                                    unfocusedTextColor = Color.White,
                                    focusedLabelColor = Color.White,
                                    unfocusedLabelColor = Color(0xFFCECECE),
                                    cursorColor = Color.White,
                                    focusedContainerColor = ControlBg.copy(alpha = 0.94f),
                                    unfocusedContainerColor = ControlBg.copy(alpha = 0.9f),
                                    focusedBorderColor = ControlBorder,
                                    unfocusedBorderColor = ControlBorder,
                                ),
                            )

                            CompactLibraryFilterMenu(
                                selected = sortOption.label,
                                options = LibrarySortOption.entries.map { it.label },
                                modifier = Modifier.width(sortWidth),
                                isLandscape = true,
                                landscapeHeight = searchControlMinHeight,
                                landscapeFontSize = searchFontSize,
                            ) { selected ->
                                val option = LibrarySortOption.entries.firstOrNull { it.label == selected } ?: LibrarySortOption.LOCATION
                                onSortOptionChange(option.name)
                            }

                            CompactLibraryFilterMenu(
                                selected = selectedBank?.let { "Bank $it" } ?: "All banks",
                                options = listOf("All banks") + bankOptions.map { "Bank $it" },
                                modifier = Modifier.width(bankWidth),
                                isLandscape = true,
                                landscapeHeight = searchControlMinHeight,
                                landscapeFontSize = searchFontSize,
                            ) { selected ->
                                val bank = selected.removePrefix("Bank ").trim().toIntOrNull()
                                onBankChange(bank)
                            }
                        }
                    }
                } else {
                    OutlinedTextField(
                        value = query,
                        onValueChange = onQueryChange,
                        placeholder = {
                            Text(
                                "Search games...",
                                color = Color(0xFFCECECE),
                                style = searchTextStyle,
                                maxLines = 1,
                            )
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(searchControlMinHeight)
                            .shadow(10.dp, RoundedCornerShape(14.dp), clip = false),
                        shape = RoundedCornerShape(14.dp),
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None),
                        textStyle = searchTextStyle,
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = Color.White,
                            unfocusedTextColor = Color.White,
                            focusedLabelColor = Color.White,
                            unfocusedLabelColor = Color(0xFFCECECE),
                            cursorColor = Color.White,
                            focusedContainerColor = ControlBg.copy(alpha = 0.94f),
                            unfocusedContainerColor = ControlBg.copy(alpha = 0.9f),
                            focusedBorderColor = ControlBorder,
                            unfocusedBorderColor = ControlBorder,
                        ),
                    )

                    BoxWithConstraints {
                        val menuWidth = (maxWidth - 8.dp) / 2
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            CompactLibraryFilterMenu(
                                selected = sortOption.label,
                                options = LibrarySortOption.entries.map { it.label },
                                modifier = Modifier.width(menuWidth),
                            ) { selected ->
                                val option = LibrarySortOption.entries.firstOrNull { it.label == selected } ?: LibrarySortOption.LOCATION
                                onSortOptionChange(option.name)
                            }

                            CompactLibraryFilterMenu(
                                selected = selectedBank?.let { "Bank $it" } ?: "All banks",
                                options = listOf("All banks") + bankOptions.map { "Bank $it" },
                                modifier = Modifier.width(menuWidth),
                            ) { selected ->
                                val bank = selected.removePrefix("Bank ").trim().toIntOrNull()
                                onBankChange(bank)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CompactLibraryFilterMenu(
    selected: String,
    options: List<String>,
    modifier: Modifier = Modifier,
    isLandscape: Boolean = false,
    landscapeHeight: androidx.compose.ui.unit.Dp = 44.dp,
    landscapeFontSize: TextUnit = 13.sp,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(modifier = modifier) {
        OutlinedButton(
            onClick = { expanded = true },
            modifier = Modifier
                .fillMaxWidth()
                .then(if (isLandscape) Modifier.height(landscapeHeight) else Modifier.defaultMinSize(minHeight = 34.dp))
                .shadow(8.dp, RoundedCornerShape(10.dp), clip = false),
            contentPadding = PaddingValues(
                horizontal = if (isLandscape) 10.dp else 8.dp,
                vertical = if (isLandscape) 6.dp else 3.dp,
            ),
            shape = RoundedCornerShape(10.dp),
            colors = ButtonDefaults.outlinedButtonColors(
                containerColor = ControlBg.copy(alpha = 0.9f),
                contentColor = Color.White,
            ),
            border = androidx.compose.foundation.BorderStroke(1.dp, ControlBorder),
        ) {
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    selected,
                    fontSize = if (isLandscape) landscapeFontSize else 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.weight(1f))
                Icon(
                    imageVector = Icons.Filled.KeyboardArrowDown,
                    contentDescription = null,
                    tint = Color(0xFFC6C6C6),
                    modifier = Modifier.defaultMinSize(minWidth = if (isLandscape) 18.dp else 14.dp),
                )
            }
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option, fontSize = if (isLandscape) landscapeFontSize else 12.sp) },
                    onClick = {
                        expanded = false
                        onSelect(option)
                    },
                )
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
            .background(Color(0xFF171717), RoundedCornerShape(12.dp))
            .border(1.dp, Color(0xFF343434), RoundedCornerShape(12.dp))
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
            Text(
                game.name,
                color = Color.White,
                maxLines = 2,
                minLines = 2,
                overflow = TextOverflow.Ellipsis,
                lineHeight = 16.sp,
            )
            Text(game.manufacturerYearLine(), color = Color(0xFFB0B0B0), maxLines = 1, fontSize = 12.sp, lineHeight = 14.sp)
            Text(game.locationBankLine(), color = Color(0xFFC0C0C0), maxLines = 1, fontSize = 12.sp, lineHeight = 14.sp)
        }
    }
}
