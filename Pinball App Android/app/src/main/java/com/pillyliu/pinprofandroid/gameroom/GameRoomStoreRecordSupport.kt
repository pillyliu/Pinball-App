package com.pillyliu.pinprofandroid.gameroom

internal data class GameRoomIssueMutationResult(
    val state: GameRoomPersistedState,
    val issueId: String,
)

internal fun gameRoomStateWithAddedEvent(
    state: GameRoomPersistedState,
    machineID: String,
    type: MachineEventType,
    category: MachineEventCategory,
    summary: String,
    occurredAtMs: Long?,
    notes: String?,
    partsUsed: String?,
    consumablesUsed: String?,
    pitchValue: Double?,
    pitchMeasurementPoint: String?,
    playCountAtEvent: Int?,
    linkedIssueID: String?,
    now: Long,
): Pair<GameRoomPersistedState, String> {
    val occurredAt = occurredAtMs ?: now
    val event = MachineEvent(
        ownedMachineID = machineID,
        type = type,
        category = category,
        occurredAtMs = occurredAt,
        playCountAtEvent = playCountAtEvent,
        summary = summary.trim().ifBlank { "Event" },
        notes = normalizeOptionalGameRoomString(notes),
        partsUsed = normalizeOptionalGameRoomString(partsUsed),
        consumablesUsed = normalizeOptionalGameRoomString(consumablesUsed),
        pitchValue = pitchValue,
        pitchMeasurementPoint = normalizeOptionalGameRoomString(pitchMeasurementPoint),
        linkedIssueID = normalizeOptionalGameRoomString(linkedIssueID),
        createdAtMs = now,
        updatedAtMs = now,
    )
    return state.copy(events = state.events + event) to event.id
}

internal fun gameRoomStateWithUpdatedEvent(
    state: GameRoomPersistedState,
    id: String,
    occurredAtMs: Long,
    summary: String,
    notes: String?,
    now: Long,
): GameRoomPersistedState {
    return state.copy(
        events = state.events.map { event ->
            if (event.id != id) return@map event
            event.copy(
                occurredAtMs = occurredAtMs,
                summary = summary.trim().ifBlank { "Event" },
                notes = normalizeOptionalGameRoomString(notes),
                updatedAtMs = now,
            )
        },
    )
}

internal fun gameRoomStateWithDeletedEvent(
    state: GameRoomPersistedState,
    id: String,
): GameRoomPersistedState {
    return state.copy(
        events = state.events.filterNot { it.id == id },
        attachments = state.attachments.filterNot {
            it.ownerType == MachineAttachmentOwnerType.event && it.ownerID == id
        },
    )
}

internal fun gameRoomAttachmentsForMachine(
    state: GameRoomPersistedState,
    machineID: String,
): List<MachineAttachment> {
    return state.attachments
        .filter { it.ownedMachineID == machineID }
        .sortedByDescending { it.createdAtMs }
}

internal fun gameRoomAttachmentsForEvent(
    state: GameRoomPersistedState,
    eventID: String,
): List<MachineAttachment> {
    return state.attachments
        .filter { it.ownerType == MachineAttachmentOwnerType.event && it.ownerID == eventID }
        .sortedByDescending { it.createdAtMs }
}

internal fun gameRoomAttachmentsForIssue(
    state: GameRoomPersistedState,
    issueID: String,
): List<MachineAttachment> {
    return state.attachments
        .filter { it.ownerType == MachineAttachmentOwnerType.issue && it.ownerID == issueID }
        .sortedByDescending { it.createdAtMs }
}

internal fun gameRoomStateWithAddedAttachment(
    state: GameRoomPersistedState,
    machineID: String,
    ownerType: MachineAttachmentOwnerType,
    ownerID: String,
    kind: MachineAttachmentKind,
    uri: String,
    thumbnailURI: String?,
    caption: String?,
): Pair<GameRoomPersistedState, String>? {
    val normalizedURI = uri.trim()
    if (normalizedURI.isBlank()) return null
    val attachment = MachineAttachment(
        ownedMachineID = machineID,
        ownerType = ownerType,
        ownerID = ownerID,
        kind = kind,
        uri = normalizedURI,
        thumbnailURI = normalizeOptionalGameRoomString(thumbnailURI),
        caption = normalizeOptionalGameRoomString(caption),
    )
    return state.copy(attachments = state.attachments + attachment) to attachment.id
}

