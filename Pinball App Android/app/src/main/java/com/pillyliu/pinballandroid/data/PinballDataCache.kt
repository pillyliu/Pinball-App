package com.pillyliu.pinballandroid.data

import android.content.Context
import android.content.res.AssetManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
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
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

private const val BASE_URL = "https://pillyliu.com"
private const val MANIFEST_URL = "https://pillyliu.com/pinball/cache-manifest.json"
private const val UPDATE_LOG_URL = "https://pillyliu.com/pinball/cache-update-log.json"
private const val META_REFRESH_INTERVAL_MS = 5 * 60 * 1000L
private const val STARTER_ASSET_ROOT = "starter-pack/pinball"
private const val STARTER_SEED_MARKER = "starter-pack-seeded-v3-only"
private const val LEGACY_CACHE_RESET_MARKER = "legacy-cache-reset-v3-assets-v1"
private val STARTER_PRIORITY_PATHS = listOf(
    "/pinball/data/pinball_library_v3.json",
    "/pinball/data/LPL_Targets.csv",
    "/pinball/data/LPL_Stats.csv",
    "/pinball/data/LPL_Standings.csv",
    "/pinball/data/redacted_players.csv",
    "/pinball/data/lpl_stats.csv",
)

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
    private val mutex = Mutex()
    private val indexIoLock = Any()
    private val refreshScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val remoteRequestLimiter = Semaphore(8)

    @Volatile
    private var appContext: Context? = null

    @Volatile
    private var loaded = false

    private val manifestFiles = mutableMapOf<String, String>()
    private var lastMetaFetchAt: Long = 0L
    private var lastUpdateScanAt: String? = null

    fun initialize(context: Context) {
        appContext = context.applicationContext
    }

    suspend fun loadText(url: String, allowMissing: Boolean = false): CachedTextResult = withContext(Dispatchers.IO) {
        val path = normalizePath(url)
        ensureLoaded()

        val cached = readCached(path)
        if (cached != null) {
            maybeRevalidateAsync(path, allowMissing)
            return@withContext CachedTextResult(
                text = cached.decodeToString(),
                isMissing = false,
                updatedAtMs = cachedUpdatedAtMs(path),
            )
        }

        val fetched = fetchBytes(path, allowMissing)
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

        val fetched = fetchBytes(path, allowMissing)
        if (fetched.isMissing) {
            return@withContext CachedTextResult(text = null, isMissing = true, updatedAtMs = null)
        }
        val text = fetched.bytes?.decodeToString()
        CachedTextResult(text = text, isMissing = text == null, updatedAtMs = fetched.updatedAtMs)
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

        val fetched = fetchBytes(path, allowMissing)
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
        sha256(local) != remoteHash
    }

    suspend fun cachedUpdatedAtFor(url: String): Long? = withContext(Dispatchers.IO) {
        val path = normalizePath(url)
        ensureLoaded()
        cachedUpdatedAtMs(path)
    }

    suspend fun loadBytes(url: String, allowMissing: Boolean = false): CachedBytesResult = withContext(Dispatchers.IO) {
        val path = normalizePath(url)
        ensureLoaded()

        val cached = readCached(path)
        if (cached != null) {
            maybeRevalidateAsync(path, allowMissing)
            return@withContext CachedBytesResult(bytes = cached, isMissing = false, updatedAtMs = cachedUpdatedAtMs(path))
        }

        fetchBytes(path, allowMissing)
    }

    private suspend fun fetchBytes(path: String, allowMissing: Boolean): CachedBytesResult {
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
                    upsertIndex(path = path, hash = null, missing = true)
                    CachedBytesResult(bytes = null, isMissing = true, updatedAtMs = null)
                } else {
                    if (code !in 200..299) throw IllegalStateException("Fetch failed ($code) for $url")
                    val bytes = conn.inputStream.use { it.readBytes() }
                    writeCached(path, bytes)
                    upsertIndex(path = path, hash = manifestFiles[path], missing = false)
                    CachedBytesResult(bytes = bytes, isMissing = false, updatedAtMs = cachedUpdatedAtMs(path))
                }
            }
        } catch (t: Throwable) {
            val stale = readCached(path)
            if (stale != null) {
                CachedBytesResult(bytes = stale, isMissing = false, updatedAtMs = cachedUpdatedAtMs(path))
            } else {
                throw t
            }
        }
    }

    private fun maybeRevalidateAsync(path: String, allowMissing: Boolean) {
        // Fire-and-forget background refresh to keep startup fast.
        refreshScope.launch {
            try {
                mutex.withLock {
                    fetchBytes(path, allowMissing)
                }
            } catch (_: Throwable) {
            }
        }
    }

    private suspend fun refreshMetadataIfNeeded(force: Boolean) {
        val now = System.currentTimeMillis()
        if (!force && now - lastMetaFetchAt < META_REFRESH_INTERVAL_MS) return

        val manifestText = httpText(MANIFEST_URL)
        val updateText = httpText(UPDATE_LOG_URL)

        val manifestJson = JSONObject(manifestText)
        val filesJson = manifestJson.optJSONObject("files") ?: JSONObject()

        manifestFiles.clear()
        val fileKeys = filesJson.keys()
        while (fileKeys.hasNext()) {
            val path = fileKeys.next()
            val hash = filesJson.optJSONObject(path)?.optString("hash") ?: continue
            manifestFiles[path] = hash
        }

        val updateJson = JSONObject(updateText)
        val events = updateJson.optJSONArray("events") ?: JSONArray()

        var newestEventAt = lastUpdateScanAt
        for (i in 0 until events.length()) {
            val event = events.optJSONObject(i) ?: continue
            val generatedAt = event.optString("generatedAt")
            if (newestEventAt == null || generatedAt > newestEventAt) {
                newestEventAt = generatedAt
            }
            if (lastUpdateScanAt != null && generatedAt <= lastUpdateScanAt!!) {
                continue
            }
            val removed = mutableSetOf<String>()
            collectPaths(event.optJSONArray("removed"), removed)
            removed.forEach { path ->
                deleteCached(path)
                upsertIndex(path = path, hash = null, missing = true)
            }
        }

        lastUpdateScanAt = newestEventAt
        lastMetaFetchAt = now
        persistMetaState()
    }

    private fun collectPaths(array: JSONArray?, into: MutableSet<String>) {
        if (array == null) return
        for (i in 0 until array.length()) {
            val path = array.optString(i)
            if (path.isNotBlank()) into += path
        }
    }

    private suspend fun ensureLoaded() {
        if (loaded) return
        mutex.withLock {
            if (loaded) return
            val context = appContext ?: error("PinballDataCache.initialize(context) was not called")
            val dir = cacheRoot(context)
            if (!dir.exists()) dir.mkdirs()
            purgeLegacyCachedPinballAssetsIfNeeded(context)
            readIndexState()
            preloadPriorityStarterFiles(context)
            loaded = true
            // Do not block first read on full starter-pack copy; reads already lazy-load from assets on miss.
            refreshScope.launch {
                try {
                    seedStarterPackIfNeeded(context)
                } catch (_: Throwable) {
                    // Best effort background seed.
                }
            }
            requestMetadataRefresh(force = true)
        }
    }

    private fun purgeLegacyCachedPinballAssetsIfNeeded(context: Context) {
        val root = cacheRoot(context)
        if (!root.exists()) root.mkdirs()
        val marker = File(root, LEGACY_CACHE_RESET_MARKER)
        if (marker.exists()) return

        runCatching {
            resourcesDir(context).takeIf { it.exists() }?.deleteRecursively()
            indexFile(context).takeIf { it.exists() }?.delete()
            File(root, STARTER_SEED_MARKER).takeIf { it.exists() }?.delete()
        }

        manifestFiles.clear()
        lastMetaFetchAt = 0L
        lastUpdateScanAt = null

        runCatching { marker.writeText("ok") }
    }

    private fun preloadPriorityStarterFiles(context: Context) {
        STARTER_PRIORITY_PATHS.forEach { path ->
            if (readCached(path) != null) return@forEach
            val assetPath = "starter-pack${path}"
            try {
                val bytes = context.assets.open(assetPath).use { it.readBytes() }
                writeCached(path, bytes)
            } catch (_: Throwable) {
                // Best effort preload.
            }
        }
    }

    private fun httpText(url: String): String {
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

    private fun normalizePath(urlOrPath: String): String {
        return when {
            urlOrPath.startsWith("http://") || urlOrPath.startsWith("https://") -> URL(urlOrPath).path
            urlOrPath.startsWith("/") -> urlOrPath
            else -> "/$urlOrPath"
        }
    }

    private fun shouldCacheByManifest(url: String): Boolean {
        return try {
            val parsed = URL(url)
            parsed.host.equals("pillyliu.com", ignoreCase = true) && parsed.path.startsWith("/pinball/")
        } catch (_: Throwable) {
            false
        }
    }

    suspend fun passthroughOrCachedText(url: String, allowMissing: Boolean = false): CachedTextResult {
        if (!shouldCacheByManifest(url)) {
            val text = httpText(url)
            return CachedTextResult(text = text, isMissing = false, updatedAtMs = System.currentTimeMillis())
        }
        return loadText(url, allowMissing)
    }

    suspend fun passthroughOrCachedBytes(url: String, allowMissing: Boolean = false): CachedBytesResult {
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
                CachedBytesResult(bytes = conn.inputStream.use { it.readBytes() }, isMissing = false, updatedAtMs = System.currentTimeMillis())
            }
        }
        return loadBytes(url, allowMissing)
    }

    suspend fun resolveImageModel(url: String): Any {
        if (!shouldCacheByManifest(url)) return url
        val path = normalizePath(url)
        ensureLoaded()
        val cached = readCached(path)
        if (cached != null) {
            maybeRevalidateAsync(path, allowMissing = false)
            return resourceFile(path)
        }
        val fetched = fetchBytes(path, allowMissing = false)
        return if (fetched.bytes != null) resourceFile(path) else url
    }

    private fun cacheRoot(context: Context): File = File(context.filesDir, "pinball-data-cache")

    private fun resourcesDir(context: Context): File = File(cacheRoot(context), "resources")

    private fun indexFile(context: Context): File = File(cacheRoot(context), "cache-index.json")

    private fun resourceFile(path: String): File {
        val context = appContext ?: error("Missing context")
        val ext = path.substringAfterLast('.', "")
        val digest = sha256(path)
        val fileName = if (ext.isBlank()) digest else "$digest.$ext"
        val dir = resourcesDir(context)
        if (!dir.exists()) dir.mkdirs()
        return File(dir, fileName)
    }

    private fun writeCached(path: String, bytes: ByteArray) {
        val file = resourceFile(path)
        file.writeBytes(bytes)
    }

    private fun readCached(path: String): ByteArray? {
        if (isMarkedMissingInIndex(path)) {
            val context = appContext
            if (context != null && path.startsWith("/pinball/")) {
                val assetPath = "starter-pack${path}"
                try {
                    val bytes = context.assets.open(assetPath).use { it.readBytes() }
                    writeCached(path, bytes)
                    upsertIndex(path = path, hash = manifestFiles[path], missing = false)
                    return bytes
                } catch (_: Throwable) {
                    // Fall through to keep missing marker behavior for non-seeded assets.
                }
            }
            deleteCached(path)
            return null
        }
        val file = resourceFile(path)
        if (!file.exists()) {
            val context = appContext
            if (context != null && path.startsWith("/pinball/")) {
                val assetPath = "starter-pack${path}"
                try {
                    val bytes = context.assets.open(assetPath).use { it.readBytes() }
                    writeCached(path, bytes)
                    return bytes
                } catch (_: Throwable) {
                    return null
                }
            }
            return null
        }
        return file.readBytes()
    }

    private fun cachedUpdatedAtMs(path: String): Long? {
        val file = resourceFile(path)
        if (!file.exists()) return null
        val ts = file.lastModified()
        return if (ts > 0L) ts else null
    }

    private fun deleteCached(path: String) {
        val file = resourceFile(path)
        if (file.exists()) file.delete()
    }

    private fun sha256(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(input.toByteArray())
        return digest.joinToString(separator = "") { "%02x".format(it) }
    }

    private fun sha256(input: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(input)
        return digest.joinToString(separator = "") { "%02x".format(it) }
    }

    private fun upsertIndex(path: String, hash: String?, missing: Boolean) {
        val context = appContext ?: return
        synchronized(indexIoLock) {
            val root = readOrInitIndexRoot(context)
            val resources = root.optJSONObject("resources") ?: JSONObject().also { root.put("resources", it) }
            val obj = JSONObject()
                .put("path", path)
                .put("hash", hash)
                .put("missing", missing)
                .put("lastValidatedAt", System.currentTimeMillis())
            resources.put(path, obj)
            root.put("lastMetaFetchAt", lastMetaFetchAt)
            root.put("lastUpdateScanAt", lastUpdateScanAt)
            writeIndexRoot(context, root)
        }
    }

    private fun isMarkedMissingInIndex(path: String): Boolean {
        val context = appContext ?: return false
        return synchronized(indexIoLock) {
            runCatching {
                val root = readOrInitIndexRoot(context)
                val resources = root.optJSONObject("resources") ?: return@runCatching false
                resources.optJSONObject(path)?.optBoolean("missing", false) == true
            }.getOrDefault(false)
        }
    }

    private fun isMissingAndFresh(path: String, maxCacheAgeMs: Long): Boolean {
        val context = appContext ?: return false
        return synchronized(indexIoLock) {
            runCatching {
                val root = readOrInitIndexRoot(context)
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
            val root = readOrInitIndexRoot(context)
            lastMetaFetchAt = root.optLong("lastMetaFetchAt", 0L)
            lastUpdateScanAt = root.optString("lastUpdateScanAt").takeIf { it.isNotBlank() }
        }
    }

    private fun persistMetaState() {
        val context = appContext ?: return
        synchronized(indexIoLock) {
            val root = readOrInitIndexRoot(context)
            root.put("lastMetaFetchAt", lastMetaFetchAt)
            root.put("lastUpdateScanAt", lastUpdateScanAt)
            if (!root.has("resources")) {
                root.put("resources", JSONObject())
            }
            writeIndexRoot(context, root)
        }
    }

    private fun readOrInitIndexRoot(context: Context): JSONObject {
        val file = indexFile(context)
        val root = if (!file.exists()) {
            JSONObject()
        } else {
            runCatching { JSONObject(file.readText()) }.getOrElse {
                file.delete()
                JSONObject()
            }
        }
        if (!root.has("resources") || root.optJSONObject("resources") == null) {
            root.put("resources", JSONObject())
        }
        return root
    }

    private fun writeIndexRoot(context: Context, root: JSONObject) {
        indexFile(context).writeText(root.toString())
    }

    private fun hasUsableNetwork(context: Context?): Boolean {
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

    private fun seedStarterPackIfNeeded(context: Context) {
        val marker = File(cacheRoot(context), STARTER_SEED_MARKER)
        if (marker.exists()) return

        try {
            val roots = context.assets.list(STARTER_ASSET_ROOT) ?: return
            if (roots.isEmpty()) return
            copyStarterAssetTree(context.assets, STARTER_ASSET_ROOT, "/pinball")
            marker.writeText("ok")
        } catch (_: Throwable) {
            // Starter pack seeding is best effort.
        }
    }

    private fun copyStarterAssetTree(assets: AssetManager, assetPath: String, cachePath: String) {
        val children = assets.list(assetPath) ?: return
        if (children.isEmpty()) {
            if (readCached(cachePath) == null) {
                val bytes = assets.open(assetPath).use { it.readBytes() }
                writeCached(cachePath, bytes)
            }
            return
        }

        children.forEach { child ->
            copyStarterAssetTree(
                assets = assets,
                assetPath = "$assetPath/$child",
                cachePath = "$cachePath/$child",
            )
        }
    }
}
