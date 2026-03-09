package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppInlineActionChip
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.dismissKeyboardOnTapOutside

internal data class GameRoomInputSheetContext(
    val store: GameRoomStore,
    val selectedMachine: OwnedMachine,
    val selectedSheet: GameRoomInputSheet,
    val inputDateDraft: String,
    val onInputDateDraftChange: (String) -> Unit,
    val inputNotesDraft: String,
    val onInputNotesDraftChange: (String) -> Unit,
    val inputConsumableDraft: String,
    val onInputConsumableDraftChange: (String) -> Unit,
    val inputPitchValueDraft: String,
    val onInputPitchValueDraftChange: (String) -> Unit,
    val inputPitchPointDraft: String,
    val onInputPitchPointDraftChange: (String) -> Unit,
    val inputIssueSymptomDraft: String,
    val onInputIssueSymptomDraftChange: (String) -> Unit,
    val inputIssueSeverityDraft: String,
    val onInputIssueSeverityDraftChange: (String) -> Unit,
    val inputIssueSubsystemDraft: String,
    val onInputIssueSubsystemDraftChange: (String) -> Unit,
    val inputIssueDiagnosisDraft: String,
    val onInputIssueDiagnosisDraftChange: (String) -> Unit,
    val inputResolveIssueIDDraft: String?,
    val onInputResolveIssueIDDraftChange: (String?) -> Unit,
    val inputOwnershipTypeDraft: String,
    val onInputOwnershipTypeDraftChange: (String) -> Unit,
    val inputSummaryDraft: String,
    val onInputSummaryDraftChange: (String) -> Unit,
    val inputDetailsDraft: String,
    val onInputDetailsDraftChange: (String) -> Unit,
    val inputPlayTotalDraft: String,
    val onInputPlayTotalDraftChange: (String) -> Unit,
    val inputMediaKindDraft: String,
    val onInputMediaKindDraftChange: (String) -> Unit,
    val inputMediaURIDraft: String,
    val onInputMediaURIDraftChange: (String) -> Unit,
    val inputMediaCaptionDraft: String,
    val onInputMediaCaptionDraftChange: (String) -> Unit,
    val issueDraftAttachments: List<IssueInputAttachmentDraft>,
    val onIssueDraftAttachmentsChange: (List<IssueInputAttachmentDraft>) -> Unit,
    val onLaunchIssuePhotoPicker: () -> Unit,
    val onLaunchIssueVideoPicker: () -> Unit,
    val onLaunchPendingMediaPicker: (MachineAttachmentKind, Long) -> Unit,
    val onSelectedLogEventIDChange: (String?) -> Unit,
    val onMachineSubviewChange: (GameRoomMachineSubview) -> Unit,
    val onDismiss: () -> Unit,
)

internal data class GameRoomEditEventContext(
    val store: GameRoomStore,
    val editingEventID: String,
    val editEventDateDraft: String,
    val onEditEventDateDraftChange: (String) -> Unit,
    val editEventSummaryDraft: String,
    val onEditEventSummaryDraftChange: (String) -> Unit,
    val editEventNotesDraft: String,
    val onEditEventNotesDraftChange: (String) -> Unit,
    val onDismiss: () -> Unit,
)

internal data class GameRoomAttachmentPresentationContext(
    val store: GameRoomStore,
    val mediaPreviewAttachment: MachineAttachment?,
    val editingAttachment: MachineAttachment?,
    val editAttachmentCaptionDraft: String,
    val onEditAttachmentCaptionDraftChange: (String) -> Unit,
    val editAttachmentNotesDraft: String,
    val onEditAttachmentNotesDraftChange: (String) -> Unit,
    val onClosePreview: () -> Unit,
    val onBeginAttachmentEdit: (MachineAttachment) -> Unit,
    val onDeleteAttachment: (MachineAttachment) -> Unit,
    val onDismissAttachmentEdit: () -> Unit,
)

