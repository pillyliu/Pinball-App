package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Settings
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
import com.pillyliu.pinprofandroid.data.redactPlayerNameForDisplay
import com.pillyliu.pinprofandroid.ui.AppBackButton
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens

@Composable
internal fun PracticeTopBar(
    route: PracticeRoute,
    playerName: String,
    editingGroupID: String?,
    gamePickerContext: PracticeTopBarGamePickerContext? = null,
    onBack: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenIfpaProfile: () -> Unit,
    isJournalSelectionMode: Boolean = false,
    onToggleJournalSelectionMode: (() -> Unit)? = null,
) {
    val colors = PinballThemeTokens.colors
    Row(verticalAlignment = Alignment.CenterVertically) {
        if (route != PracticeRoute.Home) {
            AppBackButton(onClick = onBack)
        }
        if (route == PracticeRoute.Game && gamePickerContext != null) {
            PracticeTopBarGamePicker(
                context = gamePickerContext,
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 0.dp),
            )
        } else {
            if (route == PracticeRoute.Home) {
                PracticeWelcomeTitle(
                    playerName = playerName,
                    onOpenIfpaProfile = onOpenIfpaProfile,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 8.dp),
                )
            } else {
                Text(
                    text = practiceTopTitle(route, editingGroupID),
                    color = colors.brandInk,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 20.sp,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 0.dp),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        if (route == PracticeRoute.Journal && onToggleJournalSelectionMode != null) {
            if (isJournalSelectionMode) {
                TextButton(
                    onClick = onToggleJournalSelectionMode,
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                ) {
                    Text("Cancel", style = MaterialTheme.typography.labelLarge, maxLines = 1, softWrap = false, color = colors.brandInk)
                }
            } else {
                IconButton(onClick = onToggleJournalSelectionMode) {
                    Icon(Icons.Outlined.Edit, contentDescription = "Edit journal entries", tint = colors.brandInk)
                }
            }
        } else if (route == PracticeRoute.Home) {
            IconButton(onClick = onOpenSettings) {
                Icon(Icons.Outlined.Settings, contentDescription = "Settings", tint = colors.brandInk)
            }
        }
    }
}

private fun practiceTopTitle(
    route: PracticeRoute,
    editingGroupID: String?,
): String {
    return when (route) {
        PracticeRoute.IfpaProfile -> "IFPA Profile"
        PracticeRoute.GroupDashboard -> "Group Dashboard"
        PracticeRoute.GroupEditor -> if (editingGroupID == null) "Create Group" else "Edit Group"
        PracticeRoute.Journal -> "Journal Timeline"
        PracticeRoute.Insights -> "Insights"
        PracticeRoute.Mechanics -> "Mechanics"
        PracticeRoute.Settings -> "Practice Settings"
        else -> "Practice"
    }
}

@Composable
private fun PracticeWelcomeTitle(
    playerName: String,
    onOpenIfpaProfile: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    val trimmed = playerName.trim()
    if (trimmed.isBlank()) {
        Text(
            text = "Welcome back",
            color = colors.brandInk,
            fontWeight = FontWeight.SemiBold,
            fontSize = 20.sp,
            modifier = modifier,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        return
    }
    val redacted = redactPlayerNameForDisplay(trimmed)
    val display = if (redacted != trimmed) {
        redacted
    } else {
        trimmed.split(Regex("\\s+")).firstOrNull().orEmpty().ifBlank { trimmed }
    }
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "Welcome back, ",
            color = colors.brandInk,
            fontWeight = FontWeight.SemiBold,
            fontSize = 20.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        TextButton(
            onClick = onOpenIfpaProfile,
            contentPadding = PaddingValues(0.dp),
        ) {
            Text(
                text = display,
                color = androidx.compose.ui.graphics.Color(0xFF7DC4FA),
                fontWeight = FontWeight.SemiBold,
                fontSize = 20.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
