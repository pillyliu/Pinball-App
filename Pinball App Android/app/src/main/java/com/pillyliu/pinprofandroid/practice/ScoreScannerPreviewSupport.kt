package com.pillyliu.pinprofandroid.practice

import android.graphics.Bitmap
import androidx.camera.view.PreviewView
import androidx.compose.ui.geometry.Size

internal fun scoreScannerPreviewCropBitmap(
    previewView: PreviewView?,
    previewMapping: ScoreScannerPreviewMapping?,
): Bitmap? {
    val resolvedPreviewView = previewView ?: return null
    val resolvedPreviewMapping = previewMapping ?: return null
    val previewBitmap = resolvedPreviewView.bitmap ?: return null
    val previewBounds = resolvedPreviewMapping.previewBounds
    val targetRect = resolvedPreviewMapping.targetRect

    val cropLeft = (targetRect.left - previewBounds.left).toInt().coerceIn(0, previewBitmap.width - 1)
    val cropTop = (targetRect.top - previewBounds.top).toInt().coerceIn(0, previewBitmap.height - 1)
    val cropWidth = targetRect.width().toInt().coerceIn(1, previewBitmap.width - cropLeft)
    val cropHeight = targetRect.height().toInt().coerceIn(1, previewBitmap.height - cropTop)

    return Bitmap.createBitmap(previewBitmap, cropLeft, cropTop, cropWidth, cropHeight)
}

internal fun scoreScannerOrientedFrameSize(
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
