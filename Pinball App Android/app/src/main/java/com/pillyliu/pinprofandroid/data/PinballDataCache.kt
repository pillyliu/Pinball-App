package com.pillyliu.pinprofandroid.data

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.pillyliu.pinprofandroid.library.HOSTED_PINBALL_REFRESH_TARGETS
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

internal const val BASE_URL = "https://pillyliu.com"
internal const val MANIFEST_URL = "https://pillyliu.com/pinball/cache-manifest.json"
internal const val UPDATE_LOG_URL = "https://pillyliu.com/pinball/cache-update-log.json"
internal const val META_REFRESH_INTERVAL_MS = 5 * 60 * 1000L
data class CachedTextResult(
    val text: String?,
    val isMissing: Boolean,
    val updatedAtMs: Long? = null,
)

data class CachedBytesResult(
    val bytes: ByteArray?,
    val isMissing: Boolean,
    val updatedAtMs: Long? = null,
)

object PinballDataCache {
    internal val mutex = Mutex()
    internal val indexIoLock = Any()
    internal val refreshScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    internal val remoteRequestLimiter = Semaphore(8)

    @Volatile
    internal var appContext: Context? = null

    @Volatile
    internal var loaded = false

    @Volatile
    internal var cacheGeneration = 0L

    internal val manifestFiles = mutableMapOf<String, String>()
    internal var lastMetaFetchAt: Long = 0L
    internal var lastUpdateScanAt: String? = null

    fun initialize(context: Context) {
        appContext = context.applicationContext
    }

    suspend fun loadText(url: String, allowMissing: Boolean = false): CachedTextResult = withContext(Dispatchers.IO) {
        val path = normalizePath(url)
        ensureLoaded()

        val cached = readCached(path)
        if (cached != null) {
            scheduleRuntimeRevalidate(path, allowMissing)
            return@withContext CachedTextResult(
                text = cached.decodeToString(),
                isMissing = false,
                updatedAtMs = cachedUpdatedAtMs(path),
            )
        }

        val fetched = runtimeFetchBytes(path, allowMissing)
        if (fetched.isMissing) {
            return@withContext CachedTextResult(
                text = null,
                isMissing = true,
                updatedAtMs = null,
            )
        }

        val text = fetched.bytes?.decodeToString()
        CachedTextResult(text = text, isMissing = text == null, updatedAtMs = fetched.updatedAtMs)
    }

    suspend fun forceRefreshText(url: String, allowMissing: Boolean = false): CachedTextResult = withContext(Dispatchers.IO) {
        val path = normalizePath(url)
        ensureLoaded()

        val fetched = runtimeFetchBytes(path, allowMissing, allowStaleOnFailure = false)
        if (fetched.isMissing) {
            return@withContext CachedTextResult(text = null, isMissing = true, updatedAtMs = null)
        }
        val text = fetched.bytes?.decodeToString()
        CachedTextResult(text = text, isMissing = text == null, updatedAtMs = fetched.updatedAtMs)
    }

    suspend fun forceRefreshHostedLibraryData() = withContext(Dispatchers.IO) {
        ensureLoaded()
        refreshMetadataIfNeeded(force = true)
        HOSTED_PINBALL_REFRESH_TARGETS.forEach { target ->
            runtimeFetchBytes(
                path = target.path,
                allowMissing = target.allowMissing,
                allowStaleOnFailure = false,
            )
        }
    }

    suspend fun clearAllCachedData() = withContext(Dispatchers.IO) {
        ensureLoaded()
        mutex.withLock {
            cacheGeneration += 1

            val context = appContext ?: error("PinballDataCache.initialize(context) was not called")
            val root = pinballCacheRoot(context)
            val resources = pinballCacheResourcesDir(context)
            val index = pinballCacheIndexFile(context)

            if (resources.exists()) {
                resources.deleteRecursively()
            }
            if (index.exists()) {
                index.delete()
            }

            manifestFiles.clear()
            lastMetaFetchAt = 0L
            lastUpdateScanAt = null

            if (!root.exists()) {
                root.mkdirs()
            }
            pinballCacheWriteIndexRoot(context, JSONObject().put("resources", JSONObject()))
        }
    }

