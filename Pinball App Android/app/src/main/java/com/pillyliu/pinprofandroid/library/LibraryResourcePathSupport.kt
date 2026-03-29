package com.pillyliu.pinprofandroid.library

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.net.URL

internal const val libraryMissingArtworkPath = "/pinball/images/playfields/fallback-image-not-available_2048.webp"

private val pinProfHosts = setOf(
    "pillyliu.com",
    "www.pillyliu.com",
    "pinprof.com",
    "www.pinprof.com",
)

internal enum class LivePlayfieldKind {
    PILLYLIU,
    OPDB,
    EXTERNAL,
    MISSING,
}

internal data class LivePlayfieldStatus(
    val effectiveKind: LivePlayfieldKind,
    val effectiveUrl: String?,
)

internal suspend fun loadLivePlayfieldStatus(practiceIdentity: String?): LivePlayfieldStatus? = withContext(Dispatchers.IO) {
    val normalizedPracticeIdentity = practiceIdentity?.trim()?.takeIf { it.isNotEmpty() } ?: return@withContext null
    val route = URLEncoder.encode("public/playfield-status/$normalizedPracticeIdentity", Charsets.UTF_8.name())
    val requestUrl = "https://pillyliu.com/pinprof-admin/api.php?route=$route"
    val connection = (URL(requestUrl).openConnection() as HttpURLConnection).apply {
        connectTimeout = 15_000
        readTimeout = 15_000
        requestMethod = "GET"
        setRequestProperty("Cache-Control", "no-cache")
    }
    try {
        val code = connection.responseCode
        if (code !in 200..299) return@withContext null
        val payload = connection.inputStream.bufferedReader().use { it.readText() }
        val json = JSONObject(payload)
        val kind = when (json.optString("effectiveKind").lowercase()) {
            "pillyliu" -> LivePlayfieldKind.PILLYLIU
            "opdb" -> LivePlayfieldKind.OPDB
            "external" -> LivePlayfieldKind.EXTERNAL
            "missing" -> LivePlayfieldKind.MISSING
            else -> return@withContext null
        }
        LivePlayfieldStatus(
            effectiveKind = kind,
            effectiveUrl = resolveLibraryUrl(json.optString("effectiveUrl").ifBlank { null }),
        )
    } catch (_: Throwable) {
        null
    } finally {
        connection.disconnect()
    }
}

internal fun resolveLibraryUrl(pathOrUrl: String?): String? {
    val normalized = normalizedOptionalString(pathOrUrl) ?: return null
    if (normalized.startsWith("http://") || normalized.startsWith("https://")) return normalized
    return if (normalized.startsWith("/")) "https://pillyliu.com$normalized" else "https://pillyliu.com/$normalized"
}

internal fun isPinProfHost(host: String?): Boolean =
    host?.lowercase()?.let(pinProfHosts::contains) == true

internal fun isPinProfPlayfieldUrl(url: String?): Boolean {
    val resolved = resolveLibraryUrl(url) ?: return false
    return runCatching {
        val parsed = URL(resolved)
        isPinProfHost(parsed.host) && parsed.path.startsWith("/pinball/images/playfields/")
    }.getOrDefault(false)
}

internal fun isPinProfRulesheetUrl(url: String?): Boolean {
    val resolved = resolveLibraryUrl(url) ?: return false
    return runCatching {
        val parsed = URL(resolved)
        isPinProfHost(parsed.host) && parsed.path.startsWith("/pinball/rulesheets/")
    }.getOrDefault(false)
}

internal fun normalizeLibraryPlayfieldLocalPath(path: String?): String? {
    val raw = normalizedOptionalString(path) ?: return null
    val target = when {
        raw.endsWith("_700.webp", ignoreCase = true) -> raw
        raw.endsWith("_1400.webp", ignoreCase = true) -> raw.replace(Regex("_1400\\.webp$", RegexOption.IGNORE_CASE), "_700.webp")
        raw.contains("/pinball/images/playfields/") -> raw.replace(Regex("\\.[A-Za-z0-9]+$"), "_700.webp")
        else -> raw
    }
    return target
}

internal fun normalizeLibraryCachePath(path: String?): String? {
    val raw = normalizedOptionalString(path) ?: return null
    fun normalizePlayfieldPublishedPath(value: String): String =
        value.replace(Regex("(/pinball/images/playfields/.+?)(?:_(700|1400))?\\.[A-Za-z0-9]+$", RegexOption.IGNORE_CASE), "$1.webp")
    if (raw.startsWith("/")) {
        return if (raw.contains("/pinball/images/playfields/")) normalizePlayfieldPublishedPath(raw) else raw
    }
    if (raw.startsWith("http://") || raw.startsWith("https://")) {
        return try {
            val uri = java.net.URI(raw)
            if (uri.host?.equals("pillyliu.com", ignoreCase = true) == true) {
                uri.path?.takeIf { it.isNotBlank() }?.let {
                    if (it.contains("/pinball/images/playfields/")) normalizePlayfieldPublishedPath(it) else it
                } ?: raw
            } else {
                raw
            }
        } catch (_: Exception) {
            raw
        }
    }
    val normalized = "/$raw"
    return if (normalized.contains("/pinball/images/playfields/")) normalizePlayfieldPublishedPath(normalized) else normalized
}

internal fun PinballGame.resolve(pathOrUrl: String?): String? =
    resolveLibraryUrl(pathOrUrl)

internal fun hostedRenderedRulesheetPageUrl(slug: String, source: String? = null): String {
    val encodedSlug = URLEncoder.encode(slug, Charsets.UTF_8.name())
    val encodedSource = source?.trim()?.takeIf { it.isNotEmpty() }
        ?.let { URLEncoder.encode(it, Charsets.UTF_8.name()) }
    return if (encodedSource != null) {
        "https://pillyliu.com/rules/$encodedSlug?source=$encodedSource"
    } else {
        "https://pillyliu.com/rules/$encodedSlug"
    }
}
