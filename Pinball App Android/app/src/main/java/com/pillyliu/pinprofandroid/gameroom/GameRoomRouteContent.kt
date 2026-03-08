package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.CardContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Settings

internal data class GameRoomHomeRouteContext(
    val store: GameRoomStore,
    val catalogLoader: GameRoomCatalogLoader,
    val selectedMachine: OwnedMachine?,
    val selectedMachineID: String?,
    val collectionLayout: GameRoomCollectionLayout,
    val onCollectionLayoutChange: (GameRoomCollectionLayout) -> Unit,
    val onSelectMachine: (String) -> Unit,
    val onOpenMachineView: () -> Unit,
    val onOpenSettings: () -> Unit,
)

@Composable
internal fun GameRoomHomeRoute(
    context: GameRoomHomeRouteContext,
) {
    val store = context.store
    val activeMachines = store.activeMachines
    val selectedMachine = context.selectedMachine

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = store.venueName,
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.SemiBold,
                fontSize = 20.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 8.dp),
            )
            IconButton(onClick = context.onOpenSettings) {
                Icon(
                    imageVector = Icons.Outlined.Settings,
                    contentDescription = "GameRoom Settings",
                    tint = MaterialTheme.colorScheme.onSurface,
                )
            }
        }

        CardContainer {
            Text(
                text = "Selected Machine",
                color = MaterialTheme.colorScheme.onSurface,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            if (selectedMachine == null) {
                Text(
                    text = "Select a machine from the collection below.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodyMedium,
                )
            } else {
                val snapshot = store.snapshot(selectedMachine.id)
                val areaName = store.area(selectedMachine.gameRoomAreaID)?.name ?: "No area"
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = selectedMachine.displayTitle,
                        color = MaterialTheme.colorScheme.onSurface,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    val variantLabel = gameRoomVariantBadgeLabel(selectedMachine.displayVariant, selectedMachine.displayTitle)
                    if (variantLabel != null) {
                        GameRoomVariantPill(label = variantLabel, style = VariantPillStyle.Standard)
                    }
                }
                Text(
                    text = "Location: $areaName • Group ${selectedMachine.groupNumber ?: "—"} • Position ${selectedMachine.position ?: "—"}",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodyMedium,
                )
                Text(
                    text = "Current Snapshot",
                    color = MaterialTheme.colorScheme.onSurface,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = 2.dp),
                )
                SnapshotMetricGrid(
                    metrics = listOf(
                        "Open Issues" to snapshot.openIssueCount.toString(),
                        "Current Plays" to snapshot.currentPlayCount.toString(),
                        "Due Tasks" to snapshot.dueTaskCount.toString(),
                        "Last Service" to formatDate(snapshot.lastServiceAtMs, "None"),
                        "Pitch" to (snapshot.currentPitchValue?.let { String.format("%.1f", it) } ?: "—"),
                        "Last Level" to formatDate(snapshot.lastLeveledAtMs, "None"),
                        "Last Inspection" to formatDate(snapshot.lastGeneralInspectionAtMs, "None"),
                        "Purchase Date" to formatDate(selectedMachine.purchaseDateMs, "—"),
                    ),
                )
                selectedMachine.purchaseDateRawText?.takeIf { it.isNotBlank() }?.let { raw ->
                    Text(
                        text = "Purchase (raw): $raw",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }

        CardContainer {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Collection",
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    GameRoomCollectionLayout.entries.forEach { mode ->
                        val selected = mode == context.collectionLayout
                        Box(
                            modifier = Modifier
                                .background(
                                    if (selected) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceContainerHigh,
                                    RoundedCornerShape(999.dp),
                                )
                                .border(
                                    1.dp,
                                    if (selected) MaterialTheme.colorScheme.outline else MaterialTheme.colorScheme.outlineVariant,
                                    RoundedCornerShape(999.dp),
                                )
                                .clickable { context.onCollectionLayoutChange(mode) }
                                .padding(horizontal = 10.dp, vertical = 6.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = mode.label,
                                color = MaterialTheme.colorScheme.onSurface,
                                fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                            )
                        }
                    }
                }
            }
            Text(
                text = "Tracked active machines: ${activeMachines.size}",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (activeMachines.isEmpty()) {
                AppPanelEmptyCard(text = "No active machines yet. Add one in GameRoom Settings > Edit.")
            } else if (context.collectionLayout == GameRoomCollectionLayout.Tiles) {
                val leftColumn = activeMachines.filterIndexed { index, _ -> index % 2 == 0 }
                val rightColumn = activeMachines.filterIndexed { index, _ -> index % 2 == 1 }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        leftColumn.forEach { machine ->
                            val snapshot = store.snapshot(machine.id)
                            val art = context.catalogLoader.resolvedArt(machine.catalogGameID, machine.displayVariant)
                            MiniMachineCard(
                                machine = machine,
                                imageUrl = art?.primaryImageLargeUrl ?: art?.primaryImageUrl,
                                attentionState = snapshot.attentionState,
                                selected = context.selectedMachineID == machine.id,
                                onClick = {
                                    if (context.selectedMachineID == machine.id) {
                                        context.onOpenMachineView()
                                    } else {
                                        context.onSelectMachine(machine.id)
                                    }
                                },
                            )
                        }
                    }
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        rightColumn.forEach { machine ->
                            val snapshot = store.snapshot(machine.id)
                            val art = context.catalogLoader.resolvedArt(machine.catalogGameID, machine.displayVariant)
                            MiniMachineCard(
                                machine = machine,
                                imageUrl = art?.primaryImageLargeUrl ?: art?.primaryImageUrl,
                                attentionState = snapshot.attentionState,
                                selected = context.selectedMachineID == machine.id,
                                onClick = {
                                    if (context.selectedMachineID == machine.id) {
                                        context.onOpenMachineView()
                                    } else {
                                        context.onSelectMachine(machine.id)
                                    }
                                },
                            )
                        }
                    }
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    activeMachines.forEach { machine ->
                        val snapshot = store.snapshot(machine.id)
                        val art = context.catalogLoader.resolvedArt(machine.catalogGameID, machine.displayVariant)
                        MachineListRow(
                            machine = machine,
                            imageUrl = art?.primaryImageLargeUrl ?: art?.primaryImageUrl,
                            areaName = store.area(machine.gameRoomAreaID)?.name ?: "No area",
                            attentionState = snapshot.attentionState,
                            selected = context.selectedMachineID == machine.id,
                            onClick = {
                                if (context.selectedMachineID == machine.id) {
                                    context.onOpenMachineView()
                                } else {
                                    context.onSelectMachine(machine.id)
                                }
                            },
                        )
                    }
                }
            }
        }
    }
}

