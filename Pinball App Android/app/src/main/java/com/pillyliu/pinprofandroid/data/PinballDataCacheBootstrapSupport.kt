package com.pillyliu.pinprofandroid.data

import android.content.Context

internal fun ensurePinballCacheRootExists(context: Context) {
    val dir = pinballCacheRoot(context)
    if (!dir.exists()) dir.mkdirs()
}

internal fun purgeLegacyPinballCacheIfNeeded(context: Context): Boolean {
    ensurePinballCacheRootExists(context)
    val marker = java.io.File(pinballCacheRoot(context), PINBALL_LEGACY_CACHE_RESET_MARKER)
    if (marker.exists()) return false

    runCatching {
        pinballCacheResourcesDir(context).takeIf { it.exists() }?.deleteRecursively()
        pinballCacheIndexFile(context).takeIf { it.exists() }?.delete()
    }
    runCatching { marker.writeText("ok") }
    return true
}

internal fun seedBundledPinballPreloadIfNeeded(
    context: Context,
    resourceExists: (String) -> Boolean,
    readBundledBytes: (String) -> ByteArray?,
    writeCached: (String, ByteArray) -> Unit,
    upsertIndex: (String) -> Unit,
) {
    val paths = pinballCacheReadBundledPreloadPaths(context)
    paths.forEach { rawPath ->
        val normalizedPath = normalizePinballCachePath(rawPath)
        if (resourceExists(normalizedPath)) {
            upsertIndex(normalizedPath)
            return@forEach
        }

        val bundledBytes = readBundledBytes(normalizedPath)
            ?: throw IllegalStateException("Missing bundled preload asset for $normalizedPath")
        writeCached(normalizedPath, bundledBytes)
        upsertIndex(normalizedPath)
    }
}
