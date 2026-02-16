package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import com.pillyliu.pinballandroid.data.redactPlayerNameForDisplay
import com.pillyliu.pinballandroid.ui.CardContainer

@Composable
internal fun PracticeSettingsSection(
    store: PracticeStore,
    importStatus: String,
    onImportLplCsv: () -> Unit,
    onOpenResetDialog: () -> Unit,
) {
    CardContainer {
        Text("Practice Profile", fontWeight = FontWeight.SemiBold)
        var draftName by remember(store.playerName) { mutableStateOf(store.playerName) }
        OutlinedTextField(
            value = draftName,
            onValueChange = { draftName = it },
            label = { Text("Player name") },
            modifier = Modifier.fillMaxWidth(),
        )
        Button(onClick = { store.updatePlayerName(draftName) }) { Text("Save Profile") }
    }

    CardContainer {
        Text("League Import", fontWeight = FontWeight.SemiBold)
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
            selected = if (store.leaguePlayerName.isBlank()) "Select league player" else redactPlayerNameForDisplay(store.leaguePlayerName),
            formatOptionLabel = ::redactPlayerNameForDisplay,
            onSelect = { store.updateLeaguePlayerName(it) },
        )
        Text("Used when you tap Import LPL CSV.", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Button(
            onClick = onImportLplCsv,
            enabled = store.leaguePlayerName.isNotBlank(),
        ) { Text("Import LPL CSV") }
        if (importStatus.isNotBlank()) {
            Text(importStatus, style = MaterialTheme.typography.bodySmall)
        }
    }

    CardContainer {
        Text("Defaults", fontWeight = FontWeight.SemiBold)
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Enable optional cloud sync")
            Switch(
                checked = store.cloudSyncEnabled,
                onCheckedChange = { store.updateCloudSyncEnabled(it) },
            )
        }
        Text(
            "Placeholder for Phase 2 sync to pillyliu.com. Data stays on-device today.",
            style = MaterialTheme.typography.bodySmall,
        )
    }

    CardContainer {
        Text("Reset", fontWeight = FontWeight.SemiBold)
        Text("Erase the full local Practice log state.")
        Button(onClick = onOpenResetDialog) { Text("Reset Practice Log") }
    }
}
