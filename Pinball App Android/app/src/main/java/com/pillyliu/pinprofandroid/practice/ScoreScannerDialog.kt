package com.pillyliu.pinprofandroid.practice

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.RectF
import android.net.Uri
import android.provider.Settings
import android.view.WindowManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogWindowProvider
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.pillyliu.pinprofandroid.ui.AppFullscreenActionButton
import com.pillyliu.pinprofandroid.ui.AppFullscreenStatusOverlay
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton

@Composable
internal fun ScoreScannerDialog(
    onUseReading: (Int) -> Unit,
    onClose: () -> Unit,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val controller = rememberScoreScannerController(context)
    val density = LocalDensity.current
    val view = LocalView.current
    val focusManager = LocalFocusManager.current
    var previewView by remember { mutableStateOf<PreviewView?>(null) }
    var rootSize by remember { mutableStateOf(IntSize.Zero) }
    var targetRect by remember { mutableStateOf<RectF?>(null) }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        controller.setCameraPermission(granted)
    }

    LaunchedEffect(Unit) {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        controller.setCameraPermission(granted)
        if (!granted) {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    LaunchedEffect(previewView, controller.hasCameraPermission) {
        val currentPreviewView = previewView ?: return@LaunchedEffect
        if (controller.hasCameraPermission) {
            controller.bindCamera(lifecycleOwner, currentPreviewView)
        }
    }

    LaunchedEffect(rootSize, targetRect) {
        val currentTargetRect = targetRect ?: return@LaunchedEffect
        if (rootSize.width > 0 && rootSize.height > 0) {
            controller.updatePreviewMapping(
                previewBounds = RectF(0f, 0f, rootSize.width.toFloat(), rootSize.height.toFloat()),
                targetRect = currentTargetRect,
            )
        }
    }

    DisposableEffect(view) {
        val dialogWindow = (view.parent as? DialogWindowProvider)?.window
        val originalSoftInputMode = dialogWindow?.attributes?.softInputMode
        dialogWindow?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING)

        onDispose {
            if (originalSoftInputMode != null) {
                dialogWindow.setSoftInputMode(originalSoftInputMode)
            }
        }
    }

    BackHandler(onBack = onClose)

    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            dismissOnBackPress = true,
            dismissOnClickOutside = false,
            decorFitsSystemWindows = false,
        ),
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .onGloballyPositioned { coordinates ->
                    rootSize = coordinates.size
                },
        ) {
            val safeInsets = WindowInsets.safeDrawing.asPaddingValues()
            val imeBottom = with(density) { WindowInsets.ime.getBottom(this).toDp() }
            val controlsBottomPadding = maxOf(
                safeInsets.calculateBottomPadding(),
                if (imeBottom > 0.dp) imeBottom + 6.dp else 18.dp
            )
            val targetWidth = minOf(maxWidth * 0.82f, 420.dp)
            val targetHeight = minOf(maxOf(maxHeight * 0.10f, 78.dp), 104.dp)
            val targetTop = minOf(
                maxOf(safeInsets.calculateTopPadding() + 192.dp, 190.dp),
                maxOf(maxHeight * 0.26f, safeInsets.calculateTopPadding() + 192.dp),
            )
            val livePanelTop = minOf(targetTop + targetHeight + 86.dp, maxHeight - 220.dp)
            val headerTop = maxOf(targetTop - 84.dp, 78.dp)

            if (controller.hasCameraPermission) {
                AndroidView(
                    modifier = Modifier.fillMaxSize(),
                    factory = { viewContext ->
                        PreviewView(viewContext).apply {
                            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                            scaleType = PreviewView.ScaleType.FILL_CENTER
                            previewView = this
                        }
                    },
                    update = { previewView = it },
                )
            }

            TargetStage(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .offset(y = targetTop)
                    .width(targetWidth)
                    .height(targetHeight)
                    .onGloballyPositioned { coordinates ->
                        targetRect = coordinates.boundsInRoot().toAndroidRectF()
                    },
                controller = controller,
            )

            ClosePill(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(start = 18.dp, top = safeInsets.calculateTopPadding() + 18.dp),
                onClose = onClose,
            )

            Text(
                text = "Align the score display inside the box",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = headerTop)
                    .padding(horizontal = 24.dp),
            )

            LiveReadingPanel(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = livePanelTop)
                    .padding(horizontal = 18.dp),
                controller = controller,
            )

            if (controller.isFrozen && imeBottom > 0.dp) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                        ) {
                            focusManager.clearFocus(force = true)
                        }
                )
            }

            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 18.dp)
                    .padding(bottom = controlsBottomPadding),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                if (controller.isFrozen) {
                    ScoreConfirmationSheet(
                        controller = controller,
                        onUseReading = {
                            val score = controller.validatedConfirmedScore() ?: return@ScoreConfirmationSheet
                            onUseReading(score)
                        },
                        onRetake = controller::retake,
                    )
                } else {
                    ScannerControls(
                        zoomFactor = controller.zoomFactor,
                        availableZoomRange = controller.availableZoomRange,
                        onSetZoom = controller::updateZoomFactor,
                        onFreeze = controller::freezeCurrentFrame,
                    )
                }
            }

            when (controller.status) {
                ScoreScannerStatus.CameraPermissionRequired -> {
                    AppFullscreenStatusOverlay(
                        text = controller.status.detail,
                    )
                    AppFullscreenActionButton(
                        text = "Open Settings",
                        onClick = {
                            val intent = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", context.packageName, null),
                            )
                            context.startActivity(intent)
                        },
                        modifier = Modifier
                            .align(Alignment.Center)
                            .padding(top = 132.dp),
                    )
                }

                ScoreScannerStatus.CameraUnavailable -> {
                    AppFullscreenStatusOverlay(
                        text = controller.status.detail,
                    )
                }

                else -> Unit
            }
        }
    }
}

@Composable
private fun ClosePill(
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
private fun TargetStage(
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
            androidx.compose.foundation.Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = "Frozen score preview",
                modifier = Modifier.fillMaxSize(),
            )
        }
        CandidateHighlightsOverlay(
            candidates = controller.candidateHighlights,
            modifier = Modifier.fillMaxSize(),
        )
    }
}

@Composable
private fun CandidateHighlightsOverlay(
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
private fun LiveReadingPanel(
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
private fun ScannerControls(
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
private fun ScoreConfirmationSheet(
    controller: ScoreScannerController,
    onUseReading: () -> Unit,
    onRetake: () -> Unit,
) {
    val focusManager = LocalFocusManager.current
    val focusRequester = remember { FocusRequester() }

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
            text = "Locked score",
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
        Text(
            text = "OCR: ${controller.rawReadingText.ifBlank { controller.lockedReading?.rawText.orEmpty() }}",
            color = Color.White.copy(alpha = 0.62f),
            style = MaterialTheme.typography.bodyMedium,
        )
        ScoreManualEntryField(
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
private fun ScoreManualEntryField(
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

private fun Rect.toAndroidRectF(): RectF = RectF(left, top, right, bottom)
