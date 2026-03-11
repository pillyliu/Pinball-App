package com.pillyliu.pinprofandroid.practice

import android.graphics.Bitmap
import android.graphics.Rect
import android.graphics.RectF
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

internal class ScoreScannerOcrService(
    private val recognizer: com.google.mlkit.vision.text.TextRecognizer =
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS),
) {
    enum class Mode {
        LivePreview,
        FinalPass,
    }

    suspend fun recognize(
        inputImage: InputImage,
        mode: Mode,
        cropRect: RectF? = null,
        displayMode: ScoreScannerDisplayMode = ScoreScannerDisplayMode.Lcd,
    ): ScoreScannerAnalysis {
        val referenceRect = cropRect ?: RectF(0f, 0f, inputImage.width.toFloat(), inputImage.height.toFloat())
        val result = recognizer.process(inputImage).await()
        return analyze(result, referenceRect, mode, displayMode)
    }

    suspend fun recognize(
        bitmap: Bitmap,
        mode: Mode,
        displayMode: ScoreScannerDisplayMode = ScoreScannerDisplayMode.Lcd,
    ): ScoreScannerAnalysis {
        val inputImage = InputImage.fromBitmap(bitmap, 0)
        return recognize(inputImage = inputImage, mode = mode, cropRect = null, displayMode = displayMode)
    }

    fun close() {
        recognizer.close()
    }

    private fun analyze(
        result: Text,
        referenceRect: RectF,
        mode: Mode,
        displayMode: ScoreScannerDisplayMode,
    ): ScoreScannerAnalysis {
        val minimumTextHeight = minimumTextHeight(displayMode = displayMode, mode = mode)
        val observations = mutableListOf<ScoreOcrObservation>()

        result.textBlocks.forEach { block ->
            if (block.lines.isNotEmpty()) {
                block.lines.forEach { line ->
                    line.toObservation(referenceRect, minimumTextHeight)?.let(observations::add)
                }
            } else {
                block.toObservation(referenceRect, minimumTextHeight)?.let(observations::add)
            }
        }

        val candidates = ScoreScannerParsingService.rankedCandidates(observations)
        return ScoreScannerAnalysis(
            bestCandidate = candidates.firstOrNull(),
            candidates = candidates,
        )
    }

    private fun Text.TextBlock.toObservation(
        referenceRect: RectF,
        minimumTextHeight: Float,
    ): ScoreOcrObservation? = observationFrom(text, boundingBox, referenceRect, minimumTextHeight)

    private fun Text.Line.toObservation(
        referenceRect: RectF,
        minimumTextHeight: Float,
    ): ScoreOcrObservation? = observationFrom(text, boundingBox, referenceRect, minimumTextHeight)

    private fun observationFrom(
        text: String,
        boundingBox: Rect?,
        referenceRect: RectF,
        minimumTextHeight: Float,
    ): ScoreOcrObservation? {
        val rect = boundingBox?.let(::RectF)?.standardized() ?: return null
        val visibleRect = rect.intersecting(referenceRect) ?: return null
        val normalized = RectF(
            (visibleRect.left - referenceRect.left) / referenceRect.width(),
            (visibleRect.top - referenceRect.top) / referenceRect.height(),
            (visibleRect.right - referenceRect.left) / referenceRect.width(),
            (visibleRect.bottom - referenceRect.top) / referenceRect.height(),
        )
        if (normalized.height() < minimumTextHeight) return null

        return ScoreOcrObservation(
            text = text,
            confidence = 1f,
            boundingBox = normalized,
        )
    }

    private fun minimumTextHeight(
        displayMode: ScoreScannerDisplayMode,
        mode: Mode,
    ): Float = when (displayMode) {
        ScoreScannerDisplayMode.Lcd -> if (mode == Mode.LivePreview) 0.03f else 0.02f
        ScoreScannerDisplayMode.Dmd -> if (mode == Mode.LivePreview) 0.025f else 0.018f
        ScoreScannerDisplayMode.Segmented -> if (mode == Mode.LivePreview) 0.04f else 0.025f
    }
}

private suspend fun <T> Task<T>.await(): T = suspendCancellableCoroutine { continuation ->
    addOnSuccessListener { result -> continuation.resume(result) }
    addOnFailureListener { error -> continuation.resumeWithException(error) }
    addOnCanceledListener { continuation.cancel() }
}