    suspend fun loadText(url: String, allowMissing: Boolean = false, maxCacheAgeMs: Long): CachedTextResult = withContext(Dispatchers.IO) {
        val path = normalizePath(url)
        ensureLoaded()

        if (isMissingAndFresh(path, maxCacheAgeMs)) {
            return@withContext CachedTextResult(text = null, isMissing = true, updatedAtMs = null)
        }

        val cached = readCached(path)
        val updatedAtMs = cachedUpdatedAtMs(path)
        if (cached != null && updatedAtMs != null && System.currentTimeMillis() - updatedAtMs < maxCacheAgeMs) {
            return@withContext CachedTextResult(
                text = cached.decodeToString(),
                isMissing = false,
                updatedAtMs = updatedAtMs,
            )
        }

        val fetched = runtimeFetchBytes(path, allowMissing)
        if (fetched.isMissing) {
            return@withContext CachedTextResult(text = null, isMissing = true, updatedAtMs = null)
        }

        val text = fetched.bytes?.decodeToString()
        CachedTextResult(text = text, isMissing = text == null, updatedAtMs = fetched.updatedAtMs)
    }

    suspend fun hasRemoteUpdate(url: String): Boolean = withContext(Dispatchers.IO) {
        val path = normalizePath(url)
        ensureLoaded()
        try {
            refreshMetadataIfNeeded(force = true)
        } catch (_: Throwable) {
            return@withContext false
        }

        val remoteHash = manifestFiles[path] ?: return@withContext false
        val local = readCached(path) ?: return@withContext false
        pinballCacheSha256(local) != remoteHash
    }

    suspend fun cachedUpdatedAtFor(url: String): Long? = withContext(Dispatchers.IO) {
        val path = normalizePath(url)
        ensureLoaded()
        cachedUpdatedAtMs(path)
    }

    suspend fun loadBytes(url: String, allowMissing: Boolean = false): CachedBytesResult =
        runtimeLoadBytes(url, allowMissing)

    internal suspend fun refreshMetadataIfNeeded(force: Boolean) {
        val now = System.currentTimeMillis()
        if (!shouldRefreshPinballCacheMetadata(lastMetaFetchAt, now, META_REFRESH_INTERVAL_MS, force)) return

        val refresh = fetchPinballCacheMetadataRefresh(
            manifestUrl = MANIFEST_URL,
            updateLogUrl = UPDATE_LOG_URL,
            now = now,
            lastUpdateScanAt = lastUpdateScanAt,
            httpText = ::httpText,
        )

        manifestFiles.clear()
        manifestFiles.putAll(refresh.manifestFiles)
        refresh.removedPaths.forEach { path ->
            deleteCached(path)
            upsertIndex(path = path, hash = null, missing = true)
        }

        lastUpdateScanAt = refresh.lastUpdateScanAt
        lastMetaFetchAt = refresh.lastMetaFetchAt
        persistMetaState()
    }

    internal suspend fun ensureLoaded() {
        if (loaded) return
        mutex.withLock {
            if (loaded) return
            val context = appContext ?: error("PinballDataCache.initialize(context) was not called")
            ensurePinballCacheRootExists(context)
            if (purgeLegacyPinballCacheIfNeeded(context)) {
                manifestFiles.clear()
                lastMetaFetchAt = 0L
                lastUpdateScanAt = null
            }
            readIndexState()
            seedBundledPinballPreloadIfNeeded(
                context = context,
                resourceExists = { path -> resourceFile(path).exists() },
                readBundledBytes = { path -> pinballCacheReadBundledPreloadBytes(context, path) },
                writeCached = { path, bytes -> writeCached(path, bytes) },
                upsertIndex = { path -> upsertIndex(path = path, hash = manifestFiles[path], missing = false) },
            )
            loaded = true
            requestMetadataRefresh(force = true)
        }
    }

