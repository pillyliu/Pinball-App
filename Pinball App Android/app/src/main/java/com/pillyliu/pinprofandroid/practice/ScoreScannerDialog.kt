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
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.ime
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
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.pillyliu.pinprofandroid.ui.AppFullscreenActionButton
import com.pillyliu.pinprofandroid.ui.AppFullscreenStage
import com.pillyliu.pinprofandroid.ui.AppFullscreenStatusOverlay

@Composable
internal fun ScoreScannerDialog(
    onUseReading: (Long) -> Unit,
    onClose: () -> Unit,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val controller = rememberScoreScannerController(context)
    val density = LocalDensity.current
    val view = LocalView.current
    val hapticFeedback = LocalHapticFeedback.current
    val focusManager = LocalFocusManager.current
    var previewView by remember { mutableStateOf<PreviewView?>(null) }
    var rootSize by remember { mutableStateOf(IntSize.Zero) }
    var targetRect by remember { mutableStateOf<RectF?>(null) }
    var previousStatus by remember { mutableStateOf(controller.status) }

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

    LaunchedEffect(controller.status) {
        val nextStatus = controller.status
        if (nextStatus == ScoreScannerStatus.Locked && previousStatus != ScoreScannerStatus.Locked) {
            hapticFeedback.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
        }
        previousStatus = nextStatus
    }

    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            dismissOnBackPress = true,
            dismissOnClickOutside = false,
            decorFitsSystemWindows = false,
        ),
    ) {
        AppFullscreenStage(
            modifier = Modifier.onGloballyPositioned { coordinates ->
                rootSize = coordinates.size
            },
        ) {
            BoxWithConstraints(
                modifier = Modifier.fillMaxSize(),
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

                ScoreScannerCameraPreview(
                    hasCameraPermission = controller.hasCameraPermission,
                    isFrozen = controller.isFrozen,
                    onPreviewViewReady = { previewView = it },
                )

                ScoreScannerTargetStage(
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

                ScoreScannerClosePill(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(start = 18.dp, top = safeInsets.calculateTopPadding() + 18.dp),
                    onClose = onClose,
                )

                ScoreScannerHeader(
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = headerTop),
                )

                ScoreScannerLiveReadingPanel(
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
                    verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(14.dp),
                ) {
                    if (controller.isFrozen) {
                        ScoreScannerConfirmationSheet(
                            controller = controller,
                            onUseReading = {
                                val score = controller.validatedConfirmedScore() ?: return@ScoreScannerConfirmationSheet
                                onUseReading(score)
                            },
                            onRetake = controller::retake,
                        )
                    } else {
                        ScoreScannerControls(
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
                            title = controller.status.title,
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
                            title = controller.status.title,
                            text = controller.status.detail,
                        )
                    }

                    else -> Unit
                }
            }
        }
    }
}
