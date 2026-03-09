package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
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
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppTextAction

@Composable
internal fun JournalEditDialog(
    store: PracticeStore,
    initial: PracticeJournalEditDraft,
    validationMessage: String?,
    onDismiss: () -> Unit,
    onSave: (PracticeJournalEditDraft) -> Unit,
) {
    val allGames = remember(store.games, store.allLibraryGames) {
        if (store.allLibraryGames.isNotEmpty()) store.allLibraryGames else store.games
    }
    val gameOptions = remember(allGames) { orderedGamesForDropdown(allGames, collapseByPracticeIdentity = true) }

    var gameSlug by remember(initial) { mutableStateOf(initial.gameSlug) }
    var scoreText by remember(initial) { mutableStateOf(initial.score?.let(::formatScore).orEmpty()) }
    var scoreContext by remember(initial) { mutableStateOf(initial.scoreContext ?: "practice") }
    var tournamentName by remember(initial) { mutableStateOf(initial.tournamentName.orEmpty()) }
    var studyCategory by remember(initial) { mutableStateOf(initial.studyCategory ?: "study") }
    var studyValue by remember(initial) { mutableStateOf(initial.studyValue.orEmpty()) }
    var studyNote by remember(initial) { mutableStateOf(initial.studyNote.orEmpty()) }
    var noteCategory by remember(initial) { mutableStateOf(initial.noteCategory ?: "general") }
    var noteDetail by remember(initial) { mutableStateOf(initial.noteDetail.orEmpty()) }
    var noteText by remember(initial) { mutableStateOf(initial.noteText.orEmpty()) }
    var scoreFieldValue by remember(initial) { mutableStateOf(TextFieldValue(scoreText, TextRange(scoreText.length))) }

    LaunchedEffect(scoreText) {
        if (scoreFieldValue.text != scoreText) {
            scoreFieldValue = TextFieldValue(scoreText, TextRange(scoreText.length))
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Edit Journal Entry") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SimpleMenuDropdown(
                    title = "Game",
                    options = gameOptions.map { it.practiceKey },
                    selected = gameSlug,
                    selectedLabel = findGameByPracticeLookupKey(gameOptions, gameSlug)?.displayTitleForPractice ?: gameSlug,
                    onSelect = { gameSlug = it },
                    formatOptionLabel = { option ->
                        findGameByPracticeLookupKey(gameOptions, option)?.displayTitleForPractice ?: option
                    },
                )

                when (initial.kind) {
                    PracticeJournalEditKind.Score -> {
                        OutlinedTextField(
                            value = scoreFieldValue,
                            onValueChange = { incoming ->
                                val formatted = formatScoreInputWithCommasForJournal(incoming.text)
                                scoreText = formatted
                                scoreFieldValue = TextFieldValue(formatted, TextRange(formatted.length))
                            },
                            label = { Text("Score") },
                            modifier = Modifier.fillMaxWidth(),
                            textStyle = LocalTextStyle.current.copy(
                                textAlign = TextAlign.End,
                                fontFamily = FontFamily.Monospace,
                            ),
                        )
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
                    }

                    PracticeJournalEditKind.Study, PracticeJournalEditKind.Practice -> {
                        val categories = if (initial.kind == PracticeJournalEditKind.Practice) listOf("practice") else listOf(
                            "rulesheet", "tutorial", "gameplay", "playfield", "practice"
                        )
                        SimpleMenuDropdown(
                            title = "Category",
                            options = categories,
                            selected = studyCategory,
                            onSelect = { studyCategory = it },
                        )
                        OutlinedTextField(
                            value = studyValue,
                            onValueChange = { studyValue = it },
                            label = { Text("Value") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                        OutlinedTextField(
                            value = studyNote,
                            onValueChange = { studyNote = it },
                            label = { Text("Note (optional)") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }

                    PracticeJournalEditKind.Note, PracticeJournalEditKind.Mechanics -> {
                        OutlinedTextField(
                            value = noteCategory,
                            onValueChange = { noteCategory = it },
                            label = { Text("Category") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                        OutlinedTextField(
                            value = noteDetail,
                            onValueChange = { noteDetail = it },
                            label = { Text("Detail (optional)") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                        OutlinedTextField(
                            value = noteText,
                            onValueChange = { noteText = it },
                            label = { Text("Note") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }

                if (!validationMessage.isNullOrBlank()) {
                    Text(validationMessage, color = MaterialTheme.colorScheme.error)
                }
            }
        },
        confirmButton = {
            AppTextAction(text = "Save", onClick = {
                val draft = when (initial.kind) {
                    PracticeJournalEditKind.Score -> {
                        val score = scoreText.replace(",", "").trim().toDoubleOrNull() ?: return@AppTextAction
                        initial.copy(
                            gameSlug = gameSlug,
                            score = score,
                            scoreContext = scoreContext,
                            tournamentName = tournamentName.takeIf { scoreContext == "tournament" && it.isNotBlank() },
                        )
                    }

                    PracticeJournalEditKind.Study, PracticeJournalEditKind.Practice -> {
                        initial.copy(
                            gameSlug = gameSlug,
                            studyCategory = studyCategory,
                            studyValue = studyValue.trim(),
                            studyNote = studyNote.trim().ifBlank { null },
                        )
                    }

                    PracticeJournalEditKind.Note, PracticeJournalEditKind.Mechanics -> {
                        initial.copy(
                            gameSlug = gameSlug,
                            noteCategory = noteCategory.trim(),
                            noteDetail = noteDetail.trim().ifBlank { null },
                            noteText = noteText.trim(),
                        )
                    }
                }
                onSave(draft)
            })
        },
        dismissButton = {
            AppTextAction(text = "Cancel", onClick = onDismiss)
        },
    )
}

private fun formatScoreInputWithCommasForJournal(raw: String): String {
    val digits = raw.filter(Char::isDigit)
    if (digits.isEmpty()) return ""
    val out = StringBuilder()
    digits.forEachIndexed { index, ch ->
        out.append(ch)
        val remaining = digits.length - index - 1
        if (remaining > 0 && remaining % 3 == 0) out.append(',')
    }
    return out.toString()
}
