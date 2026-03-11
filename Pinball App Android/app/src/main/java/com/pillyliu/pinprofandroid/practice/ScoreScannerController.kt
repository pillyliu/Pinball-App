package com.pillyliu.pinprofandroid.practice

import android.content.Context
import android.graphics.Bitmap
import android.graphics.RectF
import android.os.SystemClock
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Size
import androidx.lifecycle.LifecycleOwner
import com.google.common.util.concurrent.ListenableFuture
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

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
    private val appContext: Context,
) {
    var hasCameraPermission by mutableStateOf(false)
        private set
    var status by mutableStateOf(ScoreScannerStatus.Searching)
        private set
    var liveReadingText by mutableStateOf("No reading yet")
        private set
    var rawReadingText by mutableStateOf("")
        private set
    val candidateHighlights = mutableStateListOf<ScoreScannerCandidate>()
    var lockedReading by mutableStateOf<ScoreScannerLockedReading?>(null)
        private set
    var isFrozen by mutableStateOf(false)
        private set
    var frozenPreviewBitmap by mutableStateOf<Bitmap?>(null)
        private set
    var zoomFactor by mutableFloatStateOf(1f)
        private set
    var availableZoomRange by mutableStateOf(1f..8f)
        private set
    var confirmationText by mutableStateOf("")
    var confirmationValidationMessage by mutableStateOf<String?>(null)

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val ocrService = ScoreScannerOcrService()
    private val stabilityService = ScoreScannerStabilityService()
    private val liveOcrIntervalMs = 340L
    private val minimumLiveDigitCount = 5
    private val minimumFinalDigitCount = 4

    @Volatile
    private var previewMapping: ScoreScannerPreviewMapping? = null

    @Volatile
    private var lastOcrTimeMs = 0L

    @Volatile
    private var isProcessingFrame = false

    @Volatile
    private var processingPaused = false

    private var displayMode = ScoreScannerDisplayMode.Lcd
    private var latestSnapshot: ScoreScannerStabilityService.Snapshot? = null
    private var boundLifecycleOwner: LifecycleOwner? = null
    private var boundPreviewView: PreviewView? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var camera: Camera? = null

    fun setCameraPermission(granted: Boolean) {
        hasCameraPermission = granted
        if (!granted) {
            status = ScoreScannerStatus.CameraPermissionRequired
        } else if (!isFrozen) {
            status = ScoreScannerStatus.Searching
        }
    }

    fun bindCamera(
        lifecycleOwner: LifecycleOwner,
        previewView: PreviewView,
    ) {
        boundLifecycleOwner = lifecycleOwner
        boundPreviewView = previewView
        if (!hasCameraPermission) {
            status = ScoreScannerStatus.CameraPermissionRequired
            return
        }

        scope.launch {
            val provider = try {
                cameraProvider ?: ProcessCameraProvider.getInstance(appContext).await().also {
                    cameraProvider = it
                }
            } catch (_: Exception) {
                status = ScoreScannerStatus.CameraUnavailable
                return@launch
            }

            withContext(Dispatchers.Main.immediate) {
                runCatching {
                    provider.unbindAll()

                    val preview = Preview.Builder().build().also { useCase ->
                        useCase.surfaceProvider = previewView.surfaceProvider
                    }

                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .also { useCase ->
                            useCase.setAnalyzer(cameraExecutor, ::analyzeFrame)
                        }

                    val boundCamera = provider.bindToLifecycle(
                        lifecycleOwner,
                        CameraSelector.DEFAULT_BACK_CAMERA,
                        preview,
                        analysis,
                    )

                    imageAnalysis = analysis
                    camera = boundCamera

                    val maxZoom = boundCamera.cameraInfo.zoomState.value?.maxZoomRatio?.coerceAtMost(8f) ?: 8f
                    availableZoomRange = 1f..maxZoom.coerceAtLeast(1f)
                    updateZoomFactor(1f)
                    status = ScoreScannerStatus.Searching
                }.onFailure {
                    status = ScoreScannerStatus.CameraUnavailable
                }
            }
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
        freeze(preferredReading = latestLockedReading(latestSnapshot))
    }

    fun retake() {
        processingPaused = false
        isProcessingFrame = false
        lastOcrTimeMs = 0L
        latestSnapshot = null
        stabilityService.reset()

        isFrozen = false
        frozenPreviewBitmap = null
        lockedReading = null
        candidateHighlights.clear()
        confirmationText = ""
        confirmationValidationMessage = null
        liveReadingText = "No reading yet"
        rawReadingText = ""
        status = if (hasCameraPermission) ScoreScannerStatus.Searching else ScoreScannerStatus.CameraPermissionRequired
    }

    fun validatedConfirmedScore(): Int? {
        val score = ScoreScannerParsingService.normalizedScore(confirmationText)
        if (score == null || score <= 0) {
            confirmationValidationMessage = "Enter a valid score above 0."
            return null
        }

        confirmationText = ScoreScannerParsingService.formattedScore(score)
        confirmationValidationMessage = null
        return score
    }

    fun dispose() {
        imageAnalysis?.clearAnalyzer()
        cameraProvider?.unbindAll()
        ocrService.close()
        scope.cancel()
        cameraExecutor.shutdown()
    }

    private fun analyzeFrame(imageProxy: ImageProxy) {
        if (processingPaused || isFrozen) {
            imageProxy.close()
            return
        }

        val now = SystemClock.elapsedRealtime()
        if (isProcessingFrame || now - lastOcrTimeMs < liveOcrIntervalMs) {
            imageProxy.close()
            return
        }

        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return
        }

        lastOcrTimeMs = now
        isProcessingFrame = true

        val rotationDegrees = imageProxy.imageInfo.rotationDegrees
        val frameSize = orientedFrameSize(
            width = imageProxy.width,
            height = imageProxy.height,
            rotationDegrees = rotationDegrees,
        )
        val cropRect = previewMapping?.let {
            ScoreScannerFrameMapper.cropRect(frameSize = frameSize, previewMapping = it)
        } ?: ScoreScannerFrameMapper.cropRect(
            frameSize = frameSize,
            normalizedRect = ScoreScannerFrameMapper.fallbackNormalizedRect,
        )

        val inputImage = com.google.mlkit.vision.common.InputImage.fromMediaImage(mediaImage, rotationDegrees)
        scope.launch {
            try {
                val analysis = ocrService.recognize(
                    inputImage = inputImage,
                    mode = ScoreScannerOcrService.Mode.LivePreview,
                    cropRect = cropRect,
                    displayMode = displayMode,
                )
                process(analysis)
            } catch (_: Exception) {
                val snapshot = stabilityService.ingest(candidate = null)
                latestSnapshot = snapshot
                status = snapshot.state
            } finally {
                imageProxy.close()
                isProcessingFrame = false
            }
        }
    }

    private fun process(analysis: ScoreScannerAnalysis) {
        val filtered = filteredAnalysis(
            analysis = analysis,
            minimumDigitCount = minimumLiveDigitCount,
            minimumHorizontalPadding = 0.10f,
            minimumVerticalPadding = 0.10f,
        )
        val snapshot = stabilityService.ingest(filtered.bestCandidate)
        latestSnapshot = snapshot

        candidateHighlights.clear()
        candidateHighlights.addAll(filtered.candidates.take(3))
        rawReadingText = filtered.bestCandidate?.rawText.orEmpty()
        liveReadingText = when {
            snapshot.dominantReading != null -> snapshot.dominantReading.formattedScore
            filtered.bestCandidate != null -> filtered.bestCandidate.formattedScore
            else -> "No reading yet"
        }
        status = snapshot.state

        if (snapshot.state == ScoreScannerStatus.Locked) {
            freeze(preferredReading = latestLockedReading(snapshot))
        }
    }

    private fun freeze(preferredReading: ScoreScannerLockedReading?) {
        if (isFrozen) return

        processingPaused = true
        val previewBitmap = capturePreviewCropBitmap()
        isFrozen = true
        frozenPreviewBitmap = previewBitmap
        lockedReading = preferredReading
        confirmationText = preferredReading?.formattedScore.orEmpty()
        confirmationValidationMessage = null
        status = if (preferredReading == null) ScoreScannerStatus.StableCandidate else ScoreScannerStatus.Locked

        if (previewBitmap == null) return

        scope.launch {
            try {
                val analysis = ocrService.recognize(
                    bitmap = previewBitmap,
                    mode = ScoreScannerOcrService.Mode.FinalPass,
                    displayMode = displayMode,
                )
                val filtered = filteredAnalysis(
                    analysis = analysis,
                    minimumDigitCount = minimumFinalDigitCount,
                    minimumHorizontalPadding = 0.04f,
                    minimumVerticalPadding = 0.04f,
                )
                candidateHighlights.clear()
                candidateHighlights.addAll(filtered.candidates.take(3))

                val locked = filtered.bestCandidate?.let {
                    ScoreScannerLockedReading(
                        score = it.normalizedScore,
                        formattedScore = it.formattedScore,
                        rawText = it.rawText,
                        confidence = it.confidence,
                        averageConfidence = it.confidence,
                    )
                } ?: preferredReading

                lockedReading = locked
                if (locked != null) {
                    confirmationText = locked.formattedScore
                    rawReadingText = locked.rawText
                    status = ScoreScannerStatus.Locked
                }
            } catch (_: Exception) {
                if (preferredReading != null) {
                    lockedReading = preferredReading
                    confirmationText = preferredReading.formattedScore
                    rawReadingText = preferredReading.rawText
                    status = ScoreScannerStatus.Locked
                }
            }
        }
    }

    private fun filteredAnalysis(
        analysis: ScoreScannerAnalysis,
        minimumDigitCount: Int,
        minimumHorizontalPadding: Float,
        minimumVerticalPadding: Float,
    ): ScoreScannerAnalysis {
        val filteredCandidates = analysis.candidates.filter { candidate ->
            candidate.digitCount >= minimumDigitCount &&
                candidate.boundingBox.left >= minimumHorizontalPadding &&
                candidate.boundingBox.right <= (1f - minimumHorizontalPadding) &&
                candidate.boundingBox.top >= minimumVerticalPadding &&
                candidate.boundingBox.bottom <= (1f - minimumVerticalPadding)
        }

        return ScoreScannerAnalysis(
            bestCandidate = filteredCandidates.firstOrNull(),
            candidates = filteredCandidates,
        )
    }

    private fun latestLockedReading(
        snapshot: ScoreScannerStabilityService.Snapshot?,
    ): ScoreScannerLockedReading? {
        val reading = snapshot?.dominantReading ?: return null
        return ScoreScannerLockedReading(
            score = reading.score,
            formattedScore = reading.formattedScore,
            rawText = reading.rawText,
            confidence = reading.confidence,
            averageConfidence = snapshot.averageConfidence,
        )
    }

    private fun capturePreviewCropBitmap(): Bitmap? {
        val previewView = boundPreviewView ?: return null
        val mapping = previewMapping ?: return null
        val previewBitmap = previewView.bitmap ?: return null
        val previewBounds = mapping.previewBounds
        val targetRect = mapping.targetRect

        val cropLeft = (targetRect.left - previewBounds.left).toInt().coerceIn(0, previewBitmap.width - 1)
        val cropTop = (targetRect.top - previewBounds.top).toInt().coerceIn(0, previewBitmap.height - 1)
        val cropWidth = targetRect.width().toInt().coerceIn(1, previewBitmap.width - cropLeft)
        val cropHeight = targetRect.height().toInt().coerceIn(1, previewBitmap.height - cropTop)

        return Bitmap.createBitmap(previewBitmap, cropLeft, cropTop, cropWidth, cropHeight)
    }

    private fun orientedFrameSize(
        width: Int,
        height: Int,
        rotationDegrees: Int,
    ): Size {
        return if (rotationDegrees == 90 || rotationDegrees == 270) {
            Size(height.toFloat(), width.toFloat())
        } else {
            Size(width.toFloat(), height.toFloat())
        }
    }
}

private suspend fun <T> ListenableFuture<T>.await(): T = suspendCancellableCoroutine { continuation ->
    addListener(
        {
            runCatching { get() }
                .onSuccess { continuation.resume(it) }
                .onFailure { continuation.resumeWithException(it) }
        },
        java.util.concurrent.Executor { runnable -> runnable.run() },
    )
}
