package com.pillyliu.pinballandroid.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

suspend fun downloadText(url: String): String = withContext(Dispatchers.IO) {
    val cached = PinballDataCache.passthroughOrCachedText(url, allowMissing = false)
    cached.text ?: throw IllegalStateException("Empty response for $url")
}

suspend fun downloadTextAllowMissing(url: String): Pair<Int, String?> = withContext(Dispatchers.IO) {
    val cached = PinballDataCache.passthroughOrCachedText(url, allowMissing = true)
    if (cached.isMissing) return@withContext 404 to null
    200 to cached.text
}
