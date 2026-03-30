package com.pillyliu.pinprofandroid.gameroom

internal fun buildGameRoomInputSheetContext(
    store: GameRoomStore,
    selectedMachine: OwnedMachine?,
    selectedSheet: GameRoomInputSheet?,
    inputDateDraft: String,
    onInputDateDraftChange: (String) -> Unit,
    inputNotesDraft: String,
    onInputNotesDraftChange: (String) -> Unit,
    inputConsumableDraft: String,
    onInputConsumableDraftChange: (String) -> Unit,
    inputPitchValueDraft: String,
    onInputPitchValueDraftChange: (String) -> Unit,
    inputPitchPointDraft: String,
    onInputPitchPointDraftChange: (String) -> Unit,
    inputIssueSymptomDraft: String,
    onInputIssueSymptomDraftChange: (String) -> Unit,
    inputIssueSeverityDraft: String,
    onInputIssueSeverityDraftChange: (String) -> Unit,
    inputIssueSubsystemDraft: String,
    onInputIssueSubsystemDraftChange: (String) -> Unit,
    inputIssueDiagnosisDraft: String,
    onInputIssueDiagnosisDraftChange: (String) -> Unit,
    inputResolveIssueIDDraft: String?,
    onInputResolveIssueIDDraftChange: (String?) -> Unit,
    inputOwnershipTypeDraft: String,
    onInputOwnershipTypeDraftChange: (String) -> Unit,
    inputSummaryDraft: String,
    onInputSummaryDraftChange: (String) -> Unit,
    inputDetailsDraft: String,
    onInputDetailsDraftChange: (String) -> Unit,
    inputPlayTotalDraft: String,
    onInputPlayTotalDraftChange: (String) -> Unit,
    inputMediaKindDraft: String,
    onInputMediaKindDraftChange: (String) -> Unit,
    inputMediaURIDraft: String,
    onInputMediaURIDraftChange: (String) -> Unit,
    inputMediaCaptionDraft: String,
    onInputMediaCaptionDraftChange: (String) -> Unit,
    issueDraftAttachments: List<IssueInputAttachmentDraft>,
    onIssueDraftAttachmentsChange: (List<IssueInputAttachmentDraft>) -> Unit,
    mediaLaunchers: GameRoomMediaLaunchers,
    onPendingMediaMachineIDChange: (String?) -> Unit,
    onPendingMediaOwnerTypeChange: (String) -> Unit,
    onPendingMediaOwnerIDChange: (String?) -> Unit,
    onPendingMediaOccurredAtMsChange: (Long?) -> Unit,
    onPendingMediaCaptionDraftChange: (String) -> Unit,
    onPendingMediaNotesDraftChange: (String) -> Unit,
    onSelectedLogEventIDChange: (String?) -> Unit,
    onMachineSubviewChange: (GameRoomMachineSubview) -> Unit,
    onActiveInputSheetChange: (GameRoomInputSheet?) -> Unit,
): GameRoomInputSheetContext? {
    val resolvedMachine = selectedMachine ?: return null
    val resolvedSheet = selectedSheet ?: return null
    return GameRoomInputSheetContext(
        store = store,
        selectedMachine = resolvedMachine,
        selectedSheet = resolvedSheet,
        inputDateDraft = inputDateDraft,
        onInputDateDraftChange = onInputDateDraftChange,
        inputNotesDraft = inputNotesDraft,
        onInputNotesDraftChange = onInputNotesDraftChange,
        inputConsumableDraft = inputConsumableDraft,
        onInputConsumableDraftChange = onInputConsumableDraftChange,
        inputPitchValueDraft = inputPitchValueDraft,
        onInputPitchValueDraftChange = onInputPitchValueDraftChange,
        inputPitchPointDraft = inputPitchPointDraft,
        onInputPitchPointDraftChange = onInputPitchPointDraftChange,
        inputIssueSymptomDraft = inputIssueSymptomDraft,
        onInputIssueSymptomDraftChange = onInputIssueSymptomDraftChange,
        inputIssueSeverityDraft = inputIssueSeverityDraft,
        onInputIssueSeverityDraftChange = onInputIssueSeverityDraftChange,
        inputIssueSubsystemDraft = inputIssueSubsystemDraft,
        onInputIssueSubsystemDraftChange = onInputIssueSubsystemDraftChange,
        inputIssueDiagnosisDraft = inputIssueDiagnosisDraft,
        onInputIssueDiagnosisDraftChange = onInputIssueDiagnosisDraftChange,
        inputResolveIssueIDDraft = inputResolveIssueIDDraft,
        onInputResolveIssueIDDraftChange = onInputResolveIssueIDDraftChange,
        inputOwnershipTypeDraft = inputOwnershipTypeDraft,
        onInputOwnershipTypeDraftChange = onInputOwnershipTypeDraftChange,
        inputSummaryDraft = inputSummaryDraft,
        onInputSummaryDraftChange = onInputSummaryDraftChange,
        inputDetailsDraft = inputDetailsDraft,
        onInputDetailsDraftChange = onInputDetailsDraftChange,
        inputPlayTotalDraft = inputPlayTotalDraft,
        onInputPlayTotalDraftChange = onInputPlayTotalDraftChange,
        inputMediaKindDraft = inputMediaKindDraft,
        onInputMediaKindDraftChange = onInputMediaKindDraftChange,
        inputMediaURIDraft = inputMediaURIDraft,
        onInputMediaURIDraftChange = onInputMediaURIDraftChange,
        inputMediaCaptionDraft = inputMediaCaptionDraft,
        onInputMediaCaptionDraftChange = onInputMediaCaptionDraftChange,
        issueDraftAttachments = issueDraftAttachments,
        onIssueDraftAttachmentsChange = onIssueDraftAttachmentsChange,
        onLaunchIssuePhotoPicker = { mediaLaunchers.issuePhotoDraftLauncher.launch(arrayOf("image/*")) },
        onLaunchIssueVideoPicker = { mediaLaunchers.issueVideoDraftLauncher.launch(arrayOf("video/*")) },
        onLaunchPendingMediaPicker = { kind, occurredAtMs ->
            onPendingMediaMachineIDChange(resolvedMachine.id)
            onPendingMediaOwnerTypeChange(MachineAttachmentOwnerType.event.name)
            onPendingMediaOwnerIDChange(null)
            onPendingMediaOccurredAtMsChange(occurredAtMs)
            onPendingMediaCaptionDraftChange(inputMediaCaptionDraft)
            onPendingMediaNotesDraftChange(inputNotesDraft)
            onActiveInputSheetChange(null)
            if (kind == MachineAttachmentKind.photo) {
                mediaLaunchers.addPhotoLauncher.launch(arrayOf("image/*"))
            } else {
                mediaLaunchers.addVideoLauncher.launch(arrayOf("video/*"))
            }
        },
        onSelectedLogEventIDChange = onSelectedLogEventIDChange,
        onMachineSubviewChange = onMachineSubviewChange,
        onDismiss = { onActiveInputSheetChange(null) },
    )
}

