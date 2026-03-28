package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.library.ConstrainedAsyncImagePreview
import com.pillyliu.pinprofandroid.practice.StyledPracticeJournalSummaryText
import com.pillyliu.pinprofandroid.practice.formatTimestamp
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.AppCardTitleWithVariant
import com.pillyliu.pinprofandroid.ui.AppInlineTintedMetaWithPill
import com.pillyliu.pinprofandroid.ui.AppMetricGrid
import com.pillyliu.pinprofandroid.ui.AppMetricItem
import com.pillyliu.pinprofandroid.ui.AppConfirmDialog
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
internal fun GameRoomMachineRoute(
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    selectedMachine: OwnedMachine?,
    machineSubview: GameRoomMachineSubview,
    onMachineSubviewChange: (GameRoomMachineSubview) -> Unit,
    selectedLogEventID: String?,
    onSelectedLogEventIDChange: (String?) -> Unit,
    onBack: () -> Unit,
    onOpenInputSheet: (GameRoomInputSheet) -> Unit,
    onResolveIssueRequest: (String) -> Unit,
    onLogPlaysRequest: (String) -> Unit,
    onPreviewAttachment: (MachineAttachment) -> Unit,
    onEditEvent: (MachineEvent) -> Unit,
    onDeleteEvent: (MachineEvent) -> Unit,
) {
    val machineHeroCandidates = selectedMachine?.let(catalogLoader::imageCandidates).orEmpty()
    val machineEvents = selectedMachine?.let { machine ->
        store.state.events.filter { it.ownedMachineID == machine.id }.sortedByDescending { it.occurredAtMs }
    }.orEmpty()
    val selectedLogEvent = machineEvents.firstOrNull { it.id == selectedLogEventID } ?: machineEvents.firstOrNull()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        AppScreenHeader(
            title = selectedMachine?.displayTitle ?: "Machine",
            onBack = onBack,
            titleColor = MaterialTheme.colorScheme.onSurface,
        )

        if (selectedMachine != null) {
            ConstrainedAsyncImagePreview(
                urls = machineHeroCandidates,
                contentDescription = selectedMachine.displayTitle,
                emptyMessage = "No image",
                maxAspectRatio = 4f / 3f,
                imagePadding = 0.dp,
            )

            Column(
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                val variantLabel = gameRoomVariantBadgeLabel(selectedMachine.displayVariant, selectedMachine.displayTitle)
                val statusColor = gameRoomStatusColor(selectedMachine.status)
                AppCardTitleWithVariant(
                    text = selectedMachine.displayTitle,
                    variant = variantLabel,
                    maxLines = 2,
                    modifier = Modifier.fillMaxWidth(),
                )
                AppInlineTintedMetaWithPill(
                    text = gameRoomMachineMetaLine(selectedMachine, store),
                    pillLabel = gameRoomStatusLabel(selectedMachine.status),
                    pillForeground = statusColor,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        } else {
            Text(
                text = "This machine is no longer available.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        CardContainer {
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                GameRoomMachineSubview.entries.forEachIndexed { index, subview ->
                    SegmentedButton(
                        selected = machineSubview == subview,
                        onClick = { onMachineSubviewChange(subview) },
                        colors = pinballSegmentedButtonColors(),
                        icon = {},
                        shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(
                            index = index,
                            count = GameRoomMachineSubview.entries.size,
                        ),
                        label = { Text(subview.label, maxLines = 1) },
                    )
                }
            }
        }

        if (selectedMachine != null && machineSubview == GameRoomMachineSubview.Summary) {
            GameRoomMachineSummaryPanel(
                store = store,
                machine = selectedMachine,
                onPreviewAttachment = onPreviewAttachment,
            )
        }

        if (selectedMachine != null && machineSubview == GameRoomMachineSubview.Input) {
            GameRoomMachineInputPanel(
                store = store,
                machine = selectedMachine,
                onOpenInputSheet = onOpenInputSheet,
                onResolveIssueRequest = onResolveIssueRequest,
                onLogPlaysRequest = onLogPlaysRequest,
            )
        }

        if (selectedMachine != null && machineSubview == GameRoomMachineSubview.Log) {
            GameRoomMachineLogPanel(
                store = store,
                machineEvents = machineEvents,
                selectedLogEvent = selectedLogEvent,
                selectedLogEventID = selectedLogEventID,
                onSelectedLogEventIDChange = onSelectedLogEventIDChange,
                onPreviewAttachment = onPreviewAttachment,
                onEditEvent = onEditEvent,
                onDeleteEvent = onDeleteEvent,
            )
        }
    }
}

@Composable
private fun gameRoomStatusColor(status: OwnedMachineStatus): Color {
    val colors = PinballThemeTokens.colors
    return when (status) {
        OwnedMachineStatus.active -> colors.statsHigh
        OwnedMachineStatus.loaned -> colors.brandGold
        OwnedMachineStatus.archived,
        OwnedMachineStatus.sold,
        OwnedMachineStatus.traded -> colors.brandChalk
    }
}

@Composable
private fun GameRoomMachineSummaryPanel(
    store: GameRoomStore,
    machine: OwnedMachine,
    onPreviewAttachment: (MachineAttachment) -> Unit,
) {
    val snapshot = store.snapshot(machine.id)
    val machineAttachments = store.attachmentsForMachine(machine.id)

    CardContainer {
        AppCardSubheading("Current Snapshot")
        AppMetricGrid(
            items = listOf(
                AppMetricItem("Open Issues", snapshot.openIssueCount.toString()),
                AppMetricItem("Current Plays", snapshot.currentPlayCount.toString()),
                AppMetricItem("Due Tasks", snapshot.dueTaskCount.toString()),
                AppMetricItem("Last Service", formatDate(snapshot.lastServiceAtMs, "None")),
                AppMetricItem("Pitch", snapshot.currentPitchValue?.let { String.format("%.1f", it) } ?: "—"),
                AppMetricItem("Last Level", formatDate(snapshot.lastLeveledAtMs, "None")),
                AppMetricItem("Last Inspection", formatDate(snapshot.lastGeneralInspectionAtMs, "None")),
                AppMetricItem("Purchase Date", formatDate(machine.purchaseDateMs, "—")),
            ),
        )
    }

    CardContainer {
        AppCardSubheading("Media")
        if (machineAttachments.isNotEmpty()) {
            MediaAttachmentGrid(
                attachments = machineAttachments,
                onOpen = onPreviewAttachment,
            )
        } else {
            AppPanelEmptyCard(text = "No media attached yet.")
        }
    }
}

@Composable
private fun GameRoomMachineInputPanel(
    store: GameRoomStore,
    machine: OwnedMachine,
    onOpenInputSheet: (GameRoomInputSheet) -> Unit,
    onResolveIssueRequest: (String) -> Unit,
    onLogPlaysRequest: (String) -> Unit,
) {
    CardContainer {
        AppCardSubheading("Service")
        TwoColumnButtons(
            items = listOf(
                "Clean Glass" to { onOpenInputSheet(GameRoomInputSheet.CleanGlass) },
                "Clean Playfield" to { onOpenInputSheet(GameRoomInputSheet.CleanPlayfield) },
                "Swap Balls" to { onOpenInputSheet(GameRoomInputSheet.SwapBalls) },
                "Check Pitch" to { onOpenInputSheet(GameRoomInputSheet.CheckPitch) },
                "Level Machine" to { onOpenInputSheet(GameRoomInputSheet.LevelMachine) },
                "General Inspection" to { onOpenInputSheet(GameRoomInputSheet.GeneralInspection) },
            ),
        )
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
        AppCardSubheading("Issue")
        TwoColumnButtons(
            items = listOf(
                "Log Issue" to { onOpenInputSheet(GameRoomInputSheet.LogIssue) },
                "Resolve Issue" to {
                    val openIssue = store.state.issues.firstOrNull {
                        it.ownedMachineID == machine.id && it.status != MachineIssueStatus.resolved
                    }
                    if (openIssue != null) {
                        onResolveIssueRequest(openIssue.id)
                    }
                },
            ),
        )
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
        AppCardSubheading("Ownership / Media")
        TwoColumnButtons(
            items = listOf(
                "Ownership Update" to { onOpenInputSheet(GameRoomInputSheet.OwnershipUpdate) },
                "Install Mod" to { onOpenInputSheet(GameRoomInputSheet.InstallMod) },
                "Replace Part" to { onOpenInputSheet(GameRoomInputSheet.ReplacePart) },
                "Log Plays" to { onLogPlaysRequest(store.snapshot(machine.id).currentPlayCount.toString()) },
                "Add Photo/Video" to { onOpenInputSheet(GameRoomInputSheet.AddMedia) },
            ),
        )
    }
}

@Composable
private fun GameRoomMachineLogPanel(
    store: GameRoomStore,
    machineEvents: List<MachineEvent>,
    selectedLogEvent: MachineEvent?,
    selectedLogEventID: String?,
    onSelectedLogEventIDChange: (String?) -> Unit,
    onPreviewAttachment: (MachineAttachment) -> Unit,
    onEditEvent: (MachineEvent) -> Unit,
    onDeleteEvent: (MachineEvent) -> Unit,
) {
    var pendingDeleteEvent by remember(machineEvents) { mutableStateOf<MachineEvent?>(null) }
    CardContainer {
        if (selectedLogEvent != null) {
            val eventAttachments = store.attachmentsForEvent(selectedLogEvent.id)
            val issueAttachments = selectedLogEvent.linkedIssueID?.let { store.attachmentsForIssue(it) }.orEmpty()
            val selectedEntryAttachments = (eventAttachments + issueAttachments).distinctBy { it.id }
            CardContainer(modifier = Modifier.height(164.dp)) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    AppCardSubheading(text = "Selected Entry")
                    StyledPracticeJournalSummaryText(
                        summary = selectedLogEvent.summary,
                        style = MaterialTheme.typography.bodySmall,
                    )
                    Text(
                        text = "Type: ${displayMachineEventType(selectedLogEvent.type)}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = "Category: ${displayMachineEventCategory(selectedLogEvent.category)}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = formatTimestamp(selectedLogEvent.occurredAtMs),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    if (!selectedLogEvent.notes.isNullOrBlank()) {
                        Text(
                            text = "Notes: ${selectedLogEvent.notes}",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (selectedEntryAttachments.isNotEmpty()) {
                        AppCardSubheading(text = "Media (${selectedEntryAttachments.size})")
                        MediaAttachmentGrid(
                            attachments = selectedEntryAttachments,
                            onOpen = onPreviewAttachment,
                        )
                    }
                }
            }
        }
        if (machineEvents.isEmpty()) {
            AppPanelEmptyCard(text = "No log entries yet.")
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 280.dp),
            ) {
                LazyColumn(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(0.dp),
                ) {
                    itemsIndexed(
                        items = machineEvents,
                        key = { _, event -> event.id },
                    ) { index, event ->
                        val mediaCount = store.attachmentsForEvent(event.id).size
                        GameRoomLogRow(
                            event = event,
                            mediaCount = mediaCount,
                            selected = selectedLogEventID == event.id,
                            onSelect = {
                                val mediaAttachment = if (
                                    event.type == MachineEventType.photoAdded ||
                                        event.type == MachineEventType.videoAdded
                                ) {
                                    store.attachmentsForEvent(event.id).firstOrNull()
                                } else {
                                    null
                                }
                                if (mediaAttachment != null) {
                                    onPreviewAttachment(mediaAttachment)
                                } else {
                                    onSelectedLogEventIDChange(event.id)
                                }
                            },
                            onEdit = { onEditEvent(event) },
                            onDelete = { pendingDeleteEvent = event },
                        )
                        if (index != machineEvents.lastIndex) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                        }
                    }
                }
            }
        }
    }

    pendingDeleteEvent?.let { event ->
        AppConfirmDialog(
            title = "Delete entry?",
            message = "This will remove the selected game room log entry.",
            confirmLabel = "Delete",
            onConfirm = {
                onDeleteEvent(event)
                pendingDeleteEvent = null
            },
            onDismiss = { pendingDeleteEvent = null },
        )
    }
}
