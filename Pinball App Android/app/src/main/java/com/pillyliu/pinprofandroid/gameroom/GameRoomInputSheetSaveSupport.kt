package com.pillyliu.pinprofandroid.gameroom

internal fun saveGameRoomInputSheet(context: GameRoomInputSheetContext) {
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

internal fun resetGameRoomInputDrafts(context: GameRoomInputSheetContext) {
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
