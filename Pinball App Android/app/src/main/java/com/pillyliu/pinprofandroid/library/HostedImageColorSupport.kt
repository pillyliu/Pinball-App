package com.pillyliu.pinprofandroid.library

import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.core.graphics.ColorUtils
import androidx.core.graphics.get
import coil.imageLoader
import coil.request.ImageRequest
import coil.size.Size

@Composable
internal fun rememberPlayfieldTitleColor(imageUrls: List<String>): Color {
    val context = LocalContext.current
    val fallback = androidx.compose.material3.MaterialTheme.colorScheme.onSurface
    val candidates = imageUrls.filter { it.isNotBlank() }.distinct()
    val primaryModel = rememberCachedImageModel(candidates.firstOrNull())
    val titleColor by produceState(initialValue = fallback, key1 = primaryModel) {
        value = fallback
        val model = primaryModel ?: return@produceState
        val request = ImageRequest.Builder(context)
            .data(model)
            .allowHardware(false)
            .size(Size.ORIGINAL)
            .build()
        val result = runCatching { context.imageLoader.execute(request) }.getOrNull() ?: return@produceState
        val bitmap = (result.drawable as? BitmapDrawable)?.bitmap ?: return@produceState
        val luma = sampleTopCenterLuma(bitmap)
        value = if (luma < 0.46) Color(0xFFF8FAFC) else Color(0xFF111827)
    }
    return titleColor
}

private fun sampleTopCenterLuma(bitmap: Bitmap): Double {
    val width = bitmap.width
    val height = bitmap.height
    if (width <= 0 || height <= 0) return 0.5

    val left = (width * 0.2f).toInt().coerceIn(0, width - 1)
    val right = (width * 0.8f).toInt().coerceIn(left + 1, width)
    val bottom = (height * 0.22f).toInt().coerceIn(1, height)
    val stepX = maxOf(1, (right - left) / 36)
    val stepY = maxOf(1, bottom / 18)

    var total = 0.0
    var count = 0
    for (y in 0 until bottom step stepY) {
        for (x in left until right step stepX) {
            total += ColorUtils.calculateLuminance(bitmap[x, y])
            count++
        }
    }
    return if (count == 0) 0.5 else total / count
}
