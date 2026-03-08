package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.library.ConstrainedAsyncImagePreview
import com.pillyliu.pinprofandroid.practice.StyledPracticeJournalSummaryText
import com.pillyliu.pinprofandroid.practice.formatTimestamp
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors

@Composable
internal fun GameRoomMachineRoute(
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    selectedMachine: OwnedMachine?,
    machineSubview: GameRoomMachineSubview,
    onMachineSubviewChange: (GameRoomMachineSubview) -> Unit,
    selectedLogEventID: String?,
    onSelectedLogEventIDChange: (String?) -> Unit,
    revealedLogRowID: String?,
    onRevealedLogRowIDChange: (String?) -> Unit,
    onBack: () -> Unit,
    onOpenInputSheet: (GameRoomInputSheet) -> Unit,
    onResolveIssueRequest: (String) -> Unit,
    onLogPlaysRequest: (String) -> Unit,
    onPreviewAttachment: (MachineAttachment) -> Unit,
    onEditEvent: (MachineEvent) -> Unit,
    onDeleteEvent: (MachineEvent) -> Unit,
) {
    val selectedArt = selectedMachine?.let { catalogLoader.resolvedArt(it.catalogGameID, it.displayVariant) }
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
            title = "Machine View",
            onBack = onBack,
            titleColor = MaterialTheme.colorScheme.onSurface,
        )

        if (selectedMachine != null) {
            val machineHeroCandidates = listOfNotNull(
                selectedArt?.primaryImageLargeUrl,
                selectedArt?.primaryImageUrl,
                selectedArt?.playfieldImageLargeUrl,
                selectedArt?.playfieldImageUrl,
            )
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
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = selectedMachine.displayTitle,
                        color = MaterialTheme.colorScheme.onSurface,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    if (variantLabel != null) {
                        GameRoomVariantPill(label = variantLabel, style = VariantPillStyle.MachineTitle)
                    }
                    Spacer(modifier = Modifier.weight(1f))
                }
                Text(
                    text = machineLocationLine(selectedMachine, store),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
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
                revealedLogRowID = revealedLogRowID,
                onRevealedLogRowIDChange = onRevealedLogRowIDChange,
                onPreviewAttachment = onPreviewAttachment,
                onEditEvent = onEditEvent,
                onDeleteEvent = onDeleteEvent,
            )
        }
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
        Text(
            text = "Current Snapshot",
            color = MaterialTheme.colorScheme.onSurface,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
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
                "Purchase Date" to formatDate(machine.purchaseDateMs, "—"),
            ),
        )
        machine.purchaseDateRawText?.takeIf { it.isNotBlank() }?.let { raw ->
            Text(
                text = "Purchase (raw): $raw",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }

    CardContainer {
        Text(
            text = "Media",
            color = MaterialTheme.colorScheme.onSurface,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
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
        Text("Service", color = MaterialTheme.colorScheme.onSurface, fontWeight = FontWeight.SemiBold)
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
        Text("Issue", color = MaterialTheme.colorScheme.onSurface, fontWeight = FontWeight.SemiBold)
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
        Text("Ownership / Media", color = MaterialTheme.colorScheme.onSurface, fontWeight = FontWeight.SemiBold)
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
    revealedLogRowID: String?,
    onRevealedLogRowIDChange: (String?) -> Unit,
    onPreviewAttachment: (MachineAttachment) -> Unit,
    onEditEvent: (MachineEvent) -> Unit,
    onDeleteEvent: (MachineEvent) -> Unit,
) {
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
                    Text(
                        text = "Selected Entry",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.SemiBold,
                    )
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
                        Text(
                            text = "Media (${selectedEntryAttachments.size})",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontWeight = FontWeight.SemiBold,
                        )
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
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .pointerInput(revealedLogRowID) {
                        detectTapGestures(
                            onTap = {
                                if (revealedLogRowID != null) {
                                    onRevealedLogRowIDChange(null)
                                }
                            },
                        )
                    },
                verticalArrangement = Arrangement.spacedBy(0.dp),
            ) {
                machineEvents.forEachIndexed { index, event ->
                    val mediaCount = store.attachmentsForEvent(event.id).size
                    GameRoomLogRow(
                        event = event,
                        mediaCount = mediaCount,
                        selected = selectedLogEventID == event.id,
                        revealedRowID = revealedLogRowID,
                        onRevealedRowIDChange = onRevealedLogRowIDChange,
                        onSelect = {
                            onRevealedLogRowIDChange(null)
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
                        onEdit = {
                            onRevealedLogRowIDChange(null)
                            onEditEvent(event)
                        },
                        onDelete = {
                            onRevealedLogRowIDChange(null)
                            onDeleteEvent(event)
                        },
                    )
                    if (index != machineEvents.lastIndex) {
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                    }
                }
            }
        }
    }
}
