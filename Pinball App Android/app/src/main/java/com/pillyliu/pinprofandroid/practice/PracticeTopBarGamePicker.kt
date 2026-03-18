package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.layout.Box
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import com.pillyliu.pinprofandroid.ui.AppTopBarDropdownTrigger

@Composable
internal fun PracticeTopBarGamePicker(
    context: PracticeTopBarGamePickerContext,
    modifier: Modifier = Modifier,
) {
    val orderedGames = orderedGamesForDropdown(context.games, collapseByPracticeIdentity = true)

    Box(
        modifier = modifier,
    ) {
        AppTopBarDropdownTrigger(
            text = context.selectedGameName ?: "Game",
            onClick = { context.onExpandedChange(true) },
            contentDescription = "Select game",
        )
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
                    text = {
                        Text(
                            practiceDisplayTitleForKey(game.practiceKey, context.games) ?: game.name,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    },
                    onClick = {
                        context.onExpandedChange(false)
                        context.onGameSelected(game)
                    },
                )
            }
        }
    }
}
