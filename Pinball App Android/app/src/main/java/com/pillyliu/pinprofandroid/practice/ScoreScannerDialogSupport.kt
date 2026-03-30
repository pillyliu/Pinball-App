package com.pillyliu.pinprofandroid.practice

import android.graphics.RectF
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton

@Composable
internal fun ScoreScannerCameraPreview(
    hasCameraPermission: Boolean,
    isFrozen: Boolean,
    onPreviewViewReady: (PreviewView) -> Unit,
) {
    if (!hasCameraPermission) return
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { viewContext ->
            PreviewView(viewContext).apply {
                implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                scaleType = PreviewView.ScaleType.FILL_CENTER
                alpha = 1f
                onPreviewViewReady(this)
            }
        },
        update = {
            it.alpha = if (isFrozen) 0f else 1f
            onPreviewViewReady(it)
        },
    )
}

@Composable
internal fun ScoreScannerClosePill(
    modifier: Modifier = Modifier,
    onClose: () -> Unit,
) {
    AppSecondaryButton(
        onClick = onClose,
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 10.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.Close,
            contentDescription = null,
        )
        Text(
            text = "Close",
            modifier = Modifier.padding(start = 8.dp),
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
internal fun ScoreScannerTargetStage(
    modifier: Modifier,
    controller: ScoreScannerController,
) {
    val stageShape = RoundedCornerShape(28.dp)
    Box(
        modifier = modifier
            .clip(stageShape)
            .background(Color.Black.copy(alpha = if (controller.isFrozen) 0.58f else 0.18f))
            .border(2.dp, Color.White.copy(alpha = 0.9f), stageShape),
    ) {
        controller.frozenPreviewBitmap?.let { bitmap ->
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = "Frozen score preview",
                modifier = Modifier.fillMaxSize(),
            )
        }
        ScoreScannerCandidateHighlightsOverlay(
            candidates = controller.candidateHighlights,
            modifier = Modifier.fillMaxSize(),
        )
    }
}

@Composable
internal fun ScoreScannerCandidateHighlightsOverlay(
    candidates: List<ScoreScannerCandidate>,
    modifier: Modifier = Modifier,
) {
    BoxWithConstraints(modifier = modifier) {
        candidates.take(3).forEachIndexed { index, candidate ->
            val x = maxWidth * candidate.boundingBox.left
            val y = maxHeight * candidate.boundingBox.top
            val width = maxWidth * candidate.boundingBox.width()
            val height = maxHeight * candidate.boundingBox.height()
            val labelY = maxOf(y - 34.dp, 8.dp)

            Box(
                modifier = Modifier
                    .offset(x = x, y = y)
                    .width(width)
                    .height(height)
                    .border(
                        width = 2.dp,
                        color = Color(0xFF2FE36E),
                        shape = RoundedCornerShape(16.dp),
                    ),
            )

            if (index == 0) {
                Box(
                    modifier = Modifier
                        .offset(x = x, y = labelY)
                        .clip(RoundedCornerShape(999.dp))
                        .background(Color(0xFF2FE36E))
                        .padding(horizontal = 14.dp, vertical = 6.dp),
                ) {
                    Text(
                        text = candidate.formattedScore,
                        color = Color.Black,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
    }
}

@Composable
internal fun ScoreScannerHeader(
    modifier: Modifier = Modifier,
) {
    Text(
        text = "Align the score display inside the box",
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        color = Color.White,
        textAlign = TextAlign.Center,
        modifier = modifier.padding(horizontal = 24.dp),
    )
}

@Composable
internal fun ScoreScannerLiveReadingPanel(
    modifier: Modifier = Modifier,
    controller: ScoreScannerController,
) {
    val statusColor = when (controller.status) {
        ScoreScannerStatus.StableCandidate -> Color(0xFFF4D35E)
        ScoreScannerStatus.Locked -> Color(0xFF2FE36E)
        ScoreScannerStatus.FailedNoReading -> Color(0xFFFFB86B)
        ScoreScannerStatus.CameraPermissionRequired,
        ScoreScannerStatus.CameraUnavailable -> Color(0xFFFF8080)
        ScoreScannerStatus.Searching,
        ScoreScannerStatus.Reading -> Color.White
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clickable(
                enabled = controller.liveCandidateReading != null && !controller.isFrozen,
                onClick = controller::freezeDisplayedCandidate,
            )
            .clip(RoundedCornerShape(24.dp))
            .background(Color.Black.copy(alpha = 0.44f))
            .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(24.dp))
            .padding(horizontal = 18.dp, vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = controller.status.title.uppercase(),
            color = statusColor,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = controller.liveReadingText,
            color = Color.White,
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
        )
        Text(
            text = controller.status.detail,
            color = Color.White.copy(alpha = 0.72f),
            style = MaterialTheme.typography.bodySmall,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
internal fun ScoreScannerControls(
    zoomFactor: Float,
    availableZoomRange: ClosedFloatingPointRange<Float>,
    onSetZoom: (Float) -> Unit,
    onFreeze: () -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            AppSecondaryButton(
                onClick = { onSetZoom(availableZoomRange.start) },
                modifier = Modifier.weight(1f),
            ) {
                Text("1x", fontWeight = FontWeight.SemiBold)
            }
            AppSecondaryButton(
                onClick = { onSetZoom(minOf(8f, availableZoomRange.endInclusive)) },
                modifier = Modifier.weight(1f),
                enabled = availableZoomRange.endInclusive >= 8f,
            ) {
                Text("8x", fontWeight = FontWeight.SemiBold)
            }
            AppSecondaryButton(
                onClick = onFreeze,
                modifier = Modifier.weight(1f),
            ) {
                Text("Freeze", fontWeight = FontWeight.SemiBold)
            }
        }

        Column(
            modifier = Modifier
                .clip(RoundedCornerShape(22.dp))
                .background(Color.Black.copy(alpha = 0.44f))
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Zoom",
                    color = Color.White.copy(alpha = 0.72f),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = String.format("%.1fx", zoomFactor),
                    color = Color.White.copy(alpha = 0.72f),
                    style = MaterialTheme.typography.labelMedium,
                    fontFamily = FontFamily.Monospace,
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.End,
                )
            }
            Slider(
                value = zoomFactor,
                onValueChange = onSetZoom,
                valueRange = availableZoomRange,
            )
        }
    }
}

@Composable
internal fun ScoreScannerConfirmationSheet(
    controller: ScoreScannerController,
    onUseReading: () -> Unit,
    onRetake: () -> Unit,
) {
    val focusManager = LocalFocusManager.current
    val focusRequester = remember { FocusRequester() }
    val rawReadingText = controller.rawReadingText.ifBlank { controller.lockedReading?.rawText.orEmpty() }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(30.dp))
            .background(Color(0xE81B1B1F))
            .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(30.dp))
            .padding(horizontal = 18.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            text = if (controller.status == ScoreScannerStatus.Locked) "Locked score" else "Confirm score",
            color = Color.White,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = controller.lockedReading?.formattedScore
                ?: controller.confirmationText.ifBlank { "No reading yet" },
            color = Color.White,
            style = MaterialTheme.typography.displayMedium,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
        )
        if (rawReadingText.isNotBlank()) {
            Text(
                text = "OCR: $rawReadingText",
                color = Color.White.copy(alpha = 0.62f),
                style = MaterialTheme.typography.bodyMedium,
            )
        }
        ScoreScannerManualEntryField(
            value = controller.confirmationText,
            onValueChange = {
                controller.confirmationText = ScoreScannerParsingService.formattedScoreInput(it)
                controller.confirmationValidationMessage = null
            },
            focusRequester = focusRequester,
        )
        controller.confirmationValidationMessage?.let { message ->
            Text(
                text = message,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
            )
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            AppSecondaryButton(
                onClick = {
                    focusManager.clearFocus(force = true)
                    onRetake()
                },
                modifier = Modifier.weight(0.82f),
            ) {
                Text(
                    text = "Retake",
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            AppSecondaryButton(
                onClick = {
                    focusRequester.requestFocus()
                },
                modifier = Modifier.weight(1.18f),
            ) {
                Text(
                    text = "Manual Entry",
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            AppPrimaryButton(
                onClick = {
                    focusManager.clearFocus(force = true)
                    onUseReading()
                },
                modifier = Modifier.weight(1f),
                enabled = ScoreScannerParsingService.normalizedScore(controller.confirmationText) != null,
            ) {
                Text(
                    text = "Use Reading",
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
internal fun ScoreScannerManualEntryField(
    value: String,
    onValueChange: (String) -> Unit,
    focusRequester: FocusRequester,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .focusRequester(focusRequester),
        label = { Text("Manual correction") },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        textStyle = MaterialTheme.typography.headlineSmall.copy(
            textAlign = TextAlign.End,
            fontFamily = FontFamily.Monospace,
            color = Color.White,
        ),
        singleLine = true,
    )
}

internal fun Rect.toAndroidRectF(): RectF = RectF(left, top, right, bottom)
