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
    var draftPrpaId by remember(store.prpaPlayerID) { mutableStateOf(store.prpaPlayerID) }

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
                scope.launch {
                    val identity = store.savePlayerProfileAndSyncIfpa(trimmed)
                    identity?.ifpaPlayerID?.let { draftIfpaId = it }
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
        SectionTitle("PRPA")
        OutlinedTextField(
            value = draftPrpaId,
            onValueChange = { draftPrpaId = it.filter(Char::isDigit) },
            label = { Text("PRPA number") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
        Text(
            "Save your Punk Rock Pinball Association player number to add PRPA rankings to the same Practice profile screen.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        AppPrimaryButton(
            onClick = { store.updatePrpaPlayerID(draftPrpaId.filter(Char::isDigit)) },
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Save PRPA ID") }
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
                scope.launch {
                    val identity = store.selectLeaguePlayerAndSyncIfpa(selectedPlayer)
                    identity?.ifpaPlayerID?.let { draftIfpaId = it }
                }
            },
        )
        Text(
            PRACTICE_LEAGUE_IMPORT_DESCRIPTION,
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
