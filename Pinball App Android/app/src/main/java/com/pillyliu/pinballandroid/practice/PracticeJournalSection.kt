package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.LocalTextStyle
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.library.LibraryActivityKind
import com.pillyliu.pinballandroid.library.LibraryActivityLog
import com.pillyliu.pinballandroid.ui.CardContainer
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

internal data class JournalTimelineRow(
    val id: String,
    val gameSlug: String,
    val summary: String,
    val timestampMs: Long,
    val journalEntry: JournalEntry?,
    val isEditable: Boolean,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun PracticeJournalSection(
    store: PracticeStore,
    journalFilter: JournalFilter,
    onJournalFilterChange: (JournalFilter) -> Unit,
    isSelectionMode: Boolean,
    selectedRowIds: Set<String>,
    onSelectionModeChange: (Boolean) -> Unit,
    onSelectedRowIdsChange: (Set<String>) -> Unit,
    onOpenGame: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var editingDraft by remember { mutableStateOf<PracticeJournalEditDraft?>(null) }
    var pendingDeleteRows by remember { mutableStateOf<List<JournalEntry>>(emptyList()) }
    var editValidation by remember { mutableStateOf<String?>(null) }
    var revealedRowId by rememberSaveable { mutableStateOf<String?>(null) }

    val filterWeights = remember {
        mapOf(
            JournalFilter.All to 0.72f,
            JournalFilter.Study to 0.95f,
            JournalFilter.Practice to 1.18f,
            JournalFilter.Scores to 0.95f,
            JournalFilter.Notes to 0.92f,
            JournalFilter.League to 1.16f,
        )
    }

    SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
        JournalFilter.entries.forEachIndexed { index, option ->
            SegmentedButton(
                selected = journalFilter == option,
                onClick = { onJournalFilterChange(option) },
                shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(index, JournalFilter.entries.size),
                modifier = Modifier.weight(filterWeights[option] ?: 1f),
                icon = {},
                label = { Text(option.label, maxLines = 1, softWrap = false, overflow = TextOverflow.Ellipsis) },
            )
        }
    }

    CardContainer(
        modifier = modifier
            .fillMaxWidth()
            .pointerInput(revealedRowId) {
                detectTapGestures(
                    onTap = {
                        if (revealedRowId != null) {
                            revealedRowId = null
                        }
                    }
                )
            }
    ) {
        val appRows = store.journalItems(journalFilter).map { row ->
            JournalTimelineRow(
                id = "app-${row.id}",
                gameSlug = row.gameSlug,
                summary = row.summary,
                timestampMs = row.timestampMs,
                journalEntry = row,
                isEditable = store.canEditJournalEntry(row),
            )
        }
        val libraryRows = when (journalFilter) {
            JournalFilter.All -> LibraryActivityLog.events(context)
            JournalFilter.Study -> LibraryActivityLog.events(context).filter {
                it.kind == LibraryActivityKind.OpenRulesheet ||
                    it.kind == LibraryActivityKind.OpenPlayfield ||
                    it.kind == LibraryActivityKind.TapVideo
            }
            JournalFilter.Practice, JournalFilter.Scores, JournalFilter.Notes, JournalFilter.League -> emptyList()
        }.map { event ->
            JournalTimelineRow(
                id = "library-${event.id}",
                gameSlug = event.gameSlug,
                summary = libraryActivitySummary(event),
                timestampMs = event.timestampMs,
                journalEntry = null,
                isEditable = false,
            )
        }

        val rows = (appRows + libraryRows).sortedByDescending { it.timestampMs }
        val selectedEditableEntries = rows
            .filter { it.id in selectedRowIds && it.isEditable }
            .mapNotNull { it.journalEntry }

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (isSelectionMode) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Button(
                        onClick = {
                            val entry = selectedEditableEntries.singleOrNull() ?: return@Button
                            editingDraft = store.journalEditDraft(entry)
                            editValidation = null
                        },
                        enabled = selectedEditableEntries.size == 1,
                    ) {
                        Icon(Icons.Outlined.Edit, contentDescription = null)
                        Text("Edit")
                    }
                    Button(
                        onClick = { pendingDeleteRows = selectedEditableEntries },
                        enabled = selectedEditableEntries.isNotEmpty(),
                    ) {
                        Icon(Icons.Outlined.Delete, contentDescription = null)
                        Text("Delete")
                    }
                }
            }

            if (rows.isEmpty()) {
                Text("No matching journal events.")
            } else {
                val grouped = rows.groupBy {
                    Instant.ofEpochMilli(it.timestampMs)
                        .atZone(ZoneId.systemDefault())
                        .toLocalDate()
                }
                val days = grouped.keys.sortedDescending()
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    days.forEach { day ->
                        item("header-$day") {
                            Text(
                                day.format(DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.US)),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        items(grouped[day].orEmpty(), key = { it.id }) { row ->
                            JournalRow(
                                row = row,
                                revealedRowId = revealedRowId,
                                onRevealedRowIdChange = { revealedRowId = it },
                                isSelectionMode = isSelectionMode,
                                isSelected = row.id in selectedRowIds,
                                onToggleSelected = {
                                    if (!row.isEditable) return@JournalRow
                                    onSelectedRowIdsChange(
                                        if (row.id in selectedRowIds) selectedRowIds - row.id else selectedRowIds + row.id
                                    )
                                },
                                onOpenGame = onOpenGame,
                                onEdit = { entry ->
                                    revealedRowId = null
                                    editingDraft = store.journalEditDraft(entry)
                                    editValidation = null
                                },
                                onDelete = { entry ->
                                    revealedRowId = null
                                    pendingDeleteRows = listOf(entry)
                                },
                            )
                        }
                    }
                }
            }
        }
    }

    if (pendingDeleteRows.isNotEmpty()) {
        AlertDialog(
            onDismissRequest = { pendingDeleteRows = emptyList() },
            title = { Text(if (pendingDeleteRows.size == 1) "Delete entry?" else "Delete entries?") },
            text = { Text("This will remove the selected journal entr${if (pendingDeleteRows.size == 1) "y" else "ies"} and linked practice data.") },
            confirmButton = {
                TextButton(onClick = {
                    pendingDeleteRows.forEach { store.deleteJournalEntry(it.id) }
                    val removedIds = pendingDeleteRows.map { "app-${it.id}" }.toSet()
                    onSelectedRowIdsChange(selectedRowIds - removedIds)
                    pendingDeleteRows = emptyList()
                    if ((selectedRowIds - removedIds).isEmpty()) onSelectionModeChange(false)
                }) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { pendingDeleteRows = emptyList() }) { Text("Cancel") }
            },
        )
    }

    editingDraft?.let { draft ->
        JournalEditDialog(
            store = store,
            initial = draft,
            validationMessage = editValidation,
            onDismiss = {
                editingDraft = null
                editValidation = null
            },
            onSave = { updated ->
                if (store.updateJournalEntry(updated)) {
                    editingDraft = null
                    editValidation = null
                    onSelectedRowIdsChange(emptySet())
                    onSelectionModeChange(false)
                } else {
                    editValidation = "Could not save changes."
                }
            },
        )
    }
}

