package com.pillyliu.pinprofandroid.gameroom

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.ManagedActivityResultLauncher
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import java.util.UUID

internal data class GameRoomPendingMediaDraft(
    val machineID: String?,
    val ownerTypeName: String,
    val ownerID: String?,
    val occurredAtMs: Long?,
    val captionDraft: String,
    val notesDraft: String,
)

internal data class GameRoomMediaLaunchers(
    val addPhotoLauncher: ManagedActivityResultLauncher<Array<String>, Uri?>,
    val addVideoLauncher: ManagedActivityResultLauncher<Array<String>, Uri?>,
    val issuePhotoDraftLauncher: ManagedActivityResultLauncher<Array<String>, Uri?>,
    val issueVideoDraftLauncher: ManagedActivityResultLauncher<Array<String>, Uri?>,
)

@Composable
internal fun rememberGameRoomMediaLaunchers(
    context: Context,
    store: GameRoomStore,
    pendingMediaDraft: GameRoomPendingMediaDraft,
    onSelectedLogEventIDChange: (String?) -> Unit,
    onMachineSubviewChange: (GameRoomMachineSubview) -> Unit,
    onClearPendingMediaDraft: () -> Unit,
    issueDraftAttachments: List<IssueInputAttachmentDraft>,
    onIssueDraftAttachmentsChange: (List<IssueInputAttachmentDraft>) -> Unit,
): GameRoomMediaLaunchers {
    val addPhotoLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        handlePickedPendingMedia(
            context = context,
            uri = uri,
            kind = MachineAttachmentKind.photo,
            store = store,
            pendingMediaDraft = pendingMediaDraft,
            onSelectedLogEventIDChange = onSelectedLogEventIDChange,
            onMachineSubviewChange = onMachineSubviewChange,
            onClearPendingMediaDraft = onClearPendingMediaDraft,
        )
    }

    val addVideoLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        handlePickedPendingMedia(
            context = context,
            uri = uri,
            kind = MachineAttachmentKind.video,
            store = store,
            pendingMediaDraft = pendingMediaDraft,
            onSelectedLogEventIDChange = onSelectedLogEventIDChange,
            onMachineSubviewChange = onMachineSubviewChange,
            onClearPendingMediaDraft = onClearPendingMediaDraft,
        )
    }

    val issuePhotoDraftLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        handlePickedIssueDraftAttachment(
            context = context,
            uri = uri,
            kind = MachineAttachmentKind.photo,
            issueDraftAttachments = issueDraftAttachments,
            onIssueDraftAttachmentsChange = onIssueDraftAttachmentsChange,
        )
    }

    val issueVideoDraftLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        handlePickedIssueDraftAttachment(
            context = context,
            uri = uri,
            kind = MachineAttachmentKind.video,
            issueDraftAttachments = issueDraftAttachments,
            onIssueDraftAttachmentsChange = onIssueDraftAttachmentsChange,
        )
    }

    return GameRoomMediaLaunchers(
        addPhotoLauncher = addPhotoLauncher,
        addVideoLauncher = addVideoLauncher,
        issuePhotoDraftLauncher = issuePhotoDraftLauncher,
        issueVideoDraftLauncher = issueVideoDraftLauncher,
    )
}

private fun handlePickedPendingMedia(
    context: Context,
    uri: Uri?,
    kind: MachineAttachmentKind,
    store: GameRoomStore,
    pendingMediaDraft: GameRoomPendingMediaDraft,
    onSelectedLogEventIDChange: (String?) -> Unit,
    onMachineSubviewChange: (GameRoomMachineSubview) -> Unit,
    onClearPendingMediaDraft: () -> Unit,
) {
    val machineID = pendingMediaDraft.machineID
    if (uri != null && machineID != null) {
        runCatching {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }
        val caption = pendingMediaDraft.captionDraft.ifBlank {
            uri.lastPathSegment?.substringAfterLast('/')?.takeIf { it.isNotBlank() }.orEmpty()
        }.ifBlank { null }
        val notes = pendingMediaDraft.notesDraft.ifBlank { null }
        val occurredAtMs = pendingMediaDraft.occurredAtMs
        val ownerType = runCatching { MachineAttachmentOwnerType.valueOf(pendingMediaDraft.ownerTypeName) }
            .getOrDefault(MachineAttachmentOwnerType.event)
        val ownerID = pendingMediaDraft.ownerID
        var timelineEventID: String? = null
        val resolvedOwnerID = if (ownerType == MachineAttachmentOwnerType.issue && !ownerID.isNullOrBlank()) {
            ownerID
        } else {
            store.addEvent(
                machineID = machineID,
                type = if (kind == MachineAttachmentKind.photo) MachineEventType.photoAdded else MachineEventType.videoAdded,
                category = MachineEventCategory.media,
                summary = if (kind == MachineAttachmentKind.photo) "Photo added" else "Video added",
                occurredAtMs = occurredAtMs,
                notes = notes,
            ).also { timelineEventID = it }
        }
        if (ownerType == MachineAttachmentOwnerType.issue && !ownerID.isNullOrBlank()) {
            timelineEventID = store.addEvent(
                machineID = machineID,
                type = if (kind == MachineAttachmentKind.photo) MachineEventType.photoAdded else MachineEventType.videoAdded,
                category = MachineEventCategory.media,
                summary = if (kind == MachineAttachmentKind.photo) "Issue photo added" else "Issue video added",
                occurredAtMs = occurredAtMs,
                notes = notes,
                linkedIssueID = ownerID,
            )
        }
        store.addAttachment(
            machineID = machineID,
            ownerType = ownerType,
            ownerID = resolvedOwnerID,
            kind = kind,
            uri = uri.toString(),
            caption = caption,
        )
        onSelectedLogEventIDChange(timelineEventID)
        onMachineSubviewChange(GameRoomMachineSubview.Log)
    }
    onClearPendingMediaDraft()
}

private fun handlePickedIssueDraftAttachment(
    context: Context,
    uri: Uri?,
    kind: MachineAttachmentKind,
    issueDraftAttachments: List<IssueInputAttachmentDraft>,
    onIssueDraftAttachmentsChange: (List<IssueInputAttachmentDraft>) -> Unit,
) {
    if (uri != null) {
        runCatching {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }
        val caption = uri.lastPathSegment?.substringAfterLast('/')?.takeIf { it.isNotBlank() }
        onIssueDraftAttachmentsChange(
            issueDraftAttachments + IssueInputAttachmentDraft(
                id = UUID.randomUUID().toString(),
                kind = kind,
                uri = uri.toString(),
                caption = caption,
            ),
        )
    }
}
