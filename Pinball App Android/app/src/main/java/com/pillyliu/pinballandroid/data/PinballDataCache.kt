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
import kotlinx.coroutines.sync.withLock
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
private const val STARTER_SEED_MARKER = "starter-pack-seeded-v1"

data class CachedTextResult(
    val text: String?,
    val isMissing: Boolean,
)

data class CachedBytesResult(
    val bytes: ByteArray?,
    val isMissing: Boolean,
)

object PinballDataCache {
    private val mutex = Mutex()
    private val refreshScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

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
            )
        }

        val fetched = fetchBytes(path, allowMissing)
        if (fetched.isMissing) {
            return@withContext CachedTextResult(
                text = null,
                isMissing = true,
            )
        }

        val text = fetched.bytes?.decodeToString()
        CachedTextResult(text = text, isMissing = text == null)
    }

    suspend fun loadBytes(url: String, allowMissing: Boolean = false): CachedBytesResult = withContext(Dispatchers.IO) {
        val path = normalizePath(url)
        ensureLoaded()

        val cached = readCached(path)
        if (cached != null) {
            maybeRevalidateAsync(path, allowMissing)
            return@withContext CachedBytesResult(bytes = cached, isMissing = false)
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
                return CachedBytesResult(bytes = null, isMissing = true)
            }
            throw IllegalStateException("Offline and no cached file for $path")
        }

        try {
            refreshMetadataIfNeeded(force = false)
        } catch (_: Throwable) {
            // Metadata refresh is best effort and should not block direct fetch attempts.
        }

        if (allowMissing && manifestFiles[path] == null) {
            upsertIndex(path = path, hash = null, missing = true)
            return CachedBytesResult(bytes = null, isMissing = true)
        }

        val url = "$BASE_URL$path"
        return try {
            val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15000
                readTimeout = 20000
                requestMethod = "GET"
                setRequestProperty("Cache-Control", "no-cache")
            }

            val code = conn.responseCode
            if (code == 404 && allowMissing) {
                upsertIndex(path = path, hash = null, missing = true)
                CachedBytesResult(bytes = null, isMissing = true)
            } else {
                if (code !in 200..299) throw IllegalStateException("Fetch failed ($code) for $url")
                val bytes = conn.inputStream.use { it.readBytes() }
                writeCached(path, bytes)
                upsertIndex(path = path, hash = manifestFiles[path], missing = false)
                CachedBytesResult(bytes = bytes, isMissing = false)
            }
        } catch (t: Throwable) {
            val stale = readCached(path)
            if (stale != null) {
                CachedBytesResult(bytes = stale, isMissing = false)
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

        val changed = mutableSetOf<String>()
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
            collectPaths(event.optJSONArray("added"), changed)
            collectPaths(event.optJSONArray("changed"), changed)
            val removed = mutableSetOf<String>()
            collectPaths(event.optJSONArray("removed"), removed)
            removed.forEach { path ->
                changed += path
                deleteCached(path)
                removeFromIndex(path)
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
        mutex.withLock {
            if (loaded) return
            val context = appContext ?: error("PinballDataCache.initialize(context) was not called")
            val dir = cacheRoot(context)
            if (!dir.exists()) dir.mkdirs()
            readIndexState()
            seedStarterPackIfNeeded(context)
            loaded = true
            requestMetadataRefresh(force = true)
        }
    }

    private fun httpText(url: String): String {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15000
            readTimeout = 20000
            requestMethod = "GET"
            setRequestProperty("Cache-Control", "no-cache")
        }
        val code = conn.responseCode
        if (code !in 200..299) throw IllegalStateException("Fetch failed ($code) for $url")
        return conn.inputStream.bufferedReader().use { it.readText() }
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
            return CachedTextResult(text = text, isMissing = false)
        }
        return loadText(url, allowMissing)
    }

    suspend fun passthroughOrCachedBytes(url: String, allowMissing: Boolean = false): CachedBytesResult {
        if (!shouldCacheByManifest(url)) {
            val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15000
                readTimeout = 20000
                requestMethod = "GET"
            }
            val code = conn.responseCode
            if (code == 404 && allowMissing) return CachedBytesResult(bytes = null, isMissing = true)
            if (code !in 200..299) throw IllegalStateException("Fetch failed ($code) for $url")
            return CachedBytesResult(bytes = conn.inputStream.use { it.readBytes() }, isMissing = false)
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
        val file = resourceFile(path)
        if (!file.exists()) return null
        return file.readBytes()
    }

    private fun deleteCached(path: String) {
        val file = resourceFile(path)
        if (file.exists()) file.delete()
    }

    private fun sha256(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(input.toByteArray())
        return digest.joinToString(separator = "") { "%02x".format(it) }
    }

    private fun upsertIndex(path: String, hash: String?, missing: Boolean) {
        val context = appContext ?: return
        val file = indexFile(context)
        val root = if (file.exists()) JSONObject(file.readText()) else JSONObject()
        val resources = root.optJSONObject("resources") ?: JSONObject().also { root.put("resources", it) }
        val obj = JSONObject()
            .put("path", path)
            .put("hash", hash)
            .put("missing", missing)
            .put("lastValidatedAt", System.currentTimeMillis())
        resources.put(path, obj)
        root.put("lastMetaFetchAt", lastMetaFetchAt)
        root.put("lastUpdateScanAt", lastUpdateScanAt)
        file.writeText(root.toString())
    }

    private fun removeFromIndex(path: String) {
        val context = appContext ?: return
        val file = indexFile(context)
        if (!file.exists()) return
        val root = JSONObject(file.readText())
        val resources = root.optJSONObject("resources") ?: return
        resources.remove(path)
        file.writeText(root.toString())
    }

    private fun readIndexState() {
        val context = appContext ?: return
        val file = indexFile(context)
        if (!file.exists()) return
        val root = JSONObject(file.readText())
        lastMetaFetchAt = root.optLong("lastMetaFetchAt", 0L)
        lastUpdateScanAt = root.optString("lastUpdateScanAt").takeIf { it.isNotBlank() }
    }

    private fun persistMetaState() {
        val context = appContext ?: return
        val file = indexFile(context)
        val root = if (file.exists()) JSONObject(file.readText()) else JSONObject()
        root.put("lastMetaFetchAt", lastMetaFetchAt)
        root.put("lastUpdateScanAt", lastUpdateScanAt)
        if (!root.has("resources")) {
            root.put("resources", JSONObject())
        }
        file.writeText(root.toString())
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
