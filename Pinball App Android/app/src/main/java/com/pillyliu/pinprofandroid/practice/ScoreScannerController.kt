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
    private data class AnalyzerState(
        var lastOcrTimeMs: Long = 0L,
        var lastLiveBitmapFallbackTimeMs: Long = 0L,
        var isProcessingFrame: Boolean = false,
        var processingPaused: Boolean = false,
        var pendingFreezeRequest: Boolean = false,
        var pendingFreezePreferredReading: ScoreScannerLockedReading? = null,
        var frozenGate: Boolean = false,
        var latestSnapshot: ScoreScannerStabilityService.Snapshot? = null,
    )

    private data class AnalyzerFramePermit(
        val requestedFreeze: Boolean,
        val requestedFreezePreferredReading: ScoreScannerLockedReading?,
    )

    var hasCameraPermission by mutableStateOf(false)
        private set
    var status by mutableStateOf(ScoreScannerStatus.Searching)
        private set
    var liveReadingText by mutableStateOf("No reading yet")
        private set
    var liveCandidateReading by mutableStateOf<ScoreScannerLockedReading?>(null)
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
    private val liveBitmapFallbackIntervalMs = 450L
    private val minimumLiveDigitCount = 4
    private val minimumFinalDigitCount = 4
    private val minimumLiveHorizontalPadding = 0.04f
    private val minimumLiveVerticalPadding = 0.04f
    private val strongLiveCandidateDigitCount = 6
    private val strongLiveCandidateFormatQuality = 5
    private val analyzerStateLock = Any()
    private val analyzerState = AnalyzerState()

    @Volatile
    private var previewMapping: ScoreScannerPreviewMapping? = null
    private var displayMode = ScoreScannerDisplayMode.Lcd
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
        if (isFrozen) return
        requestPendingFreeze(preferredFreezeReading())
    }

    fun freezeDisplayedCandidate() {
        if (isFrozen) return
        val preferredReading = preferredFreezeReading() ?: return
        val previewBitmap = capturePreviewCropBitmap()
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

    fun dispose() {
        imageAnalysis?.clearAnalyzer()
        cameraProvider?.unbindAll()
        ocrService.close()
        scope.cancel()
        cameraExecutor.shutdown()
    }

    private fun analyzeFrame(imageProxy: ImageProxy) {
        val now = SystemClock.elapsedRealtime()
        val framePermit = beginAnalyzerFrame(now)
        if (framePermit == null) {
            imageProxy.close()
            return
        }

        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            finishAnalyzerFrame()
            imageProxy.close()
            return
        }

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
        val requestedFreeze = framePermit.requestedFreeze
        val requestedFreezePreferredReading = framePermit.requestedFreezePreferredReading
        scope.launch {
            try {
                val previewBitmap = if (requestedFreeze) capturePreviewCropBitmap() else null
                if (requestedFreeze) {
                    freeze(
                        preferredReading = requestedFreezePreferredReading ?: preferredFreezeReading(),
                        sourceImage = inputImage,
                        sourceCropRect = cropRect,
                        previewBitmap = previewBitmap,
                    )
                    return@launch
                }

                val analysis = liveAnalysis(
                    sourceImage = inputImage,
                    sourceCropRect = cropRect,
                    now = now,
                )
                process(
                    analysis = analysis,
                    sourceImage = inputImage,
                    sourceCropRect = cropRect,
                )
            } catch (_: Exception) {
                val snapshot = updateAnalyzerSnapshot(candidate = null)
                val lockedReading = latestLockedReading(snapshot)
                if (snapshot.state == ScoreScannerStatus.Locked && lockedReading != null) {
                    freeze(
                        preferredReading = lockedReading,
                        sourceImage = inputImage,
                        sourceCropRect = cropRect,
                        previewBitmap = capturePreviewCropBitmap(),
                    )
                } else {
                    candidateHighlights.clear()
                    rawReadingText = lockedReading?.rawText.orEmpty()
                    liveReadingText = lockedReading?.formattedScore ?: "No reading yet"
                    liveCandidateReading = lockedReading
                    status = snapshot.state
                }
            } finally {
                imageProxy.close()
                finishAnalyzerFrame()
            }
        }
    }

    private fun process(
        analysis: ScoreScannerAnalysis,
        sourceImage: com.google.mlkit.vision.common.InputImage,
        sourceCropRect: RectF?,
    ) {
        val filtered = filteredAnalysis(
            analysis = analysis,
            minimumDigitCount = minimumLiveDigitCount,
            minimumHorizontalPadding = minimumLiveHorizontalPadding,
            minimumVerticalPadding = minimumLiveVerticalPadding,
        )
        val snapshot = updateAnalyzerSnapshot(candidate = filtered.bestCandidate)
        val displayedReading = latestDisplayedReading(
            snapshot = snapshot,
            bestCandidate = filtered.bestCandidate,
        )

        candidateHighlights.clear()
        candidateHighlights.addAll(filtered.candidates.take(3))
        rawReadingText = filtered.bestCandidate?.rawText.orEmpty()
        liveCandidateReading = displayedReading
        liveReadingText = when {
            snapshot.dominantReading != null -> snapshot.dominantReading.formattedScore
            filtered.bestCandidate != null -> filtered.bestCandidate.formattedScore
            else -> "No reading yet"
        }
        status = snapshot.state

        if (snapshot.state == ScoreScannerStatus.Locked) {
            freeze(
                preferredReading = latestLockedReading(snapshot),
                sourceImage = sourceImage,
                sourceCropRect = sourceCropRect,
                previewBitmap = capturePreviewCropBitmap(),
            )
        }
    }

    private fun freeze(
        preferredReading: ScoreScannerLockedReading?,
        sourceImage: com.google.mlkit.vision.common.InputImage? = null,
        sourceCropRect: RectF? = null,
        previewBitmap: Bitmap? = null,
    ) {
        if (isFrozen) return

        val shouldFreeze = withAnalyzerState {
            if (frozenGate) {
                false
            } else {
                processingPaused = true
                frozenGate = true
                true
            }
        }
        if (!shouldFreeze) {
            return
        }
        isFrozen = true
        frozenPreviewBitmap = previewBitmap
        lockedReading = preferredReading
        confirmationText = preferredReading?.formattedScore.orEmpty()
        confirmationValidationMessage = null
        status = if (preferredReading == null) ScoreScannerStatus.StableCandidate else ScoreScannerStatus.Locked

        scope.launch {
            try {
                val analysis = when {
                    previewBitmap != null -> ocrService.recognize(
                        bitmap = previewBitmap,
                        mode = ScoreScannerOcrService.Mode.FinalPass,
                        displayMode = displayMode,
                    )
                    sourceImage != null -> ocrService.recognize(
                        inputImage = sourceImage,
                        mode = ScoreScannerOcrService.Mode.FinalPass,
                        cropRect = sourceCropRect,
                        displayMode = displayMode,
                    )
                    else -> null
                } ?: return@launch
                val filtered = filteredAnalysis(
                    analysis = analysis,
                    minimumDigitCount = minimumFinalDigitCount,
                    minimumHorizontalPadding = 0.04f,
                    minimumVerticalPadding = 0.04f,
                )
                candidateHighlights.clear()
                candidateHighlights.addAll(filtered.candidates.take(3))

                val locked = filtered.bestCandidate?.let {
                    readingFrom(it)
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

    private fun preferredFreezeReading(): ScoreScannerLockedReading? {
        val snapshot = withAnalyzerState { latestSnapshot }
        return liveCandidateReading ?: latestLockedReading(snapshot)
    }

    private fun latestDisplayedReading(
        snapshot: ScoreScannerStabilityService.Snapshot?,
        bestCandidate: ScoreScannerCandidate?,
    ): ScoreScannerLockedReading? {
        latestLockedReading(snapshot)?.let { return it }
        val candidate = bestCandidate ?: return null
        return readingFrom(candidate)
    }

    private fun readingFrom(candidate: ScoreScannerCandidate): ScoreScannerLockedReading {
        return ScoreScannerLockedReading(
            score = candidate.normalizedScore,
            formattedScore = candidate.formattedScore,
            rawText = candidate.rawText,
            confidence = candidate.confidence,
            averageConfidence = candidate.confidence,
        )
    }

    private suspend fun liveAnalysis(
        sourceImage: com.google.mlkit.vision.common.InputImage,
        sourceCropRect: RectF?,
        now: Long,
    ): ScoreScannerAnalysis {
        val sourceAnalysis = ocrService.recognize(
            inputImage = sourceImage,
            mode = ScoreScannerOcrService.Mode.LivePreview,
            cropRect = sourceCropRect,
            displayMode = displayMode,
        )
        val filteredSourceAnalysis = filteredAnalysis(
            analysis = sourceAnalysis,
            minimumDigitCount = minimumLiveDigitCount,
            minimumHorizontalPadding = minimumLiveHorizontalPadding,
            minimumVerticalPadding = minimumLiveVerticalPadding,
        )
        if (!shouldAttemptLiveBitmapFallback(now, filteredSourceAnalysis.bestCandidate)) {
            return sourceAnalysis
        }

        val previewBitmap = capturePreviewCropBitmap() ?: return sourceAnalysis
        withAnalyzerState {
            lastLiveBitmapFallbackTimeMs = now
        }
        return try {
            ocrService.recognize(
                bitmap = previewBitmap,
                mode = ScoreScannerOcrService.Mode.LivePreview,
                displayMode = displayMode,
            )
                .let { mergeAnalyses(primary = sourceAnalysis, secondary = it) }
        } finally {
            if (!previewBitmap.isRecycled) {
                previewBitmap.recycle()
            }
        }
    }

    private fun shouldAttemptLiveBitmapFallback(
        now: Long,
        sourceBestCandidate: ScoreScannerCandidate?,
    ): Boolean {
        val (snapshot, lastFallbackAt) = withAnalyzerState {
            latestSnapshot to lastLiveBitmapFallbackTimeMs
        }
        if (now - lastFallbackAt < liveBitmapFallbackIntervalMs) return false
        if (snapshot?.state == ScoreScannerStatus.Locked) return false
        val candidate = sourceBestCandidate ?: return true
        return candidate.digitCount < strongLiveCandidateDigitCount ||
            candidate.formatQuality < strongLiveCandidateFormatQuality
    }

    private fun mergeAnalyses(
        primary: ScoreScannerAnalysis,
        secondary: ScoreScannerAnalysis,
    ): ScoreScannerAnalysis {
        val rankedCandidates = ScoreScannerParsingService.rankCandidates(
            primary.candidates + secondary.candidates
        )
        return ScoreScannerAnalysis(
            bestCandidate = rankedCandidates.firstOrNull(),
            candidates = rankedCandidates,
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

    private inline fun <T> withAnalyzerState(block: AnalyzerState.() -> T): T =
        synchronized(analyzerStateLock) {
            analyzerState.block()
        }

    private fun requestPendingFreeze(preferredReading: ScoreScannerLockedReading?) {
        withAnalyzerState {
            pendingFreezePreferredReading = preferredReading
            pendingFreezeRequest = true
        }
    }

    private fun beginAnalyzerFrame(now: Long): AnalyzerFramePermit? =
        withAnalyzerState {
            if (processingPaused || frozenGate || isProcessingFrame || now - lastOcrTimeMs < liveOcrIntervalMs) {
                null
            } else {
                lastOcrTimeMs = now
                isProcessingFrame = true
                val requestedFreeze = pendingFreezeRequest
                val requestedFreezePreferredReading = pendingFreezePreferredReading
                if (requestedFreeze) {
                    pendingFreezeRequest = false
                    pendingFreezePreferredReading = null
                }
                AnalyzerFramePermit(
                    requestedFreeze = requestedFreeze,
                    requestedFreezePreferredReading = requestedFreezePreferredReading,
                )
            }
        }

    private fun finishAnalyzerFrame() {
        withAnalyzerState {
            isProcessingFrame = false
        }
    }

    private fun updateAnalyzerSnapshot(candidate: ScoreScannerCandidate?): ScoreScannerStabilityService.Snapshot =
        withAnalyzerState {
            stabilityService.ingest(candidate).also { latestSnapshot = it }
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
