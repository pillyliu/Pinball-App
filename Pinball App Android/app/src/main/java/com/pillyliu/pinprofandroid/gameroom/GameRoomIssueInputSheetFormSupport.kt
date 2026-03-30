package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppInlineActionChip
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.DropdownOption

@Composable
internal fun GameRoomIssueInputFields(
    context: GameRoomInputSheetContext,
    openIssues: List<MachineIssue>,
) {
    when (context.selectedSheet) {
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

        else -> Unit
    }
}

@Composable
internal fun GameRoomIssueAttachmentDraftRow(
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
