package com.pillyliu.pinprofandroid.data

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest

internal const val PINBALL_PRELOAD_ASSET_ROOT = "pinprof-preload"
private const val PINBALL_PRELOAD_MANIFEST_ASSET_PATH = "$PINBALL_PRELOAD_ASSET_ROOT/preload-manifest.json"
internal const val PINBALL_LEGACY_CACHE_RESET_MARKER = "legacy-cache-reset-v4-rulesheets-v1"

internal fun normalizePinballCachePath(urlOrPath: String): String {
    return when {
        urlOrPath.startsWith("http://") || urlOrPath.startsWith("https://") -> java.net.URL(urlOrPath).path
        urlOrPath.startsWith("/") -> urlOrPath
        else -> "/$urlOrPath"
    }
}

internal fun pinballCacheRoot(context: Context): File = File(context.filesDir, "pinball-data-cache")

internal fun pinballCacheResourcesDir(context: Context): File = File(pinballCacheRoot(context), "resources")

internal fun pinballCacheIndexFile(context: Context): File = File(pinballCacheRoot(context), "cache-index.json")

internal fun pinballCacheResourceFile(context: Context, path: String): File {
    val ext = path.substringAfterLast('.', "")
    val digest = pinballCacheSha256(path)
    val fileName = if (ext.isBlank()) digest else "$digest.$ext"
    val dir = pinballCacheResourcesDir(context)
    if (!dir.exists()) dir.mkdirs()
    return File(dir, fileName)
}

internal fun pinballCacheReadBundledPreloadPaths(context: Context): List<String> {
    val manifestText = runCatching {
        context.assets.open(PINBALL_PRELOAD_MANIFEST_ASSET_PATH).bufferedReader().use { it.readText() }
    }.getOrNull() ?: return emptyList()
    val root = runCatching { JSONObject(manifestText) }.getOrNull() ?: return emptyList()
    val paths = root.optJSONArray("paths") ?: return emptyList()
    return buildList {
        for (index in 0 until paths.length()) {
            val value = paths.optString(index).trim()
            if (value.isNotEmpty()) add(value)
        }
    }
}

internal fun pinballCacheReadBundledPreloadBytes(context: Context, path: String): ByteArray? {
    val assetPath = "$PINBALL_PRELOAD_ASSET_ROOT/${normalizePinballCachePath(path).removePrefix("/")}"
    return runCatching { context.assets.open(assetPath).use { it.readBytes() } }.getOrNull()
}

internal fun pinballCacheReadOrInitIndexRoot(context: Context): JSONObject {
    val file = pinballCacheIndexFile(context)
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

internal fun pinballCacheWriteIndexRoot(context: Context, root: JSONObject) {
    pinballCacheIndexFile(context).writeText(root.toString())
}

internal fun pinballCacheSha256(input: String): String {
    val digest = MessageDigest.getInstance("SHA-256").digest(input.toByteArray())
    return digest.joinToString(separator = "") { "%02x".format(it) }
}

internal fun pinballCacheSha256(input: ByteArray): String {
    val digest = MessageDigest.getInstance("SHA-256").digest(input)
    return digest.joinToString(separator = "") { "%02x".format(it) }
}