@Composable
internal fun JournalRow(
    row: JournalTimelineRow,
    revealedRowId: String?,
    onRevealedRowIdChange: (String?) -> Unit,
    isSelectionMode: Boolean,
    isSelected: Boolean,
    onToggleSelected: () -> Unit,
    onOpenGame: (String) -> Unit,
    onEdit: (JournalEntry) -> Unit,
    onDelete: (JournalEntry) -> Unit,
) {
    if (row.journalEntry != null && row.isEditable && !isSelectionMode) {
        val actionWidth = 132.dp
        val actionWidthPx = with(LocalDensity.current) { actionWidth.toPx() }
        var rowHeightPx by rememberSaveable(row.id) { mutableStateOf(0) }
        val rowHeightDp = with(LocalDensity.current) {
            if (rowHeightPx > 0) rowHeightPx.toDp() else 40.dp
        }
        var offsetX by rememberSaveable(row.id) { mutableStateOf(0f) }
        val revealProgress = (kotlin.math.abs(offsetX) / actionWidthPx).coerceIn(0f, 1f)
        val dragState = rememberDraggableState { delta ->
            offsetX = (offsetX + delta).coerceIn(-actionWidthPx, 0f)
        }
        LaunchedEffect(revealedRowId) {
            if (revealedRowId != row.id && offsetX != 0f) {
                offsetX = 0f
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 6.dp, vertical = 4.dp)
                .defaultMinSize(minHeight = 40.dp)
                .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
        ) {
            Row(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .width(actionWidth)
                    .height(rowHeightDp)
                    .alpha(if (revealProgress > 0f) 1f else 0f)
            ) {
                SwipeRevealActionButton(
                    modifier = Modifier.weight(1f),
                    tint = Color(0xFF0A84FF),
                    icon = Icons.Outlined.Edit,
                    contentDescription = "Edit entry",
                    onClick = { row.journalEntry?.let(onEdit) }
                )
                SwipeRevealActionButton(
                    modifier = Modifier.weight(1f),
                    tint = Color(0xFFFF3B30),
                    icon = Icons.Outlined.Delete,
                    contentDescription = "Delete entry",
                    onClick = { row.journalEntry?.let(onDelete) }
                )
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight()
                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
                    .background(
                        MaterialTheme.colorScheme.surfaceContainerLow.copy(alpha = 1f - revealProgress)
                    )
                    .border(
                        width = 1.dp,
                        color = MaterialTheme.colorScheme.outline.copy(alpha = 0.72f - (0.22f * revealProgress)),
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
                    )
                    .offset { IntOffset(offsetX.toInt(), 0) }
                    .onSizeChanged { rowHeightPx = it.height }
                    .draggable(
                        state = dragState,
                        orientation = Orientation.Horizontal,
                        onDragStopped = {
                            val reveal = offsetX <= (-actionWidthPx * 0.2f)
                            offsetX = if (reveal) -actionWidthPx else 0f
                            onRevealedRowIdChange(if (reveal) row.id else null)
                        }
                    )
            ) {
                JournalRowContent(
                    row = row,
                    revealedRowId = revealedRowId,
                    onRevealedRowIdChange = onRevealedRowIdChange,
                    isSelectionMode = isSelectionMode,
                    isSelected = isSelected,
                    onToggleSelected = onToggleSelected,
                    onOpenGame = onOpenGame,
                )
            }
        }
    } else {
        if (row.isEditable) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 6.dp, vertical = 4.dp)
                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
                    .background(MaterialTheme.colorScheme.surfaceContainerLow)
                    .border(
                        width = 1.dp,
                        color = MaterialTheme.colorScheme.outline.copy(alpha = 0.72f),
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
                    )
            ) {
                JournalRowContent(
                    row = row,
                    revealedRowId = revealedRowId,
                    onRevealedRowIdChange = onRevealedRowIdChange,
                    isSelectionMode = isSelectionMode,
                    isSelected = isSelected,
                    onToggleSelected = onToggleSelected,
                    onOpenGame = onOpenGame,
                )
            }
        } else {
            JournalRowContent(
                row = row,
                revealedRowId = revealedRowId,
                onRevealedRowIdChange = onRevealedRowIdChange,
                isSelectionMode = isSelectionMode,
                isSelected = isSelected,
                onToggleSelected = onToggleSelected,
                onOpenGame = onOpenGame,
            )
        }
    }
}