internal fun buildGameRoomEditEventContext(
    store: GameRoomStore,
    editingEventID: String?,
    editEventDateDraft: String,
    onEditEventDateDraftChange: (String) -> Unit,
    editEventSummaryDraft: String,
    onEditEventSummaryDraftChange: (String) -> Unit,
    editEventNotesDraft: String,
    onEditEventNotesDraftChange: (String) -> Unit,
    onEditingEventIDChange: (String?) -> Unit,
): GameRoomEditEventContext? {
    val eventID = editingEventID ?: return null
    return GameRoomEditEventContext(
        store = store,
        editingEventID = eventID,
        editEventDateDraft = editEventDateDraft,
        onEditEventDateDraftChange = onEditEventDateDraftChange,
        editEventSummaryDraft = editEventSummaryDraft,
        onEditEventSummaryDraftChange = onEditEventSummaryDraftChange,
        editEventNotesDraft = editEventNotesDraft,
        onEditEventNotesDraftChange = onEditEventNotesDraftChange,
        onDismiss = { onEditingEventIDChange(null) },
    )
}

internal fun buildGameRoomAttachmentPresentationContext(
    store: GameRoomStore,
    mediaPreviewAttachmentID: String?,
    editingAttachmentID: String?,
    editAttachmentCaptionDraft: String,
    onEditAttachmentCaptionDraftChange: (String) -> Unit,
    editAttachmentNotesDraft: String,
    onEditAttachmentNotesDraftChange: (String) -> Unit,
    onMediaPreviewAttachmentIDChange: (String?) -> Unit,
    onEditingAttachmentIDChange: (String?) -> Unit,
): GameRoomAttachmentPresentationContext {
    val attachments = store.state.attachments
    val mediaPreviewAttachment = mediaPreviewAttachmentID?.let { id -> attachments.firstOrNull { it.id == id } }
    val editingAttachment = editingAttachmentID?.let { id -> attachments.firstOrNull { it.id == id } }

    return GameRoomAttachmentPresentationContext(
        store = store,
        mediaPreviewAttachment = mediaPreviewAttachment,
        editingAttachment = editingAttachment,
        editAttachmentCaptionDraft = editAttachmentCaptionDraft,
        onEditAttachmentCaptionDraftChange = onEditAttachmentCaptionDraftChange,
        editAttachmentNotesDraft = editAttachmentNotesDraft,
        onEditAttachmentNotesDraftChange = onEditAttachmentNotesDraftChange,
        onClosePreview = { onMediaPreviewAttachmentIDChange(null) },
        onBeginAttachmentEdit = { attachment ->
            onEditingAttachmentIDChange(attachment.id)
            onEditAttachmentCaptionDraftChange(attachment.caption.orEmpty())
            onEditAttachmentNotesDraftChange(
                if (attachment.ownerType == MachineAttachmentOwnerType.event) {
                    store.state.events.firstOrNull { it.id == attachment.ownerID }?.notes.orEmpty()
                } else {
                    ""
                },
            )
        },
        onDeleteAttachment = { attachment ->
            store.deleteAttachmentAndLinkedEvent(attachment.id)
            onMediaPreviewAttachmentIDChange(null)
        },
        onDismissAttachmentEdit = { onEditingAttachmentIDChange(null) },
    )
}
