package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.AppTextAction

@Composable
internal fun PracticeGameScoreEntrySheet(
    store: PracticeStore,
    selectedGameSlug: String,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit,
) {
    var scoreText by remember { mutableStateOf("") }
    var scoreFieldValue by remember { mutableStateOf(TextFieldValue("", TextRange.Zero)) }
    var scoreContext by remember { mutableStateOf("practice") }
    var tournamentName by remember { mutableStateOf("") }
    var validation by remember { mutableStateOf<String?>(null) }
    var showScoreScanner by remember { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current

    LaunchedEffect(scoreText) {
        if (scoreFieldValue.text != scoreText) {
            scoreFieldValue = TextFieldValue(scoreText, TextRange(scoreText.length))
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Log Score") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = scoreFieldValue,
                    onValueChange = { incoming ->
                        val formatted = formatScoreInputWithCommas(incoming.text)
                        scoreText = formatted
                        scoreFieldValue = TextFieldValue(formatted, TextRange(formatted.length))
                    },
                    label = { Text("Score") },
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    textStyle = LocalTextStyle.current.copy(
                        textAlign = TextAlign.End,
                        fontFamily = FontFamily.Monospace,
                    ),
                )
                AppSecondaryButton(
                    onClick = {
                        validation = null
                        focusManager.clearFocus(force = true)
                        showScoreScanner = true
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(
                        imageVector = Icons.Outlined.CameraAlt,
                        contentDescription = null,
                    )
                    Text(
                        text = "Scan Score",
                        modifier = Modifier.fillMaxWidth(),
                        textAlign = TextAlign.Center,
                    )
                }
                SimpleMenuDropdown(
                    title = "Context",
                    options = listOf("practice", "league", "tournament"),
                    selected = scoreContext,
                    onSelect = { scoreContext = it },
                )
                if (scoreContext == "tournament") {
                    OutlinedTextField(
                        value = tournamentName,
                        onValueChange = { tournamentName = it },
                        label = { Text("Tournament name") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                validation?.let {
                    Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = {
            AppTextAction(
                text = "Save",
                onClick = {
                    validation = null
                    val result = saveQuickEntry(
                        store = store,
                        mode = QuickActivity.Score,
                        rawGameSlug = selectedGameSlug,
                        scoreText = scoreText,
                        scoreContext = scoreContext,
                        tournamentName = tournamentName,
                        rulesheetProgress = 0f,
                        videoInputKind = "clock",
                        selectedVideoSource = "",
                        videoWatchedTime = "",
                        videoTotalTime = "",
                        videoPercent = 100f,
                        practiceMinutes = "",
                        practiceCategory = "general",
                        noteText = "",
                        mechanicsSkill = "",
                        mechanicsCompetency = 3f,
                    )
                    if (result.validationMessage != null) {
                        validation = result.validationMessage
                        return@AppTextAction
                    }
                    result.savedSlug?.let(onSave)
                },
                enabled = selectedGameSlug.isNotBlank(),
            )
        },
        dismissButton = { AppTextAction(text = "Cancel", onClick = onDismiss) },
    )

    if (showScoreScanner) {
        ScoreScannerDialog(
            onUseReading = { score ->
                scoreText = formatScoreInputWithCommas(score.toString())
                validation = null
                showScoreScanner = false
            },
            onClose = { showScoreScanner = false },
        )
    }
}
