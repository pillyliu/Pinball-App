package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
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
            GameRoomInputSheetFormBody(
                context = context,
                openIssues = openIssues,
            )
        }
    }
}
