package com.pillyliu.pinprofandroid.data

import com.pillyliu.pinprofandroid.library.HostedPinballRefreshTarget
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

internal suspend fun PinballDataCache.refreshHostedResourcesIfNeeded(
    targets: List<HostedPinballRefreshTarget>,
    forceMetadataRefresh: Boolean = true,
): Set<String> = withContext(Dispatchers.IO) {
    ensureLoaded()

    mutex.withLock {
        val trackedPaths = targets.mapTo(linkedSetOf()) { normalizePath(it.path) }
        val changedPaths = refreshMetadataIfNeeded(force = forceMetadataRefresh)
            .filterTo(linkedSetOf()) { it in trackedPaths }

        targets.forEach { target ->
            val normalizedPath = normalizePath(target.path)
            if (normalizedPath in changedPaths) return@forEach
            if (!hostedResourceNeedsRefresh(normalizedPath, target.allowMissing)) return@forEach

            val previousBytes = readCached(normalizedPath)
            val fetched = runtimeFetchBytes(
                path = normalizedPath,
                allowMissing = target.allowMissing,
                allowStaleOnFailure = false,
            )
            val refreshedBytes = if (fetched.isMissing) null else readCached(normalizedPath)
            if (!nullableContentEquals(previousBytes, refreshedBytes)) {
                changedPaths += normalizedPath
            }
        }

        changedPaths
    }
}

internal suspend fun PinballDataCache.runtimeLoadBytes(
    url: String,
    allowMissing: Boolean = false,
): CachedBytesResult = withContext(Dispatchers.IO) {
    val path = normalizePath(url)
    ensureLoaded()

    val cached = readCached(path)
    if (cached != null) {
        scheduleRuntimeRevalidate(path, allowMissing)
        return@withContext CachedBytesResult(
            bytes = cached,
            isMissing = false,
            updatedAtMs = cachedUpdatedAtMs(path),
        )
    }

    runtimeFetchBytes(path, allowMissing)
}

internal suspend fun PinballDataCache.runtimeFetchBytes(
    path: String,
    allowMissing: Boolean,
    allowStaleOnFailure: Boolean = true,
): CachedBytesResult {
    val fetchGeneration = cacheGeneration
    if (!hasUsableNetwork(appContext)) {
        val stale = readCached(path)
        if (stale != null) {
            return CachedBytesResult(bytes = stale, isMissing = false)
        }
        if (allowMissing) {
            upsertIndex(path = path, hash = null, missing = true)
            return CachedBytesResult(bytes = null, isMissing = true, updatedAtMs = null)
        }
        throw IllegalStateException("Offline and no cached file for $path")
    }

    try {
        refreshMetadataIfNeeded(force = false)
    } catch (_: Throwable) {
        // Metadata refresh is best effort and should not block direct fetch attempts.
    }

    val url = "$BASE_URL$path"
    return try {
        remoteRequestLimiter.withPermit {
            val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15000
                readTimeout = 20000
                requestMethod = "GET"
                setRequestProperty("Cache-Control", "no-cache")
            }

            val code = conn.responseCode
            if (code == 404 && allowMissing) {
                ensureRuntimeActiveGeneration(fetchGeneration)
                upsertIndex(path = path, hash = null, missing = true)
                CachedBytesResult(bytes = null, isMissing = true, updatedAtMs = null)
            } else {
                if (code !in 200..299) throw IllegalStateException("Fetch failed ($code) for $url")
                val bytes = conn.inputStream.use { it.readBytes() }
                ensureRuntimeActiveGeneration(fetchGeneration)
                writeCached(path, bytes)
                upsertIndex(path = path, hash = manifestFiles[path], missing = false)
                CachedBytesResult(bytes = bytes, isMissing = false, updatedAtMs = cachedUpdatedAtMs(path))
            }
        }
    } catch (t: Throwable) {
        val stale = readCached(path)
        if (allowStaleOnFailure && stale != null) {
            CachedBytesResult(bytes = stale, isMissing = false, updatedAtMs = cachedUpdatedAtMs(path))
        } else {
            throw t
        }
    }
}

internal fun PinballDataCache.scheduleRuntimeRevalidate(path: String, allowMissing: Boolean) {
    // Fire-and-forget background refresh to keep startup fast.
    refreshScope.launch {
        try {
            mutex.withLock {
                runtimeFetchBytes(path, allowMissing)
            }
        } catch (_: Throwable) {
        }
    }
}

internal fun PinballDataCache.ensureRuntimeActiveGeneration(generation: Long) {
    if (generation != cacheGeneration) {
        throw CancellationException("Discarding stale cache write for generation $generation")
    }
}

internal suspend fun PinballDataCache.runtimePassthroughOrCachedText(
    url: String,
    allowMissing: Boolean = false,
): CachedTextResult {
    if (!shouldCacheByManifest(url)) {
        val text = httpText(url)
        return CachedTextResult(text = text, isMissing = false, updatedAtMs = System.currentTimeMillis())
    }
    return loadText(url, allowMissing)
}

internal suspend fun PinballDataCache.runtimePassthroughOrCachedBytes(
    url: String,
    allowMissing: Boolean = false,
): CachedBytesResult {
    if (!shouldCacheByManifest(url)) {
        return remoteRequestLimiter.withPermit {
            val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15000
                readTimeout = 20000
                requestMethod = "GET"
            }
            val code = conn.responseCode
            if (code == 404 && allowMissing) return@withPermit CachedBytesResult(bytes = null, isMissing = true)
            if (code !in 200..299) throw IllegalStateException("Fetch failed ($code) for $url")
            CachedBytesResult(
                bytes = conn.inputStream.use { it.readBytes() },
                isMissing = false,
                updatedAtMs = System.currentTimeMillis(),
            )
        }
    }
    return runtimeLoadBytes(url, allowMissing)
}

internal suspend fun PinballDataCache.runtimeResolveImageModel(url: String): Any {
    if (!shouldCacheByManifest(url)) return url
    val path = normalizePath(url)
    ensureLoaded()
    val cached = readCached(path)
    if (cached != null) {
        scheduleRuntimeRevalidate(path, allowMissing = false)
        return resourceFile(path)
    }
    val fetched = runtimeFetchBytes(path, allowMissing = false)
    return if (fetched.bytes != null) resourceFile(path) else url
}

private fun PinballDataCache.hostedResourceNeedsRefresh(path: String, allowMissing: Boolean): Boolean {
    val remoteHash = manifestFiles[path]
    if (remoteHash != null) {
        val localBytes = readCached(path) ?: return true
        return pinballCacheSha256(localBytes) != remoteHash
    }
    return !allowMissing
}

private fun nullableContentEquals(left: ByteArray?, right: ByteArray?): Boolean {
    if (left === right) return true
    if (left == null || right == null) return false
    return left.contentEquals(right)
}