internal fun gameRoomStateWithDeletedAttachment(
    state: GameRoomPersistedState,
    id: String,
): GameRoomPersistedState {
    return state.copy(attachments = state.attachments.filterNot { it.id == id })
}

internal fun gameRoomStateWithUpdatedAttachment(
    state: GameRoomPersistedState,
    id: String,
    caption: String?,
    notes: String?,
    now: Long,
): GameRoomPersistedState? {
    val attachment = state.attachments.firstOrNull { it.id == id } ?: return null
    return state.copy(
        attachments = state.attachments.map { current ->
            if (current.id != id) current else current.copy(caption = normalizeOptionalGameRoomString(caption))
        },
        events = if (attachment.ownerType == MachineAttachmentOwnerType.event) {
            state.events.map { event ->
                if (event.id != attachment.ownerID) event else event.copy(
                    notes = normalizeOptionalGameRoomString(notes),
                    updatedAtMs = now,
                )
            }
        } else {
            state.events
        },
    )
}

internal fun gameRoomStateWithDeletedAttachmentAndLinkedEvent(
    state: GameRoomPersistedState,
    id: String,
): GameRoomPersistedState? {
    val attachment = state.attachments.firstOrNull { it.id == id } ?: return null
    var nextAttachments = state.attachments.filterNot { it.id == id }
    var nextEvents = state.events
    if (attachment.ownerType == MachineAttachmentOwnerType.event) {
        nextEvents = nextEvents.filterNot { it.id == attachment.ownerID }
        nextAttachments = nextAttachments.filterNot {
            it.ownerType == MachineAttachmentOwnerType.event && it.ownerID == attachment.ownerID
        }
    }
    return state.copy(
        attachments = nextAttachments,
        events = nextEvents,
    )
}

internal fun gameRoomStateWithOpenedIssue(
    state: GameRoomPersistedState,
    machineID: String,
    symptom: String,
    severity: MachineIssueSeverity,
    subsystem: MachineIssueSubsystem,
    openedAtMs: Long?,
    diagnosis: String?,
    now: Long,
): GameRoomIssueMutationResult {
    val openedAt = openedAtMs ?: now
    val issue = MachineIssue(
        ownedMachineID = machineID,
        status = MachineIssueStatus.open,
        severity = severity,
        subsystem = subsystem,
        symptom = symptom.trim().ifBlank { "Issue" },
        diagnosis = normalizeOptionalGameRoomString(diagnosis),
        openedAtMs = openedAt,
        createdAtMs = now,
        updatedAtMs = now,
    )
    val (nextState, _) = gameRoomStateWithAddedEvent(
        state = state.copy(issues = state.issues + issue),
        machineID = machineID,
        type = MachineEventType.issueOpened,
        category = MachineEventCategory.issue,
        summary = "Issue opened: ${issue.symptom}",
        occurredAtMs = openedAt,
        notes = diagnosis,
        partsUsed = null,
        consumablesUsed = null,
        pitchValue = null,
        pitchMeasurementPoint = null,
        playCountAtEvent = null,
        linkedIssueID = issue.id,
        now = now,
    )
    return GameRoomIssueMutationResult(
        state = nextState,
        issueId = issue.id,
    )
}

internal fun gameRoomStateWithResolvedIssue(
    state: GameRoomPersistedState,
    issueID: String,
    resolution: String?,
    resolvedAtMs: Long?,
    now: Long,
): GameRoomPersistedState? {
    val issue = state.issues.firstOrNull { it.id == issueID } ?: return null
    val resolvedAt = resolvedAtMs ?: now
    val issueState = state.copy(
        issues = state.issues.map { current ->
            if (current.id != issueID) return@map current
            current.copy(
                status = MachineIssueStatus.resolved,
                resolvedAtMs = resolvedAt,
                resolution = normalizeOptionalGameRoomString(resolution),
                updatedAtMs = now,
            )
        },
    )
    val (nextState, _) = gameRoomStateWithAddedEvent(
        state = issueState,
        machineID = issue.ownedMachineID,
        type = MachineEventType.issueResolved,
        category = MachineEventCategory.issue,
        summary = "Issue resolved: ${issue.symptom}",
        occurredAtMs = resolvedAt,
        notes = resolution,
        partsUsed = null,
        consumablesUsed = null,
        pitchValue = null,
        pitchMeasurementPoint = null,
        playCountAtEvent = null,
        linkedIssueID = issueID,
        now = now,
    )
    return nextState
}
