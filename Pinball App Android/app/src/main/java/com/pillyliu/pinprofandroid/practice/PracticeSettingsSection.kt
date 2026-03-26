package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
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
import com.pillyliu.pinprofandroid.ui.AppSwitch
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle
import kotlinx.coroutines.launch

@Composable
internal fun PracticeSettingsSection(
    store: PracticeStore,
    importStatus: String,
    onImportLplCsv: () -> Unit,
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
            "Used for manual import and auto-sync.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                "Auto-import new league scores",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            AppSwitch(
                checked = store.leagueCsvAutoFillEnabled,
                onCheckedChange = { store.updateLeagueCsvAutoFillEnabled(it) },
            )
        }
        Text(
            "When enabled, Practice checks for a new LPL stats hash and imports only when the hosted CSV changed.",
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
        SectionTitle("Reset")
        Text("Erase the full local Practice log state.")
        AppDestructiveButton(
            onClick = onOpenResetDialog,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Reset Practice Log") }
    }
}
