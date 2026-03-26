package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.pillyliu.pinprofandroid.data.formatLplPlayerNameForDisplay
import com.pillyliu.pinprofandroid.data.rememberShowFullLplLastName
import com.pillyliu.pinprofandroid.ui.AppDestructiveButton
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle
import kotlinx.coroutines.launch

@Composable
internal fun PracticeSettingsSection(
    store: PracticeStore,
    importStatus: String,
    importedLeagueScoreCount: Int,
    onImportLplCsv: () -> Unit,
    onOpenClearImportedLeagueScoresDialog: () -> Unit,
    onOpenResetDialog: () -> Unit,
) {
    val showFullLplLastName = rememberShowFullLplLastName()
    val scope = rememberCoroutineScope()
    var draftIfpaId by remember(store.ifpaPlayerID) { mutableStateOf(store.ifpaPlayerID) }

    CardContainer {
        SectionTitle("Practice Profile")
        var draftName by remember(store.playerName) { mutableStateOf(store.playerName) }
        OutlinedTextField(
            value = draftName,
            onValueChange = { draftName = it },
            label = { Text("Player name") },
            modifier = Modifier.fillMaxWidth(),
        )
        AppPrimaryButton(
            onClick = {
                val trimmed = draftName.trim()
                draftName = trimmed
                store.updatePlayerName(trimmed)
                if (trimmed.isNotBlank()) {
                    scope.launch {
                        val ifpaPlayerID = store.approvedLeagueIdentityMatch(trimmed)?.ifpaPlayerID ?: return@launch
                        store.updateIfpaPlayerID(ifpaPlayerID)
                        draftIfpaId = ifpaPlayerID
                    }
                }
            },
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Save Profile") }
    }

    CardContainer {
        SectionTitle("IFPA")
        OutlinedTextField(
            value = draftIfpaId,
            onValueChange = { draftIfpaId = it.filter(Char::isDigit) },
            label = { Text("IFPA number") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
        Text(
            "Save your IFPA player number to unlock a quick stats profile from the Practice home header.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        AppPrimaryButton(
            onClick = { store.updateIfpaPlayerID(draftIfpaId.filter(Char::isDigit)) },
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Save IFPA ID") }
    }

    CardContainer {
        SectionTitle("League Import")
        var players by remember { mutableStateOf(listOf<String>()) }
        LaunchedEffect(Unit) {
            players = store.availableLeaguePlayers()
            if (store.leaguePlayerName.isNotBlank() && !players.contains(store.leaguePlayerName)) {
                store.updateLeaguePlayerName("")
            }
        }
        SimpleMenuDropdown(
            title = "League player",
            options = players,
            selected = if (store.leaguePlayerName.isBlank()) "Select league player" else formatLplPlayerNameForDisplay(store.leaguePlayerName, showFullLplLastName),
            formatOptionLabel = { formatLplPlayerNameForDisplay(it, showFullLplLastName) },
            onSelect = { selectedPlayer ->
                store.updateLeaguePlayerName(selectedPlayer)
                scope.launch {
                    val ifpaPlayerID = store.approvedLeagueIdentityMatch(selectedPlayer)?.ifpaPlayerID ?: return@launch
                    store.updateIfpaPlayerID(ifpaPlayerID)
                    draftIfpaId = ifpaPlayerID
                }
            },
        )
        Text(
            "Used for manual import and automatic sync.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            "Practice automatically checks for a new hosted LPL stats file and imports only new rows.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        AppPrimaryButton(
            onClick = onImportLplCsv,
            enabled = store.leaguePlayerName.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Import LPL CSV") }
        if (importStatus.isNotBlank()) {
            Text(importStatus, style = MaterialTheme.typography.bodySmall)
        }
    }

    CardContainer {
        SectionTitle("Recovery")
        Text(
            importedLeagueScoreSummary(importedLeagueScoreCount),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        AppDestructiveButton(
            onClick = onOpenClearImportedLeagueScoresDialog,
            enabled = importedLeagueScoreCount > 0,
            modifier = Modifier.fillMaxWidth(),
        ) { Text(clearImportedLeagueScoresButtonTitle(importedLeagueScoreCount)) }
        Text(
            "Erase the full local Practice log state.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        AppDestructiveButton(
            onClick = onOpenResetDialog,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Reset Practice Log") }
    }
}

internal fun importedLeagueScoreSummary(count: Int): String {
    return when (count) {
        0 -> "No imported league scores are currently saved."
        1 -> "Remove only the 1 imported league score. Manual Practice notes and scores stay."
        else -> "Remove only the $count imported league scores. Manual Practice notes and scores stay."
    }
}

internal fun clearImportedLeagueScoresButtonTitle(count: Int): String {
    return when (count) {
        0 -> "Clear Imported League Scores"
        1 -> "Clear 1 Imported League Score"
        else -> "Clear $count Imported League Scores"
    }
}

internal fun clearImportedLeagueScoresAlertMessage(count: Int): String {
    return when (count) {
        0 -> "No imported league scores are currently saved."
        1 -> "This removes the 1 imported league score and matching journal rows. Manual Practice entries stay."
        else -> "This removes the $count imported league scores and matching journal rows. Manual Practice entries stay."
    }
}
