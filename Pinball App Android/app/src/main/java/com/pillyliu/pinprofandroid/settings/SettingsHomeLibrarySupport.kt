package com.pillyliu.pinprofandroid.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption
import com.pillyliu.pinprofandroid.library.ImportedSourceRecord
import com.pillyliu.pinprofandroid.library.LibrarySourceState
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore
import com.pillyliu.pinprofandroid.library.LibrarySourceType
import com.pillyliu.pinprofandroid.ui.AppInlineActionChip
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.AppConfirmDialog
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.AppSwitch
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle

@Composable
internal fun SettingsLibrarySection(
    manufacturers: List<CatalogManufacturerOption>,
    importedSources: List<ImportedSourceRecord>,
    sourceState: LibrarySourceState,
    onOpenAddManufacturer: () -> Unit,
    onOpenAddVenue: () -> Unit,
    onOpenAddTournament: () -> Unit,
    onToggleEnabled: (String, Boolean) -> Unit,
    onTogglePinned: (String, Boolean) -> Unit,
    onRefreshSource: (ImportedSourceRecord) -> Unit,
    onDeleteSource: (String) -> Unit,
) {
    var pendingDeleteSource by remember { mutableStateOf<ImportedSourceRecord?>(null) }

    CardContainer {
        SectionTitle("Library")
        AppCardSubheading("Add")
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            AppSecondaryButton(
                onClick = onOpenAddManufacturer,
                modifier = Modifier.weight(12f),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 0.dp),
            ) { Text("Manufacturer", maxLines = 1, overflow = TextOverflow.Clip) }
            AppSecondaryButton(
                onClick = onOpenAddVenue,
                modifier = Modifier.weight(5f),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 0.dp),
            ) { Text("Venue", maxLines = 1, overflow = TextOverflow.Clip) }
            AppSecondaryButton(
                onClick = onOpenAddTournament,
                modifier = Modifier.weight(10f),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 0.dp),
            ) { Text("Tournament", maxLines = 1, overflow = TextOverflow.Clip) }
        }
        Text(
            "Enabled adds that source's games to Library and Practice. Library adds the source to the Library source filter for quick switching. Up to ${LibrarySourceStateStore.MAX_PINNED_SOURCES} sources can appear in Library at once.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        importedSources.forEach { source ->
            ManagedSourceRow(
                title = source.name,
                subtitle = importedSourceSubtitle(source, manufacturers),
                enabled = sourceState.enabledSourceIds.contains(source.id),
                pinned = sourceState.pinnedSourceIds.contains(source.id),
                canDisable = true,
                onEnabledChange = { isEnabled -> onToggleEnabled(source.id, isEnabled) },
                onPinnedChange = { isPinned -> onTogglePinned(source.id, isPinned) },
                onRefresh = if (source.type == LibrarySourceType.VENUE || source.type == LibrarySourceType.TOURNAMENT) {
                    { onRefreshSource(source) }
                } else {
                    null
                },
                onDelete = { pendingDeleteSource = source },
            )
        }
        if (importedSources.isEmpty()) {
            AppPanelEmptyCard(text = "No sources added yet.")
        }
    }

    pendingDeleteSource?.let { source ->
        AppConfirmDialog(
            title = "Delete ${source.type.deleteLabel()}?",
            message = "Remove ${source.name} from Library and Practice? This can't be undone.",
            confirmLabel = "Delete",
            onConfirm = {
                onDeleteSource(source.id)
                pendingDeleteSource = null
            },
            onDismiss = { pendingDeleteSource = null },
        )
    }
}

@Composable
private fun ManagedSourceRow(
    title: String,
    subtitle: String,
    enabled: Boolean,
    pinned: Boolean,
    canDisable: Boolean,
    onEnabledChange: (Boolean) -> Unit,
    onPinnedChange: (Boolean) -> Unit,
    onRefresh: (() -> Unit)?,
    onDelete: (() -> Unit)?,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            AppCardSubheading(title)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                onRefresh?.let { AppInlineActionChip(text = "Refresh", onClick = it) }
                onDelete?.let { AppInlineActionChip(text = "Delete", onClick = it, destructive = true) }
            }
        }
        Column(horizontalAlignment = Alignment.End) {
            Text("Enabled", style = MaterialTheme.typography.labelSmall)
            AppSwitch(
                checked = enabled,
                onCheckedChange = onEnabledChange,
                enabled = canDisable,
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text("Pinned", style = MaterialTheme.typography.labelSmall)
            AppSwitch(
                checked = pinned,
                onCheckedChange = onPinnedChange,
            )
        }
    }
}

private fun LibrarySourceType.deleteLabel(): String = when (this) {
    LibrarySourceType.MANUFACTURER -> "Manufacturer"
    LibrarySourceType.VENUE -> "Venue"
    LibrarySourceType.TOURNAMENT -> "Tournament"
    LibrarySourceType.CATEGORY -> "Source"
}

private fun importedSourceSubtitle(
    source: ImportedSourceRecord,
    manufacturers: List<CatalogManufacturerOption>,
): String =
    when (source.type) {
        LibrarySourceType.MANUFACTURER -> {
            val count = manufacturers.firstOrNull { it.id == source.providerSourceId }?.gameCount ?: 0
            "Manufacturer • ${if (count == 1) "1 game" else "$count games"}"
        }

        LibrarySourceType.VENUE -> {
            val count = source.machineIds.size
            "Imported venue • ${if (count == 1) "1 game" else "$count games"}"
        }

        LibrarySourceType.TOURNAMENT -> {
            val count = source.machineIds.size
            "Match Play tournament • ${if (count == 1) "1 game" else "$count games"}"
        }

        LibrarySourceType.CATEGORY -> "Category"
    }
