package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.ui.CardContainer
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private data class JournalTimelineRow(
    val id: String,
    val gameSlug: String,
    val summary: String,
    val timestampMs: Long,
)

@Composable
internal fun PracticeJournalSection(
    store: PracticeStore,
    journalFilter: JournalFilter,
    onJournalFilterChange: (JournalFilter) -> Unit,
    onOpenGame: (String) -> Unit,
    timelineModifier: Modifier = Modifier,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
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

    CardContainer(modifier = timelineModifier.fillMaxWidth()) {
        val appRows = store.journalItems(journalFilter).map { row ->
            JournalTimelineRow(
                id = "app-${row.id}",
                gameSlug = row.gameSlug,
                summary = row.summary,
                timestampMs = row.timestampMs,
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
            )
        }

        val rows = (appRows + libraryRows).sortedByDescending { it.timestampMs }

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
                        Column(
                            verticalArrangement = Arrangement.spacedBy(2.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    if (row.gameSlug.isNotBlank()) {
                                        onOpenGame(row.gameSlug)
                                    }
                                },
                        ) {
                            Text(row.summary, style = MaterialTheme.typography.bodySmall)
                            Text(
                                formatTimestamp(row.timestampMs),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }
    }
}