@Composable
internal fun GameRoomSettingsRoute(
    selectedSettingsSection: GameRoomSettingsSection,
    onSelectedSettingsSectionChange: (GameRoomSettingsSection) -> Unit,
    onBack: () -> Unit,
    importContent: @Composable () -> Unit,
    editContent: @Composable () -> Unit,
    archiveContent: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        AppScreenHeader(
            title = "GameRoom Settings",
            onBack = onBack,
            titleColor = MaterialTheme.colorScheme.onSurface,
        )

        CardContainer {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                GameRoomSettingsSection.entries.forEach { section ->
                    val selected = section == selectedSettingsSection
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .background(
                                if (selected) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceContainerHigh,
                                RoundedCornerShape(999.dp),
                            )
                            .border(
                                width = 1.dp,
                                color = if (selected) MaterialTheme.colorScheme.outline else MaterialTheme.colorScheme.outlineVariant,
                                shape = RoundedCornerShape(999.dp),
                            )
                            .clickable { onSelectedSettingsSectionChange(section) }
                            .padding(vertical = 8.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = section.label,
                            color = MaterialTheme.colorScheme.onSurface,
                            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                        )
                    }
                }
            }
        }

        CardContainer {
            Text(
                text = when (selectedSettingsSection) {
                    GameRoomSettingsSection.Import -> "Import from Pinside"
                    GameRoomSettingsSection.Edit -> "Edit GameRoom"
                    GameRoomSettingsSection.Archive -> "Machine Archive"
                },
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.SemiBold,
            )

            if (selectedSettingsSection == GameRoomSettingsSection.Import) {
                importContent()
            }
        }

        if (selectedSettingsSection == GameRoomSettingsSection.Edit) {
            editContent()
        }

        archiveContent()
    }
}