@Composable
private fun RowScope.SwipeRevealActionButton(
    modifier: Modifier,
    tint: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .padding(horizontal = 1.dp)
            .fillMaxHeight()
            .background(tint, shape = androidx.compose.foundation.shape.RoundedCornerShape(6.dp))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = contentDescription, tint = Color.White)
    }
}

@Composable
private fun JournalRowContent(
    row: JournalTimelineRow,
    revealedRowId: String?,
    onRevealedRowIdChange: (String?) -> Unit,
    isSelectionMode: Boolean,
    isSelected: Boolean,
    onToggleSelected: () -> Unit,
    onOpenGame: (String) -> Unit,
) {
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable {
                if (revealedRowId != null) {
                    onRevealedRowIdChange(null)
                    return@clickable
                }
                if (isSelectionMode) {
                    onToggleSelected()
                } else if (row.gameSlug.isNotBlank()) {
                    onOpenGame(row.gameSlug)
                }
            }
            .padding(horizontal = 8.dp, vertical = 4.dp),
    ) {
        if (isSelectionMode) {
            if (row.isEditable) {
                Icon(
                    if (isSelected) Icons.Outlined.CheckCircle else Icons.Outlined.Circle,
                    contentDescription = null,
                    tint = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else {
                Text(" ", modifier = Modifier.padding(horizontal = 12.dp))
            }
        }
        Column(
            verticalArrangement = Arrangement.spacedBy(2.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            StyledPracticeJournalSummaryText(
                summary = row.summary,
                style = MaterialTheme.typography.bodySmall,
            )
            Text(
                formatTimestamp(row.timestampMs),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

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
            TextButton(onClick = {
                val draft = when (initial.kind) {
                    PracticeJournalEditKind.Score -> {
                        val score = scoreText.replace(",", "").trim().toDoubleOrNull() ?: return@TextButton
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
            }) { Text("Save") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
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
