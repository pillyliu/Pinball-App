package com.pillyliu.pinprofandroid.practice

import android.graphics.Bitmap
import android.graphics.RectF
import android.os.SystemClock
import androidx.camera.core.ImageProxy
import kotlinx.coroutines.launch

internal fun ScoreScannerController.analyzeFrame(imageProxy: ImageProxy) {
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
    val frameSize = scoreScannerOrientedFrameSize(
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
            val previewBitmap = if (requestedFreeze) {
                scoreScannerPreviewCropBitmap(boundPreviewView, previewMapping)
            } else {
                null
            }
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
            val lockedReading = scoreScannerLockedReading(snapshot)
            if (snapshot.state == ScoreScannerStatus.Locked && lockedReading != null) {
                freeze(
                    preferredReading = lockedReading,
                    sourceImage = inputImage,
                    sourceCropRect = cropRect,
                    previewBitmap = scoreScannerPreviewCropBitmap(boundPreviewView, previewMapping),
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

internal fun ScoreScannerController.process(
    analysis: ScoreScannerAnalysis,
    sourceImage: com.google.mlkit.vision.common.InputImage,
    sourceCropRect: RectF?,
) {
    val filtered = scoreScannerFilteredAnalysis(
        analysis = analysis,
        minimumDigitCount = minimumLiveDigitCount,
        minimumHorizontalPadding = minimumLiveHorizontalPadding,
        minimumVerticalPadding = minimumLiveVerticalPadding,
    )
    val snapshot = updateAnalyzerSnapshot(candidate = filtered.bestCandidate)
    val displayedReading = scoreScannerDisplayedReading(
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
            preferredReading = scoreScannerLockedReading(snapshot),
            sourceImage = sourceImage,
            sourceCropRect = sourceCropRect,
            previewBitmap = scoreScannerPreviewCropBitmap(boundPreviewView, previewMapping),
        )
    }
}

internal fun ScoreScannerController.freeze(
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
            val filtered = scoreScannerFilteredAnalysis(
                analysis = analysis,
                minimumDigitCount = minimumFinalDigitCount,
                minimumHorizontalPadding = 0.04f,
                minimumVerticalPadding = 0.04f,
            )
            candidateHighlights.clear()
            candidateHighlights.addAll(filtered.candidates.take(3))

            val locked = filtered.bestCandidate?.let(::scoreScannerReadingFrom) ?: preferredReading

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

internal fun ScoreScannerController.preferredFreezeReading(): ScoreScannerLockedReading? {
    val snapshot = withAnalyzerState { latestSnapshot }
    return liveCandidateReading ?: scoreScannerLockedReading(snapshot)
}

internal suspend fun ScoreScannerController.liveAnalysis(
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
    val filteredSourceAnalysis = scoreScannerFilteredAnalysis(
        analysis = sourceAnalysis,
        minimumDigitCount = minimumLiveDigitCount,
        minimumHorizontalPadding = minimumLiveHorizontalPadding,
        minimumVerticalPadding = minimumLiveVerticalPadding,
    )
    if (
        !shouldAttemptScoreScannerLiveBitmapFallback(
            now = now,
            lastFallbackAt = withAnalyzerState { lastLiveBitmapFallbackTimeMs },
            snapshot = withAnalyzerState { latestSnapshot },
            sourceBestCandidate = filteredSourceAnalysis.bestCandidate,
            liveBitmapFallbackIntervalMs = liveBitmapFallbackIntervalMs,
            strongLiveCandidateDigitCount = strongLiveCandidateDigitCount,
            strongLiveCandidateFormatQuality = strongLiveCandidateFormatQuality,
        )
    ) {
        return sourceAnalysis
    }

    val previewBitmap = scoreScannerPreviewCropBitmap(boundPreviewView, previewMapping) ?: return sourceAnalysis
    withAnalyzerState {
        lastLiveBitmapFallbackTimeMs = now
    }
    return try {
        ocrService.recognize(
            bitmap = previewBitmap,
            mode = ScoreScannerOcrService.Mode.LivePreview,
            displayMode = displayMode,
        ).let { mergeScoreScannerAnalyses(primary = sourceAnalysis, secondary = it) }
    } finally {
        if (!previewBitmap.isRecycled) {
            previewBitmap.recycle()
        }
    }
}
