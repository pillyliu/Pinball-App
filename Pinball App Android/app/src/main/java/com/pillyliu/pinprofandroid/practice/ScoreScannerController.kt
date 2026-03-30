package com.pillyliu.pinprofandroid.practice

import android.content.Context
import android.graphics.RectF
import androidx.camera.view.PreviewView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

@Composable
internal fun rememberScoreScannerController(
    context: Context,
): ScoreScannerController {
    val appContext = context.applicationContext
    val controller = remember(appContext) { ScoreScannerController(appContext) }
    DisposableEffect(controller) {
        onDispose {
            controller.dispose()
        }
    }
    return controller
}

internal class ScoreScannerController(
    val appContext: Context,
) {
    var hasCameraPermission by mutableStateOf(false)
    var status by mutableStateOf(ScoreScannerStatus.Searching)
    var liveReadingText by mutableStateOf("No reading yet")
    var liveCandidateReading by mutableStateOf<ScoreScannerLockedReading?>(null)
    var rawReadingText by mutableStateOf("")
    val candidateHighlights = mutableStateListOf<ScoreScannerCandidate>()
    var lockedReading by mutableStateOf<ScoreScannerLockedReading?>(null)
    var isFrozen by mutableStateOf(false)
    var frozenPreviewBitmap by mutableStateOf<android.graphics.Bitmap?>(null)
    var zoomFactor by mutableFloatStateOf(1f)
    var availableZoomRange by mutableStateOf(1f..8f)
    var confirmationText by mutableStateOf("")
    var confirmationValidationMessage by mutableStateOf<String?>(null)

    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    val ocrService = ScoreScannerOcrService()
    val stabilityService = ScoreScannerStabilityService()
    val liveOcrIntervalMs = 340L
    val liveBitmapFallbackIntervalMs = 450L
    val minimumLiveDigitCount = 4
    val minimumFinalDigitCount = 4
    val minimumLiveHorizontalPadding = 0.04f
    val minimumLiveVerticalPadding = 0.04f
    val strongLiveCandidateDigitCount = 6
    val strongLiveCandidateFormatQuality = 5
    val analyzerStateLock = Any()
    val analyzerState = AnalyzerState()

    @Volatile
    var previewMapping: ScoreScannerPreviewMapping? = null
    var displayMode = ScoreScannerDisplayMode.Lcd
    var boundLifecycleOwner: androidx.lifecycle.LifecycleOwner? = null
    var boundPreviewView: PreviewView? = null
    var cameraProvider: androidx.camera.lifecycle.ProcessCameraProvider? = null
    var imageAnalysis: androidx.camera.core.ImageAnalysis? = null
    var camera: androidx.camera.core.Camera? = null

    fun setCameraPermission(granted: Boolean) {
        hasCameraPermission = granted
        if (!granted) {
            status = ScoreScannerStatus.CameraPermissionRequired
        } else if (!isFrozen) {
            status = ScoreScannerStatus.Searching
        }
    }

    fun updatePreviewMapping(
        previewBounds: RectF,
        targetRect: RectF,
    ) {
        if (previewBounds.width() <= 0f || previewBounds.height() <= 0f) return
        previewMapping = ScoreScannerPreviewMapping(
            previewBounds = previewBounds.standardized(),
            targetRect = targetRect.standardized(),
        )
    }

    fun updateZoomFactor(proposed: Float) {
        val clamped = proposed.coerceIn(availableZoomRange.start, availableZoomRange.endInclusive)
        zoomFactor = clamped
        camera?.cameraControl?.setZoomRatio(clamped)
    }

    fun freezeCurrentFrame() {
        if (isFrozen) return
        requestPendingFreeze(preferredFreezeReading())
    }

    fun freezeDisplayedCandidate() {
        if (isFrozen) return
        val preferredReading = preferredFreezeReading() ?: return
        val previewBitmap = scoreScannerPreviewCropBitmap(boundPreviewView, previewMapping)
        if (previewBitmap != null) {
            freeze(
                preferredReading = preferredReading,
                previewBitmap = previewBitmap,
            )
            return
        }

        requestPendingFreeze(preferredReading)
    }

    fun retake() {
        withAnalyzerState {
            processingPaused = false
            pendingFreezeRequest = false
            pendingFreezePreferredReading = null
            isProcessingFrame = false
            lastOcrTimeMs = 0L
            lastLiveBitmapFallbackTimeMs = 0L
            latestSnapshot = null
            frozenGate = false
            stabilityService.reset()
        }

        isFrozen = false
        frozenPreviewBitmap = null
        lockedReading = null
        liveCandidateReading = null
        candidateHighlights.clear()
        confirmationText = ""
        confirmationValidationMessage = null
        liveReadingText = "No reading yet"
        rawReadingText = ""
        status = if (hasCameraPermission) ScoreScannerStatus.Searching else ScoreScannerStatus.CameraPermissionRequired
    }

    fun validatedConfirmedScore(): Long? {
        val score = ScoreScannerParsingService.normalizedScore(confirmationText)
        if (score == null || score <= 0) {
            confirmationValidationMessage = "Enter a valid score above 0."
            return null
        }

        confirmationText = ScoreScannerParsingService.formattedScore(score)
        confirmationValidationMessage = null
        return score
    }
}
