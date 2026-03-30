package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.DropdownOption

@Composable
internal fun GameRoomMachineEventInputFields(context: GameRoomInputSheetContext) {
    when (context.selectedSheet) {
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

        else -> Unit
    }
}