    internal fun httpText(url: String): String {
        return kotlinx.coroutines.runBlocking(Dispatchers.IO) {
            remoteRequestLimiter.withPermit {
                val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 15000
                    readTimeout = 20000
                    requestMethod = "GET"
                    setRequestProperty("Cache-Control", "no-cache")
                }
                val code = conn.responseCode
                if (code !in 200..299) throw IllegalStateException("Fetch failed ($code) for $url")
                conn.inputStream.bufferedReader().use { it.readText() }
            }
        }
    }

    internal fun normalizePath(urlOrPath: String): String {
        return when {
            urlOrPath.startsWith("http://") || urlOrPath.startsWith("https://") -> URL(urlOrPath).path
            urlOrPath.startsWith("/") -> urlOrPath
            else -> "/$urlOrPath"
        }
    }

    internal fun shouldCacheByManifest(urlOrPath: String): Boolean {
        val isAbsoluteUrl = urlOrPath.startsWith("http://") || urlOrPath.startsWith("https://")
        val normalizedPath = runCatching { normalizePath(urlOrPath) }.getOrDefault(urlOrPath)
        if (!isAbsoluteUrl && normalizedPath.startsWith("/pinball/")) {
            return true
        }
        return try {
            val parsed = URL(urlOrPath)
            parsed.host.equals("pillyliu.com", ignoreCase = true) && parsed.path.startsWith("/pinball/")
        } catch (_: Throwable) {
            false
        }
    }

    suspend fun passthroughOrCachedText(url: String, allowMissing: Boolean = false): CachedTextResult =
        runtimePassthroughOrCachedText(url, allowMissing)

    suspend fun passthroughOrCachedBytes(url: String, allowMissing: Boolean = false): CachedBytesResult =
        runtimePassthroughOrCachedBytes(url, allowMissing)

    suspend fun resolveImageModel(url: String): Any = runtimeResolveImageModel(url)

    internal fun resourceFile(path: String): java.io.File {
        val context = appContext ?: error("Missing context")
        return pinballCacheResourceFile(context, path)
    }

    internal fun writeCached(path: String, bytes: ByteArray) {
        val file = resourceFile(path)
        file.writeBytes(bytes)
    }

    internal fun readCached(path: String): ByteArray? {
        if (isMarkedMissingInIndex(path)) {
            deleteCached(path)
        }
        val file = resourceFile(path)
        if (!file.exists()) return null
        return file.readBytes()
    }

    internal fun cachedUpdatedAtMs(path: String): Long? {
        val file = resourceFile(path)
        if (!file.exists()) return null
        val ts = file.lastModified()
        return if (ts > 0L) ts else null
    }

    private fun deleteCached(path: String) {
        val file = resourceFile(path)
        if (file.exists()) file.delete()
    }

    internal fun upsertIndex(path: String, hash: String?, missing: Boolean) {
        val context = appContext ?: return
        synchronized(indexIoLock) {
            val root = pinballCacheReadOrInitIndexRoot(context)
            val resources = root.optJSONObject("resources") ?: JSONObject().also { root.put("resources", it) }
            val obj = JSONObject()
                .put("path", path)
                .put("hash", hash)
                .put("missing", missing)
                .put("lastValidatedAt", System.currentTimeMillis())
            resources.put(path, obj)
            root.put("lastMetaFetchAt", lastMetaFetchAt)
            root.put("lastUpdateScanAt", lastUpdateScanAt)
            pinballCacheWriteIndexRoot(context, root)
        }
    }

    private fun isMarkedMissingInIndex(path: String): Boolean {
        val context = appContext ?: return false
        return synchronized(indexIoLock) {
            runCatching {
                val root = pinballCacheReadOrInitIndexRoot(context)
                val resources = root.optJSONObject("resources") ?: return@runCatching false
                resources.optJSONObject(path)?.optBoolean("missing", false) == true
            }.getOrDefault(false)
        }
    }

    private fun isMissingAndFresh(path: String, maxCacheAgeMs: Long): Boolean {
        val context = appContext ?: return false
        return synchronized(indexIoLock) {
            runCatching {
                val root = pinballCacheReadOrInitIndexRoot(context)
                val resources = root.optJSONObject("resources") ?: return@runCatching false
                val resource = resources.optJSONObject(path) ?: return@runCatching false
                val missing = resource.optBoolean("missing", false)
                val lastValidatedAt = resource.optLong("lastValidatedAt", 0L)
                missing && lastValidatedAt > 0L && (System.currentTimeMillis() - lastValidatedAt) < maxCacheAgeMs
            }.getOrDefault(false)
        }
    }

    private fun readIndexState() {
        val context = appContext ?: return
        synchronized(indexIoLock) {
            val root = pinballCacheReadOrInitIndexRoot(context)
            lastMetaFetchAt = root.optLong("lastMetaFetchAt", 0L)
            lastUpdateScanAt = root.optString("lastUpdateScanAt").takeIf { it.isNotBlank() }
        }
    }

    private fun persistMetaState() {
        val context = appContext ?: return
        synchronized(indexIoLock) {
            val root = pinballCacheReadOrInitIndexRoot(context)
            root.put("lastMetaFetchAt", lastMetaFetchAt)
            root.put("lastUpdateScanAt", lastUpdateScanAt)
            if (!root.has("resources")) {
                root.put("resources", JSONObject())
            }
            pinballCacheWriteIndexRoot(context, root)
        }
    }

    internal fun hasUsableNetwork(context: Context?): Boolean {
        context ?: return false
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
        val network = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(network) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    fun requestMetadataRefresh(force: Boolean = true) {
        refreshScope.launch {
            try {
                mutex.withLock {
                    if (!loaded) return@withLock
                    refreshMetadataIfNeeded(force = force)
                }
            } catch (_: Throwable) {
                // Keep existing cache if metadata refresh fails.
            }
        }
    }
}
