package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.library.LibraryActivityKind
import com.pillyliu.pinprofandroid.library.LibraryActivityLog
import com.pillyliu.pinprofandroid.ui.AppConfirmDialog
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

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
                colors = pinballSegmentedButtonColors(),
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
                AppPanelEmptyCard(text = "No matching journal events.")
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
        AppConfirmDialog(
            title = if (pendingDeleteRows.size == 1) "Delete entry?" else "Delete entries?",
            message = "This will remove the selected journal entr${if (pendingDeleteRows.size == 1) "y" else "ies"} and linked practice data.",
            confirmLabel = "Delete",
            onConfirm = {
                pendingDeleteRows.forEach { store.deleteJournalEntry(it.id) }
                val removedIds = pendingDeleteRows.map { "app-${it.id}" }.toSet()
                onSelectedRowIdsChange(selectedRowIds - removedIds)
                pendingDeleteRows = emptyList()
                if ((selectedRowIds - removedIds).isEmpty()) onSelectionModeChange(false)
            },
            onDismiss = { pendingDeleteRows = emptyList() },
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
