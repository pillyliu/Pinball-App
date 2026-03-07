package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun PracticeTopBarGamePicker(
    context: PracticeTopBarGamePickerContext,
    modifier: Modifier = Modifier,
) {
    val orderedGames = orderedGamesForDropdown(context.games, collapseByPracticeIdentity = true)

    Box(
        modifier = modifier,
    ) {
        TextButton(
            onClick = { context.onExpandedChange(true) },
            contentPadding = PaddingValues(horizontal = 0.dp, vertical = 0.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = context.selectedGameName ?: "Game",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 20.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Start,
                )
                Icon(
                    imageVector = Icons.Filled.ArrowDropDown,
                    contentDescription = "Select game",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        DropdownMenu(
            expanded = context.expanded,
            onDismissRequest = { context.onExpandedChange(false) },
        ) {
            if (context.librarySources.size > 1) {
                DropdownMenuItem(
                    text = {
                        Text(
                            (if (context.selectedLibrarySourceId == null) "✓ " else "") + "All games",
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    },
                    onClick = {
                        context.onLibrarySourceSelected(PRACTICE_ALL_GAMES_SOURCE_ID)
                    },
                )
                context.librarySources.forEach { source ->
                    DropdownMenuItem(
                        text = {
                            Text(
                                (if (source.id == context.selectedLibrarySourceId) "✓ " else "") + source.name,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        },
                        onClick = {
                            context.onLibrarySourceSelected(source.id)
                        },
                    )
                }
                HorizontalDivider()
            }
            orderedGames.forEach { game ->
                DropdownMenuItem(
                    text = { Text(game.name, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    onClick = {
                        context.onExpandedChange(false)
                        context.onGameSelected(game)
                    },
                )
            }
        }
    }
}
