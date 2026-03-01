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
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.platform.LocalContext
import com.pillyliu.pinballandroid.data.formatLplPlayerNameForDisplay
import com.pillyliu.pinballandroid.data.rememberLplFullNameAccessUnlocked
import com.pillyliu.pinballandroid.data.rememberShowFullLplLastName
import com.pillyliu.pinballandroid.data.setShowFullLplLastName
import com.pillyliu.pinballandroid.data.unlockLplFullNameAccess
import com.pillyliu.pinballandroid.ui.CardContainer

@Composable
internal fun PracticeSettingsSection(
    store: PracticeStore,
    importStatus: String,
    onImportLplCsv: () -> Unit,
    onOpenResetDialog: () -> Unit,
) {
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    val showFullLplLastName = rememberShowFullLplLastName()
    val lplFullNameAccessUnlocked = rememberLplFullNameAccessUnlocked()

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
            selected = if (store.leaguePlayerName.isBlank()) "Select league player" else formatLplPlayerNameForDisplay(store.leaguePlayerName, showFullLplLastName),
            formatOptionLabel = { formatLplPlayerNameForDisplay(it, showFullLplLastName) },
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
        Text("Privacy", fontWeight = FontWeight.SemiBold)
        Text(
            "Lansing Pinball League names are shown as first name plus last initial by default.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (lplFullNameAccessUnlocked) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("Show full last names for LPL data")
                Switch(
                    checked = showFullLplLastName,
                    onCheckedChange = { setShowFullLplLastName(context, it) },
                )
            }
        } else {
            var password by remember { mutableStateOf("") }
            var passwordError by remember { mutableStateOf<String?>(null) }
            OutlinedTextField(
                value = password,
                onValueChange = {
                    password = it
                    passwordError = null
                },
                label = { Text("LPL full-name password") },
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(
                    onDone = {
                        focusManager.clearFocus()
                        if (unlockLplFullNameAccess(context, password)) {
                            password = ""
                            passwordError = null
                        } else {
                            passwordError = "Incorrect password."
                        }
                    },
                ),
            )
            Button(
                onClick = {
                    if (unlockLplFullNameAccess(context, password)) {
                        password = ""
                        passwordError = null
                    } else {
                        passwordError = "Incorrect password."
                    }
                },
                enabled = password.isNotBlank(),
            ) {
                Text("Unlock Full Names")
            }
            passwordError?.let {
                Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            }
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
