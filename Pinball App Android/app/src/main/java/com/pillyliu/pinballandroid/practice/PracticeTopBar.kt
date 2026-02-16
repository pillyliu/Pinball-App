package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import com.pillyliu.pinballandroid.data.redactPlayerNameForDisplay
import com.pillyliu.pinballandroid.library.PinballGame

@Composable
internal fun PracticeTopBar(
    route: PracticeRoute,
    playerName: String,
    editingGroupID: String?,
    selectedGameName: String?,
    games: List<PinballGame>,
    gamePickerExpanded: Boolean,
    onGamePickerExpandedChange: (Boolean) -> Unit,
    onGameSelected: (PinballGame) -> Unit,
    onBack: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        if (route != PracticeRoute.Home) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
            }
        }
        if (route == PracticeRoute.Game) {
            androidx.compose.foundation.layout.Box(
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 0.dp),
            ) {
                TextButton(
                    onClick = { onGamePickerExpandedChange(true) },
                    contentPadding = PaddingValues(horizontal = 0.dp, vertical = 0.dp),
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            text = selectedGameName ?: "Game",
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
                    expanded = gamePickerExpanded,
                    onDismissRequest = { onGamePickerExpandedChange(false) },
                ) {
                    games.forEach { game ->
                        DropdownMenuItem(
                            text = { Text(game.name, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                            onClick = {
                                onGamePickerExpandedChange(false)
                                onGameSelected(game)
                            },
                        )
                    }
                }
            }
        } else {
            Text(
                text = practiceTopTitle(route, playerName, editingGroupID),
                fontWeight = FontWeight.SemiBold,
                fontSize = 20.sp,
                modifier = Modifier
                    .weight(1f)
                    .padding(start = if (route == PracticeRoute.Home) 8.dp else 0.dp),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (route == PracticeRoute.Home) {
            IconButton(onClick = onOpenSettings) {
                Icon(Icons.Outlined.Settings, contentDescription = "Settings")
            }
        }
    }
}

private fun practiceTopTitle(
    route: PracticeRoute,
    playerName: String,
    editingGroupID: String?,
): String {
    return when (route) {
        PracticeRoute.Home -> practiceWelcomeTitle(playerName)
        PracticeRoute.GroupDashboard -> "Group Dashboard"
        PracticeRoute.GroupEditor -> if (editingGroupID == null) "Create Group" else "Edit Group"
        PracticeRoute.Journal -> "Journal Timeline"
        PracticeRoute.Insights -> "Insights"
        PracticeRoute.Mechanics -> "Mechanics"
        PracticeRoute.Settings -> "Practice Settings"
        else -> "Practice"
    }
}

private fun practiceWelcomeTitle(playerName: String): String {
    val trimmed = playerName.trim()
    if (trimmed.isBlank()) return "Welcome back"
    val redacted = redactPlayerNameForDisplay(trimmed)
    val display = if (redacted != trimmed) {
        redacted
    } else {
        trimmed.split(Regex("\\s+")).firstOrNull().orEmpty().ifBlank { trimmed }
    }
    return "Welcome back, $display"
}