@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun GameRoomPresentationHost(
    inputSheetContext: GameRoomInputSheetContext?,
    editEventContext: GameRoomEditEventContext?,
    attachmentContext: GameRoomAttachmentPresentationContext?,
) {
    if (inputSheetContext != null) {
        GameRoomInputSheetHost(inputSheetContext)
    }
    if (editEventContext != null) {
        GameRoomEditEventSheet(editEventContext)
    }
    if (attachmentContext != null) {
        GameRoomAttachmentPresentationHost(attachmentContext)
    }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
private fun GameRoomInputSheetHost(context: GameRoomInputSheetContext) {
    val openIssues = context.store.state.issues
        .filter { it.ownedMachineID == context.selectedMachine.id && it.status != MachineIssueStatus.resolved }
        .sortedByDescending { it.openedAtMs }

    ModalBottomSheet(
        onDismissRequest = context.onDismiss,
        modifier = Modifier.dismissKeyboardOnTapOutside(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = context.selectedSheet.title,
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.SemiBold,
            )
            OutlinedTextField(
                value = context.inputDateDraft,
                onValueChange = context.onInputDateDraftChange,
                label = { Text("Date (YYYY-MM-DD)") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )

            when (context.selectedSheet) {
                GameRoomInputSheet.CleanGlass,
                GameRoomInputSheet.CleanPlayfield,
                GameRoomInputSheet.SwapBalls,
                GameRoomInputSheet.LevelMachine,
                GameRoomInputSheet.GeneralInspection -> {
                    if (
                        context.selectedSheet == GameRoomInputSheet.CleanGlass ||
                        context.selectedSheet == GameRoomInputSheet.CleanPlayfield
                    ) {
                        OutlinedTextField(
                            value = context.inputConsumableDraft,
                            onValueChange = context.onInputConsumableDraftChange,
                            label = { Text("Cleaner / Consumable") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                        )
                    }
                    OutlinedTextField(
                        value = context.inputNotesDraft,
                        onValueChange = context.onInputNotesDraftChange,
                        label = { Text("Notes") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                GameRoomInputSheet.CheckPitch -> {
                    OutlinedTextField(
                        value = context.inputPitchValueDraft,
                        onValueChange = context.onInputPitchValueDraftChange,
                        label = { Text("Pitch (degrees)") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                    )
                    OutlinedTextField(
                        value = context.inputPitchPointDraft,
                        onValueChange = context.onInputPitchPointDraftChange,
                        label = { Text("Measurement Point") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                    )
                    OutlinedTextField(
                        value = context.inputNotesDraft,
                        onValueChange = context.onInputNotesDraftChange,
                        label = { Text("Notes") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                GameRoomInputSheet.LogIssue -> {
                    OutlinedTextField(
                        value = context.inputIssueSymptomDraft,
                        onValueChange = context.onInputIssueSymptomDraftChange,
                        label = { Text("Issue") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    AnchoredDropdownFilter(
                        selectedText = context.inputIssueSeverityDraft.replaceFirstChar { it.uppercase() },
                        options = MachineIssueSeverity.entries.map {
                            DropdownOption(it.name, it.name.replaceFirstChar { ch -> ch.uppercase() })
                        },
                        onSelect = context.onInputIssueSeverityDraftChange,
                    )
                    AnchoredDropdownFilter(
                        selectedText = context.inputIssueSubsystemDraft.replaceFirstChar { it.uppercase() },
                        options = MachineIssueSubsystem.entries.map {
                            DropdownOption(it.name, it.name.replaceFirstChar { ch -> ch.uppercase() })
                        },
                        onSelect = context.onInputIssueSubsystemDraftChange,
                    )
                    OutlinedTextField(
                        value = context.inputIssueDiagnosisDraft,
                        onValueChange = context.onInputIssueDiagnosisDraftChange,
                        label = { Text("Diagnosis / Notes") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        AppSecondaryButton(
                            onClick = context.onLaunchIssuePhotoPicker,
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Add Photo")
                        }
                        AppSecondaryButton(
                            onClick = context.onLaunchIssueVideoPicker,
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Add Video")
                        }
                    }
                    if (context.issueDraftAttachments.isEmpty()) {
                        AppPanelEmptyCard(text = "No media selected.")
                    } else {
                        context.issueDraftAttachments.forEach { attachment ->
                            GameRoomIssueAttachmentDraftRow(
                                attachment = attachment,
                                onDelete = {
                                    context.onIssueDraftAttachmentsChange(
                                        context.issueDraftAttachments.filterNot { current -> current.id == attachment.id },
                                    )
                                },
                            )
                        }
                    }
                }

                GameRoomInputSheet.ResolveIssue -> {
                    AnchoredDropdownFilter(
                        selectedText = openIssues.firstOrNull { it.id == context.inputResolveIssueIDDraft }?.symptom ?: "Select Issue",
                        options = openIssues.map { DropdownOption(it.id, it.symptom) },
                        onSelect = context.onInputResolveIssueIDDraftChange,
                    )
                    OutlinedTextField(
                        value = context.inputNotesDraft,
                        onValueChange = context.onInputNotesDraftChange,
                        label = { Text("Resolution Notes") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                GameRoomInputSheet.OwnershipUpdate -> {
                    AnchoredDropdownFilter(
                        selectedText = context.inputOwnershipTypeDraft.replaceFirstChar { it.uppercase() },
                        options = listOf(
                            MachineEventType.purchased,
                            MachineEventType.moved,
                            MachineEventType.loanedOut,
                            MachineEventType.returned,
                            MachineEventType.listedForSale,
                            MachineEventType.sold,
                            MachineEventType.traded,
                            MachineEventType.reacquired,
                        ).map {
                            DropdownOption(it.name, it.name.replaceFirstChar { ch -> ch.uppercase() })
                        },
                        onSelect = context.onInputOwnershipTypeDraftChange,
                    )
                    OutlinedTextField(
                        value = context.inputSummaryDraft,
                        onValueChange = context.onInputSummaryDraftChange,
                        label = { Text("Summary") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = context.inputNotesDraft,
                        onValueChange = context.onInputNotesDraftChange,
                        label = { Text("Notes") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                GameRoomInputSheet.InstallMod,
                GameRoomInputSheet.ReplacePart -> {
                    OutlinedTextField(
                        value = context.inputSummaryDraft,
                        onValueChange = context.onInputSummaryDraftChange,
                        label = { Text("Summary") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                    )
                    OutlinedTextField(
                        value = context.inputDetailsDraft,
                        onValueChange = context.onInputDetailsDraftChange,
                        label = {
                            Text(if (context.selectedSheet == GameRoomInputSheet.InstallMod) "Mod / Details" else "Part Replaced")
                        },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = context.inputNotesDraft,
                        onValueChange = context.onInputNotesDraftChange,
                        label = { Text("Notes") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                GameRoomInputSheet.LogPlays -> {
                    OutlinedTextField(
                        value = context.inputPlayTotalDraft,
                        onValueChange = context.onInputPlayTotalDraftChange,
                        label = { Text("Total Plays") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                    )
                    OutlinedTextField(
                        value = context.inputNotesDraft,
                        onValueChange = context.onInputNotesDraftChange,
                        label = { Text("Notes") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                GameRoomInputSheet.AddMedia -> {
                    AnchoredDropdownFilter(
                        selectedText = context.inputMediaKindDraft.replaceFirstChar { it.uppercase() },
                        options = MachineAttachmentKind.entries.map {
                            DropdownOption(it.name, it.name.replaceFirstChar { ch -> ch.uppercase() })
                        },
                        onSelect = context.onInputMediaKindDraftChange,
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        AppSecondaryButton(
                            onClick = {
                                val occurredAtMs = parseIsoDateMillis(context.inputDateDraft) ?: System.currentTimeMillis()
                                context.onInputMediaKindDraftChange(MachineAttachmentKind.photo.name)
                                context.onLaunchPendingMediaPicker(MachineAttachmentKind.photo, occurredAtMs)
                            },
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Add Photo")
                        }
                        AppSecondaryButton(
                            onClick = {
                                val occurredAtMs = parseIsoDateMillis(context.inputDateDraft) ?: System.currentTimeMillis()
                                context.onInputMediaKindDraftChange(MachineAttachmentKind.video.name)
                                context.onLaunchPendingMediaPicker(MachineAttachmentKind.video, occurredAtMs)
                            },
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Add Video")
                        }
                    }
                    OutlinedTextField(
                        value = context.inputMediaURIDraft,
                        onValueChange = context.onInputMediaURIDraftChange,
                        label = { Text("Media URI (optional)") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                    )
                    OutlinedTextField(
                        value = context.inputMediaCaptionDraft,
                        onValueChange = context.onInputMediaCaptionDraftChange,
                        label = { Text("Caption") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = context.inputNotesDraft,
                        onValueChange = context.onInputNotesDraftChange,
                        label = { Text("Notes") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                AppSecondaryButton(
                    onClick = {
                        context.onIssueDraftAttachmentsChange(emptyList())
                        context.onDismiss()
                    },
                ) {
                    Text("Cancel")
                }
                AppPrimaryButton(
                    onClick = { saveGameRoomInputSheet(context) },
                    enabled = when (context.selectedSheet) {
                        GameRoomInputSheet.LogIssue -> context.inputIssueSymptomDraft.isNotBlank()
                        GameRoomInputSheet.ResolveIssue -> !context.inputResolveIssueIDDraft.isNullOrBlank()
                        GameRoomInputSheet.LogPlays -> context.inputPlayTotalDraft.isNotBlank()
                        else -> true
                    },
                ) {
                    Text("Save")
                }
            }
        }
    }
}

private fun saveGameRoomInputSheet(context: GameRoomInputSheetContext) {
    val occurredAtMs = parseIsoDateMillis(context.inputDateDraft) ?: System.currentTimeMillis()
    when (context.selectedSheet) {
        GameRoomInputSheet.CleanGlass -> context.store.addEvent(
            machineID = context.selectedMachine.id,
            type = MachineEventType.glassCleaned,
            category = MachineEventCategory.service,
            summary = "Clean Glass",
            occurredAtMs = occurredAtMs,
            notes = context.inputNotesDraft.ifBlank { null },
            consumablesUsed = context.inputConsumableDraft.ifBlank { null },
        )
        GameRoomInputSheet.CleanPlayfield -> context.store.addEvent(
            machineID = context.selectedMachine.id,
            type = MachineEventType.playfieldCleaned,
            category = MachineEventCategory.service,
            summary = "Clean Playfield",
            occurredAtMs = occurredAtMs,
            notes = context.inputNotesDraft.ifBlank { null },
            consumablesUsed = context.inputConsumableDraft.ifBlank { null },
        )
        GameRoomInputSheet.SwapBalls -> context.store.addEvent(
            machineID = context.selectedMachine.id,
            type = MachineEventType.ballsReplaced,
            category = MachineEventCategory.service,
            summary = "Swap Balls",
            occurredAtMs = occurredAtMs,
            notes = context.inputNotesDraft.ifBlank { null },
        )
        GameRoomInputSheet.CheckPitch -> context.store.addEvent(
            machineID = context.selectedMachine.id,
            type = MachineEventType.pitchChecked,
            category = MachineEventCategory.service,
            summary = "Check Pitch",
            occurredAtMs = occurredAtMs,
            notes = context.inputNotesDraft.ifBlank { null },
            pitchValue = context.inputPitchValueDraft.toDoubleOrNull(),
            pitchMeasurementPoint = context.inputPitchPointDraft.ifBlank { null },
        )
        GameRoomInputSheet.LevelMachine -> context.store.addEvent(
            machineID = context.selectedMachine.id,
            type = MachineEventType.machineLeveled,
            category = MachineEventCategory.service,
            summary = "Level Machine",
            occurredAtMs = occurredAtMs,
            notes = context.inputNotesDraft.ifBlank { null },
        )
        GameRoomInputSheet.GeneralInspection -> context.store.addEvent(
            machineID = context.selectedMachine.id,
            type = MachineEventType.generalInspection,
            category = MachineEventCategory.service,
            summary = "General Inspection",
            occurredAtMs = occurredAtMs,
            notes = context.inputNotesDraft.ifBlank { null },
        )
        GameRoomInputSheet.LogIssue -> {
            val issueID = context.store.openIssue(
                machineID = context.selectedMachine.id,
                symptom = context.inputIssueSymptomDraft,
                severity = runCatching { MachineIssueSeverity.valueOf(context.inputIssueSeverityDraft) }.getOrDefault(MachineIssueSeverity.medium),
                subsystem = runCatching { MachineIssueSubsystem.valueOf(context.inputIssueSubsystemDraft) }.getOrDefault(MachineIssueSubsystem.other),
                openedAtMs = occurredAtMs,
                diagnosis = context.inputIssueDiagnosisDraft.ifBlank { null },
            )
            var lastAttachmentEventID: String? = null
            context.issueDraftAttachments.forEach { attachment ->
                lastAttachmentEventID = context.store.addEvent(
                    machineID = context.selectedMachine.id,
                    type = if (attachment.kind == MachineAttachmentKind.photo) MachineEventType.photoAdded else MachineEventType.videoAdded,
                    category = MachineEventCategory.media,
                    summary = if (attachment.kind == MachineAttachmentKind.photo) "Issue photo added" else "Issue video added",
                    occurredAtMs = occurredAtMs,
                    linkedIssueID = issueID,
                )
                context.store.addAttachment(
                    machineID = context.selectedMachine.id,
                    ownerType = MachineAttachmentOwnerType.issue,
                    ownerID = issueID,
                    kind = attachment.kind,
                    uri = attachment.uri,
                    caption = attachment.caption,
                )
            }
            if (lastAttachmentEventID != null) {
                context.onSelectedLogEventIDChange(lastAttachmentEventID)
                context.onMachineSubviewChange(GameRoomMachineSubview.Log)
            }
        }
        GameRoomInputSheet.ResolveIssue -> {
            val issueID = context.inputResolveIssueIDDraft
            if (!issueID.isNullOrBlank()) {
                context.store.resolveIssue(issueID, context.inputNotesDraft.ifBlank { null }, resolvedAtMs = occurredAtMs)
            }
        }
        GameRoomInputSheet.OwnershipUpdate -> {
            val type = runCatching { MachineEventType.valueOf(context.inputOwnershipTypeDraft) }.getOrDefault(MachineEventType.moved)
            context.store.addEvent(
                machineID = context.selectedMachine.id,
                type = type,
                category = MachineEventCategory.ownership,
                summary = context.inputSummaryDraft.ifBlank { type.name.replaceFirstChar { it.uppercase() } },
                occurredAtMs = occurredAtMs,
                notes = context.inputNotesDraft.ifBlank { null },
            )
        }
        GameRoomInputSheet.InstallMod -> context.store.addEvent(
            machineID = context.selectedMachine.id,
            type = MachineEventType.modInstalled,
            category = MachineEventCategory.mod,
            summary = context.inputSummaryDraft.ifBlank { "Install Mod" },
            occurredAtMs = occurredAtMs,
            notes = context.inputNotesDraft.ifBlank { null },
            partsUsed = context.inputDetailsDraft.ifBlank { null },
        )
        GameRoomInputSheet.ReplacePart -> context.store.addEvent(
            machineID = context.selectedMachine.id,
            type = MachineEventType.partReplaced,
            category = MachineEventCategory.service,
            summary = context.inputSummaryDraft.ifBlank { "Replace Part" },
            occurredAtMs = occurredAtMs,
            notes = context.inputNotesDraft.ifBlank { null },
            partsUsed = context.inputDetailsDraft.ifBlank { null },
        )
        GameRoomInputSheet.LogPlays -> context.store.addEvent(
            machineID = context.selectedMachine.id,
            type = MachineEventType.custom,
            category = MachineEventCategory.custom,
            summary = "Log Plays (Total ${context.inputPlayTotalDraft.toIntOrNull() ?: 0})",
            occurredAtMs = occurredAtMs,
            notes = context.inputNotesDraft.ifBlank { null },
            playCountAtEvent = context.inputPlayTotalDraft.toIntOrNull(),
        )
        GameRoomInputSheet.AddMedia -> {
            val kind = runCatching { MachineAttachmentKind.valueOf(context.inputMediaKindDraft) }.getOrDefault(MachineAttachmentKind.photo)
            val manualURI = context.inputMediaURIDraft.trim()
            if (manualURI.isNotBlank()) {
                val summary = if (kind == MachineAttachmentKind.photo) "Photo added" else "Video added"
                val eventID = context.store.addEvent(
                    machineID = context.selectedMachine.id,
                    type = if (kind == MachineAttachmentKind.photo) MachineEventType.photoAdded else MachineEventType.videoAdded,
                    category = MachineEventCategory.media,
                    summary = summary,
                    occurredAtMs = occurredAtMs,
                    notes = context.inputNotesDraft.ifBlank { null },
                )
                context.store.addAttachment(
                    machineID = context.selectedMachine.id,
                    ownerType = MachineAttachmentOwnerType.event,
                    ownerID = eventID,
                    kind = kind,
                    uri = manualURI,
                    caption = context.inputMediaCaptionDraft.ifBlank { null },
                )
            } else {
                context.onLaunchPendingMediaPicker(kind, occurredAtMs)
                resetGameRoomInputDrafts(context)
                return
            }
        }
    }

    resetGameRoomInputDrafts(context)
}

private fun resetGameRoomInputDrafts(context: GameRoomInputSheetContext) {
    context.onInputNotesDraftChange("")
    context.onInputConsumableDraftChange("")
    context.onInputPitchValueDraftChange("")
    context.onInputPitchPointDraftChange("")
    context.onInputIssueSymptomDraftChange("")
    context.onInputIssueDiagnosisDraftChange("")
    context.onInputSummaryDraftChange("")
    context.onInputDetailsDraftChange("")
    context.onInputMediaCaptionDraftChange("")
    context.onInputMediaKindDraftChange(MachineAttachmentKind.photo.name)
    context.onInputMediaURIDraftChange("")
    context.onIssueDraftAttachmentsChange(emptyList())
    context.onDismiss()
}

@Composable
private fun GameRoomIssueAttachmentDraftRow(
    attachment: IssueInputAttachmentDraft,
    onDelete: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = attachment.caption ?: attachment.uri,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        AppInlineActionChip(text = "Remove", onClick = onDelete, destructive = true)
    }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
private fun GameRoomEditEventSheet(context: GameRoomEditEventContext) {
    ModalBottomSheet(
        onDismissRequest = context.onDismiss,
        modifier = Modifier.dismissKeyboardOnTapOutside(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "Edit Log Entry",
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.SemiBold,
            )
            OutlinedTextField(
                value = context.editEventDateDraft,
                onValueChange = context.onEditEventDateDraftChange,
                label = { Text("Date (YYYY-MM-DD)") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            OutlinedTextField(
                value = context.editEventSummaryDraft,
                onValueChange = context.onEditEventSummaryDraftChange,
                label = { Text("Summary") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            OutlinedTextField(
                value = context.editEventNotesDraft,
                onValueChange = context.onEditEventNotesDraftChange,
                label = { Text("Notes") },
                modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                AppSecondaryButton(onClick = context.onDismiss) { Text("Cancel") }
                AppPrimaryButton(
                    onClick = {
                        val occurredAtMs = parseIsoDateMillis(context.editEventDateDraft) ?: System.currentTimeMillis()
                        context.store.updateEvent(
                            context.editingEventID,
                            occurredAtMs,
                            context.editEventSummaryDraft,
                            context.editEventNotesDraft,
                        )
                        context.onDismiss()
                    },
                    enabled = context.editEventSummaryDraft.isNotBlank(),
                ) {
                    Text("Save")
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
private fun GameRoomAttachmentPresentationHost(context: GameRoomAttachmentPresentationContext) {
    val mediaPreviewAttachment = context.mediaPreviewAttachment
    if (mediaPreviewAttachment != null) {
        MediaPreviewDialog(
            attachment = mediaPreviewAttachment,
            onClose = context.onClosePreview,
            onEdit = { context.onBeginAttachmentEdit(mediaPreviewAttachment) },
            onDelete = { context.onDeleteAttachment(mediaPreviewAttachment) },
        )
    }

    val editingAttachment = context.editingAttachment
    if (editingAttachment != null) {
        ModalBottomSheet(
            onDismissRequest = context.onDismissAttachmentEdit,
            modifier = Modifier.dismissKeyboardOnTapOutside(),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "Edit Media",
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.SemiBold,
                )
                OutlinedTextField(
                    value = context.editAttachmentCaptionDraft,
                    onValueChange = context.onEditAttachmentCaptionDraftChange,
                    label = { Text("Caption") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = context.editAttachmentNotesDraft,
                    onValueChange = context.onEditAttachmentNotesDraftChange,
                    label = { Text("Notes") },
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AppSecondaryButton(onClick = context.onDismissAttachmentEdit) { Text("Cancel") }
                    AppPrimaryButton(
                        onClick = {
                            context.store.updateAttachment(
                                id = editingAttachment.id,
                                caption = context.editAttachmentCaptionDraft,
                                notes = context.editAttachmentNotesDraft,
                            )
                            context.onDismissAttachmentEdit()
                        },
                    ) {
                        Text("Save")
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
    }
}
