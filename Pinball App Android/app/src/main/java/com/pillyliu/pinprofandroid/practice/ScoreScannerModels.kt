package com.pillyliu.pinprofandroid.practice

import android.graphics.RectF
import androidx.compose.ui.geometry.Size
import kotlin.math.max
import kotlin.math.min

internal enum class ScoreScannerDisplayMode {
    Lcd,
    Dmd,
    Segmented,
}

internal enum class ScoreScannerStatus(
    val title: String,
    val detail: String,
) {
    CameraPermissionRequired(
        title = "Camera access required",
        detail = "Allow camera access to scan score displays on-device.",
    ),
    CameraUnavailable(
        title = "Camera unavailable",
        detail = "This device could not start the rear camera.",
    ),
    Searching(
        title = "Searching",
        detail = "Align the score display inside the box.",
    ),
    Reading(
        title = "Reading",
        detail = "Live OCR is tracking the display.",
    ),
    StableCandidate(
        title = "Stable candidate",
        detail = "Hold steady for a clean lock.",
    ),
    Locked(
        title = "Locked",
        detail = "Stable reading captured. Confirm or edit before use.",
    ),
    FailedNoReading(
        title = "No reading",
        detail = "No stable numeric reading yet. Freeze and confirm manually if needed.",
    ),
}

internal data class ScoreOcrObservation(
    val text: String,
    val confidence: Float,
    val boundingBox: RectF,
)

internal data class ScoreScannerCandidate(
    val rawText: String,
    val normalizedScore: Int,
    val formattedScore: String,
    val confidence: Float,
    val boundingBox: RectF,
    val digitCount: Int,
    val centerBias: Double,
)

internal data class ScoreScannerAnalysis(
    val bestCandidate: ScoreScannerCandidate?,
    val candidates: List<ScoreScannerCandidate>,
)

internal data class ScoreScannerLockedReading(
    val score: Int,
    val formattedScore: String,
    val rawText: String,
    val confidence: Float,
    val averageConfidence: Float,
)

internal data class ScoreScannerPreviewMapping(
    val previewBounds: RectF,
    val targetRect: RectF,
)

internal object ScoreScannerFrameMapper {
    fun cropRect(
        frameSize: Size,
        previewMapping: ScoreScannerPreviewMapping,
    ): RectF? {
        if (frameSize.width <= 0f || frameSize.height <= 0f) return null

        val previewBounds = previewMapping.previewBounds.standardized()
        val targetRect = previewMapping.targetRect.standardized().intersecting(previewBounds) ?: return null
        if (previewBounds.width() <= 0f || previewBounds.height() <= 0f) return null

        val scale = max(
            previewBounds.width() / frameSize.width,
            previewBounds.height() / frameSize.height,
        )
        if (scale <= 0f) return null

        val displayedWidth = frameSize.width * scale
        val displayedHeight = frameSize.height * scale
        val imageRectInPreview = RectF(
            previewBounds.left + ((previewBounds.width() - displayedWidth) / 2f),
            previewBounds.top + ((previewBounds.height() - displayedHeight) / 2f),
            previewBounds.left + ((previewBounds.width() - displayedWidth) / 2f) + displayedWidth,
            previewBounds.top + ((previewBounds.height() - displayedHeight) / 2f) + displayedHeight,
        )
        val visibleRect = targetRect.intersecting(imageRectInPreview) ?: return null

        val xInImage = (visibleRect.left - imageRectInPreview.left) / scale
        val yInImageTop = (visibleRect.top - imageRectInPreview.top) / scale
        val widthInImage = visibleRect.width() / scale
        val heightInImage = visibleRect.height() / scale

        val x = xInImage
        val y = frameSize.height - yInImageTop - heightInImage
        return RectF(
            x,
            y,
            x + widthInImage,
            y + heightInImage,
        ).standardized().intersectWithin(frameSize.width, frameSize.height)
    }

    fun cropRect(
        frameSize: Size,
        normalizedRect: RectF,
    ): RectF? {
        if (frameSize.width <= 0f || frameSize.height <= 0f) return null

        val width = frameSize.width * normalizedRect.width()
        val height = frameSize.height * normalizedRect.height()
        val x = frameSize.width * normalizedRect.left
        val y = frameSize.height * (1f - normalizedRect.bottom)
        return RectF(x, y, x + width, y + height).intersectWithin(frameSize.width, frameSize.height)
    }

    val fallbackNormalizedRect = RectF(0.12f, 0.27f, 0.88f, 0.40f)
}

internal fun RectF.standardized(): RectF {
    val left = min(this.left, this.right)
    val top = min(this.top, this.bottom)
    val right = max(this.left, this.right)
    val bottom = max(this.top, this.bottom)
    return RectF(left, top, right, bottom)
}

internal fun RectF.intersecting(other: RectF): RectF? {
    val left = max(this.left, other.left)
    val top = max(this.top, other.top)
    val right = min(this.right, other.right)
    val bottom = min(this.bottom, other.bottom)
    if (right <= left || bottom <= top) return null
    return RectF(left, top, right, bottom)
}

internal fun RectF.intersectWithin(width: Float, height: Float): RectF? {
    val bounded = intersecting(RectF(0f, 0f, width, height)) ?: return null
    if (bounded.width() <= 0f || bounded.height() <= 0f) return null
    return bounded
}
