package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil.compose.AsyncImage
import com.pillyliu.pinprofandroid.practice.StyledPracticeJournalSummaryText
import com.pillyliu.pinprofandroid.practice.formatTimestamp
import com.pillyliu.pinprofandroid.ui.AppFullscreenActionButton
import com.pillyliu.pinprofandroid.ui.AppFullscreenStatusOverlay
import com.pillyliu.pinprofandroid.ui.AppMediaPreviewPlaceholder
import com.pillyliu.pinprofandroid.ui.AppSwipeActionRow
import com.pillyliu.pinprofandroid.ui.AppSwipeActionSpec
import com.pillyliu.pinprofandroid.ui.iosEdgeSwipeBack

@Composable
internal fun GameRoomLogRow(
    event: MachineEvent,
    mediaCount: Int,
    selected: Boolean,
    onSelect: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    AppSwipeActionRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 6.dp, vertical = 4.dp)
            .defaultMinSize(minHeight = 40.dp)
            .clip(RoundedCornerShape(8.dp)),
        shape = RoundedCornerShape(8.dp),
        startAction = AppSwipeActionSpec(
            tint = Color(0xFF0A84FF),
            icon = Icons.Outlined.Edit,
            contentDescription = "Edit entry",
            onTrigger = onEdit,
        ),
        endAction = AppSwipeActionSpec(
            tint = Color(0xFFFF3B30),
            icon = Icons.Outlined.Delete,
            contentDescription = "Delete entry",
            onTrigger = onDelete,
        ),
    ) {
        Row(
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    if (selected) {
                        MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.35f)
                    } else {
                        Color.Transparent
                    },
                    RoundedCornerShape(8.dp),
                )
                .clickable(onClick = onSelect)
                .padding(horizontal = 8.dp, vertical = 4.dp),
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                StyledPracticeJournalSummaryText(
                    summary = event.summary,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    text = "${displayMachineEventCategory(event.category)} • ${formatTimestamp(event.occurredAtMs)} • $mediaCount media",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
internal fun MediaAttachmentGrid(
    attachments: List<MachineAttachment>,
    onOpen: (MachineAttachment) -> Unit,
) {
    val rows = attachments.chunked(2)
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        rows.forEach { rowItems ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                rowItems.forEach { attachment ->
                    var imageLoaded by remember(attachment.id) { mutableStateOf(false) }
                    var showMissingImage by remember(attachment.id) { mutableStateOf(attachment.uri.isBlank()) }
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(10.dp))
                            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(10.dp))
                            .clickable { onOpen(attachment) },
                    ) {
                        if (attachment.uri.isNotBlank()) {
                            AsyncImage(
                                model = attachment.uri,
                                contentDescription = attachment.caption ?: "Media attachment",
                                contentScale = ContentScale.Crop,
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(10.dp)),
                                onLoading = {
                                    imageLoaded = false
                                    showMissingImage = false
                                },
                                onSuccess = {
                                    imageLoaded = true
                                    showMissingImage = false
                                },
                                onError = {
                                    imageLoaded = false
                                    showMissingImage = true
                                },
                            )
                        }
                        when {
                            attachment.uri.isBlank() -> AppMediaPreviewPlaceholder(message = "No image")
                            !imageLoaded && !showMissingImage -> AppMediaPreviewPlaceholder(showsProgress = true)
                            showMissingImage -> AppMediaPreviewPlaceholder()
                        }
                        Text(
                            text = if (attachment.kind == MachineAttachmentKind.video) "Video" else "Photo",
                            color = Color.White,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier
                                .padding(6.dp)
                                .background(Color.Black.copy(alpha = 0.45f), RoundedCornerShape(999.dp))
                                .padding(horizontal = 8.dp, vertical = 2.dp),
                        )
                    }
                }
                if (rowItems.size == 1) {
                    Box(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
internal fun MediaPreviewDialog(
    attachment: MachineAttachment,
    onClose: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    var controlsVisible by remember { mutableStateOf(true) }
    var scale by remember { mutableFloatStateOf(1f) }
    var offsetX by remember { mutableFloatStateOf(0f) }
    var offsetY by remember { mutableFloatStateOf(0f) }
    var imageLoaded by remember(attachment.id) { mutableStateOf(false) }
    var showMissingImage by remember(attachment.id) { mutableStateOf(attachment.uri.isBlank()) }

    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .iosEdgeSwipeBack(enabled = true, onBack = onClose)
                .clipToBounds()
                .pointerInput(attachment.id) {
                    detectTapGestures(
                        onDoubleTap = {
                            if (scale > 1.05f) {
                                scale = 1f
                                offsetX = 0f
                                offsetY = 0f
                            } else {
                                scale = 2f
                            }
                        },
                        onTap = { controlsVisible = !controlsVisible },
                    )
                }
                .pointerInput(attachment.id) {
                    detectTransformGestures { _, pan, zoom, _ ->
                        val nextScale = (scale * zoom).coerceIn(1f, 4f)
                        scale = nextScale
                        if (nextScale <= 1.01f) {
                            offsetX = 0f
                            offsetY = 0f
                        } else {
                            offsetX += pan.x
                            offsetY += pan.y
                        }
                    }
                },
        ) {
            if (attachment.uri.isNotBlank()) {
                AsyncImage(
                    model = attachment.uri,
                    contentDescription = attachment.caption ?: "Media preview",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .fillMaxSize()
                        .graphicsLayer(
                            scaleX = scale,
                            scaleY = scale,
                            translationX = offsetX,
                            translationY = offsetY,
                        ),
                    onLoading = {
                        imageLoaded = false
                        showMissingImage = false
                    },
                    onSuccess = {
                        imageLoaded = true
                        showMissingImage = false
                    },
                    onError = {
                        imageLoaded = false
                        showMissingImage = true
                    },
                )
            }

            when {
                attachment.uri.isBlank() -> AppFullscreenStatusOverlay(text = "Media unavailable")
                !imageLoaded && !showMissingImage -> AppFullscreenStatusOverlay(text = "Loading media…", showsProgress = true, foregroundColor = Color.White.copy(alpha = 0.9f))
                showMissingImage -> AppFullscreenStatusOverlay(text = "Media unavailable")
            }

            if (controlsVisible) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    AppFullscreenActionButton(text = "Back", onClick = onClose)
                    AppFullscreenActionButton(text = "Edit", onClick = onEdit)
                    AppFullscreenActionButton(text = "Delete", onClick = onDelete, destructive = true)
                }
                if (!attachment.caption.isNullOrBlank()) {
                    Text(
                        text = attachment.caption,
                        color = Color.White,
                        modifier = Modifier
                            .align(Alignment.BottomStart)
                            .padding(14.dp)
                            .background(Color.Black.copy(alpha = 0.45f), RoundedCornerShape(10.dp))
                            .padding(horizontal = 10.dp, vertical = 6.dp),
                    )
                }
            }
        }
    }
}
