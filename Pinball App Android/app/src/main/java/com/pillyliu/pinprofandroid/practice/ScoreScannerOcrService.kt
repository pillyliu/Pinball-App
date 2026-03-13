package com.pillyliu.pinprofandroid.practice

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlin.math.max
import kotlin.math.roundToInt
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

    private data class BitmapRecognitionVariant(
        val bitmap: Bitmap,
        val confidenceMultiplier: Float,
        val ownedBitmap: Boolean,
    )

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
        val variants = bitmapRecognitionVariants(
            bitmap = bitmap,
            mode = mode,
            displayMode = displayMode,
        )
        val observations = mutableListOf<ScoreOcrObservation>()

        try {
            variants.forEach { variant ->
                val inputImage = InputImage.fromBitmap(variant.bitmap, 0)
                val referenceRect = RectF(0f, 0f, inputImage.width.toFloat(), inputImage.height.toFloat())
                val result = recognizer.process(inputImage).await()
                observations += extractObservations(
                    result = result,
                    referenceRect = referenceRect,
                    minimumTextHeight = minimumTextHeight(displayMode = displayMode, mode = mode),
                    confidenceMultiplier = variant.confidenceMultiplier,
                )
            }
        } finally {
            variants.filter { it.ownedBitmap }.forEach { it.bitmap.recycle() }
        }

        val candidates = ScoreScannerParsingService.rankedCandidates(observations)
        return ScoreScannerAnalysis(
            bestCandidate = candidates.firstOrNull(),
            candidates = candidates,
        )
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
        val observations = extractObservations(
            result = result,
            referenceRect = referenceRect,
            minimumTextHeight = minimumTextHeight(displayMode = displayMode, mode = mode),
        )

        val candidates = ScoreScannerParsingService.rankedCandidates(observations)
        return ScoreScannerAnalysis(
            bestCandidate = candidates.firstOrNull(),
            candidates = candidates,
        )
    }

    private fun extractObservations(
        result: Text,
        referenceRect: RectF,
        minimumTextHeight: Float,
        confidenceMultiplier: Float = 1f,
    ): List<ScoreOcrObservation> {
        val observations = mutableListOf<ScoreOcrObservation>()

        result.textBlocks.forEach { block ->
            if (block.lines.isNotEmpty()) {
                block.lines.forEach { line ->
                    line.toObservation(referenceRect, minimumTextHeight, confidenceMultiplier)?.let(observations::add)
                }
            } else {
                block.toObservation(referenceRect, minimumTextHeight, confidenceMultiplier)?.let(observations::add)
            }
        }

        return observations
    }

    private fun Text.TextBlock.toObservation(
        referenceRect: RectF,
        minimumTextHeight: Float,
        confidenceMultiplier: Float,
    ): ScoreOcrObservation? = observationFrom(text, boundingBox, referenceRect, minimumTextHeight, confidenceMultiplier)

    private fun Text.Line.toObservation(
        referenceRect: RectF,
        minimumTextHeight: Float,
        confidenceMultiplier: Float,
    ): ScoreOcrObservation? = observationFrom(text, boundingBox, referenceRect, minimumTextHeight, confidenceMultiplier)

    private fun observationFrom(
        text: String,
        boundingBox: Rect?,
        referenceRect: RectF,
        minimumTextHeight: Float,
        confidenceMultiplier: Float,
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
            confidence = confidenceMultiplier,
            boundingBox = normalized,
        )
    }

    private fun bitmapRecognitionVariants(
        bitmap: Bitmap,
        mode: Mode,
        displayMode: ScoreScannerDisplayMode,
    ): List<BitmapRecognitionVariant> {
        val variants = mutableListOf(
            BitmapRecognitionVariant(
                bitmap = bitmap,
                confidenceMultiplier = 1f,
                ownedBitmap = false,
            )
        )

        when (mode) {
            Mode.LivePreview -> {
                val liveScale = when (displayMode) {
                    ScoreScannerDisplayMode.Dmd -> 1.55f
                    ScoreScannerDisplayMode.Segmented -> 1.4f
                    ScoreScannerDisplayMode.Lcd -> 1.45f
                }
                val liveContrast = when (displayMode) {
                    ScoreScannerDisplayMode.Dmd -> 1.75f
                    ScoreScannerDisplayMode.Segmented -> 1.6f
                    ScoreScannerDisplayMode.Lcd -> 1.6f
                }
                variants += BitmapRecognitionVariant(
                    bitmap = createHighContrastVariant(
                        source = bitmap,
                        scale = liveScale,
                        contrast = liveContrast,
                        brightness = 0.02f,
                    ),
                    confidenceMultiplier = 0.94f,
                    ownedBitmap = true,
                )
            }

            Mode.FinalPass -> {
                variants += BitmapRecognitionVariant(
                    bitmap = createHighContrastVariant(
                        source = bitmap,
                        scale = 1.9f,
                        contrast = 1.9f,
                        brightness = 0.03f,
                    ),
                    confidenceMultiplier = 0.95f,
                    ownedBitmap = true,
                )
            }
        }

        return variants
    }

    private fun createHighContrastVariant(
        source: Bitmap,
        scale: Float,
        contrast: Float,
        brightness: Float,
    ): Bitmap {
        val scaledWidth = max(1, (source.width * scale).roundToInt())
        val scaledHeight = max(1, (source.height * scale).roundToInt())
        val scaledBitmap = if (scaledWidth != source.width || scaledHeight != source.height) {
            Bitmap.createScaledBitmap(source, scaledWidth, scaledHeight, true)
        } else {
            source.copy(Bitmap.Config.ARGB_8888, false)
        }

        val output = Bitmap.createBitmap(scaledWidth, scaledHeight, Bitmap.Config.ARGB_8888)
        val saturationMatrix = ColorMatrix().apply { setSaturation(0f) }
        val brightnessOffset = brightness * 255f
        val contrastTranslate = (-0.5f * contrast + 0.5f) * 255f + brightnessOffset
        val contrastMatrix = ColorMatrix(
            floatArrayOf(
                contrast, 0f, 0f, 0f, contrastTranslate,
                0f, contrast, 0f, 0f, contrastTranslate,
                0f, 0f, contrast, 0f, contrastTranslate,
                0f, 0f, 0f, 1f, 0f,
            )
        )
        contrastMatrix.preConcat(saturationMatrix)

        Canvas(output).drawBitmap(
            scaledBitmap,
            0f,
            0f,
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
                colorFilter = ColorMatrixColorFilter(contrastMatrix)
            },
        )
        if (scaledBitmap !== source) {
            scaledBitmap.recycle()
        }
        return output
    }

    private fun minimumTextHeight(
        displayMode: ScoreScannerDisplayMode,
        mode: Mode,
    ): Float = when (displayMode) {
        // Keep live preview as permissive as the freeze-frame pass so candidates
        // can surface before stability decides whether to lock them in.
        ScoreScannerDisplayMode.Lcd -> if (mode == Mode.LivePreview) 0.02f else 0.02f
        ScoreScannerDisplayMode.Dmd -> if (mode == Mode.LivePreview) 0.018f else 0.018f
        ScoreScannerDisplayMode.Segmented -> if (mode == Mode.LivePreview) 0.025f else 0.025f
    }
}

private suspend fun <T> Task<T>.await(): T = suspendCancellableCoroutine { continuation ->
    addOnSuccessListener { result -> continuation.resume(result) }
    addOnFailureListener { error -> continuation.resumeWithException(error) }
    addOnCanceledListener { continuation.cancel() }
}
