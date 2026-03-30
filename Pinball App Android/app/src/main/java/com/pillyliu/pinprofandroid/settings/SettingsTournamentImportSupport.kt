package com.pillyliu.pinprofandroid.settings

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.CardContainer

internal sealed class TournamentImportException(message: String) : Exception(message) {
    data object NoLinkedArenas : TournamentImportException("No OPDB-linked arenas were found for that tournament.")
}

internal fun extractTournamentId(raw: String): String? {
    val trimmed = raw.trim()
    if (trimmed.isBlank()) return null
    if (trimmed.all { it.isDigit() }) return trimmed
    return Regex("""tournaments/(\d+)""")
        .find(trimmed)
        ?.groupValues
        ?.getOrNull(1)
}

@Composable
internal fun SettingsTournamentImportCard(
    rawTournamentId: String,
    onTournamentIdChange: (String) -> Unit,
    importing: Boolean,
    error: String?,
    canImportTournament: Boolean,
    onImport: () -> Unit,
    onDone: () -> Unit,
) {
    CardContainer {
        LinkedHtmlText(
            html = """Import powered by <a href="https://matchplay.events">Match Play</a>""",
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = rawTournamentId,
            onValueChange = onTournamentIdChange,
            label = { Text("Tournament ID or URL") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onDone() }),
        )
        Text(
            "Enter a Match Play tournament ID or URL to import its arena list into Library and Practice.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        AppPrimaryButton(
            onClick = onImport,
            modifier = Modifier.fillMaxWidth(),
            enabled = canImportTournament,
        ) {
            Text(if (importing) "Importing..." else "Import Tournament")
        }
        if (importing) {
            AppInlineTaskStatus(text = "Importing tournament…", showsProgress = true)
        } else if (error != null) {
            AppInlineTaskStatus(text = error, isError = true)
        }
    }
}
