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
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.dismissKeyboardOnTapOutside

@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun GameRoomEditEventSheet(context: GameRoomEditEventContext) {
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
internal fun GameRoomAttachmentPresentationHost(context: GameRoomAttachmentPresentationContext) {
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
