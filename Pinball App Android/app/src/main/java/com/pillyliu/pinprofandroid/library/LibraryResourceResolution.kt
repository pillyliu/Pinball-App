package com.pillyliu.pinprofandroid.library

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

private const val FALLBACK_WHITEWOOD_PLAYFIELD_700 = "/pinball/images/playfields/fallback-whitewood-playfield_700.webp"
private const val FALLBACK_WHITEWOOD_PLAYFIELD_1400 = "/pinball/images/playfields/fallback-whitewood-playfield_1400.webp"
private val supportedPlayfieldOriginalExtensions = listOf("webp", "jpg", "jpeg", "png")

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

internal data class PlayfieldOption(
    val label: String,
    val candidates: List<String>,
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
    pathOrUrl ?: return null
    if (pathOrUrl.startsWith("http://") || pathOrUrl.startsWith("https://")) return pathOrUrl
    return if (pathOrUrl.startsWith("/")) "https://pillyliu.com$pathOrUrl" else "https://pillyliu.com/$pathOrUrl"
}

internal fun PinballGame.resolve(pathOrUrl: String?): String? =
    resolveLibraryUrl(pathOrUrl)

internal val PinballGame.primaryArtworkCandidates: List<String>
    get() = listOfNotNull(
        resolveLibraryUrl(primaryImageLargeUrl),
        resolveLibraryUrl(primaryImageUrl),
    ).distinct()

internal fun normalizeLibraryPlayfieldLocalPath(path: String?): String? {
    val raw = path?.trim()?.takeIf { it.isNotEmpty() } ?: return null
    val target = when {
        raw.endsWith("_700.webp", ignoreCase = true) -> raw
        raw.endsWith("_1400.webp", ignoreCase = true) -> raw.replace(Regex("_1400\\.webp$", RegexOption.IGNORE_CASE), "_700.webp")
        raw.contains("/pinball/images/playfields/") -> raw.replace(Regex("\\.[A-Za-z0-9]+$"), "_700.webp")
        else -> raw
    }
    return target
}

internal fun normalizeLibraryCachePath(path: String?): String? {
    val raw = path?.trim()?.takeIf { it.isNotEmpty() } ?: return null
    if (raw.startsWith("/")) return raw
    if (raw.startsWith("http://") || raw.startsWith("https://")) {
        return try {
            val uri = java.net.URI(raw)
            if (uri.host?.equals("pillyliu.com", ignoreCase = true) == true) {
                uri.path?.takeIf { it.isNotBlank() } ?: raw
            } else {
                raw
            }
        } catch (_: Exception) {
            raw
        }
    }
    return "/$raw"
}

private fun fallbackPlayfieldUrl(width: Int): String? =
    resolveLibraryUrl("/pinball/images/playfields/fallback-whitewood-playfield_${width}.webp")

internal val PinballGame.localAssetKey: String?
    get() = practiceIdentity?.ifBlank { null } ?: opdbGroupId?.ifBlank { null }

private val PinballGame.playfieldAssetKeys: List<String>
    get() {
        val keys = LinkedHashSet<String>()

        fun append(raw: String?) {
            val trimmed = raw?.trim()?.takeIf { it.isNotEmpty() } ?: return
            keys += trimmed
        }

        opdbId
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.split("-")
            ?.let { components ->
                for (count in components.size downTo 1) {
                    append(components.take(count).joinToString("-"))
                }
            }

        append(localAssetKey)
        append(opdbGroupId)
        return keys.toList()
    }

private val PinballGame.remotePlayfieldCandidates: List<String>
    get() = listOfNotNull(resolveLibraryUrl(playfieldImageUrl))

private val PinballGame.explicitLocalPlayfieldCandidates: List<String>
    get() = listOfNotNull(
        playfieldLocalOriginalURL,
        playfieldLocalURL,
    ).distinct()

private val PinballGame.preferredLocalPlayfieldCandidates: List<String>
    get() = (
        explicitLocalPlayfieldCandidates +
            localOriginalPlayfieldCandidates() +
            localPlayfieldCandidates(listOf(1400, 700))
        ).distinct()

private fun PinballGame.localOriginalPlayfieldCandidates(): List<String> {
    val candidates = LinkedHashSet<String>()
    playfieldAssetKeys.forEach { assetKey ->
        supportedPlayfieldOriginalExtensions.forEach { ext ->
            resolveLibraryUrl("/pinball/images/playfields/$assetKey-playfield.$ext")?.let(candidates::add)
        }
    }
    return candidates.toList()
}

private fun PinballGame.localPlayfieldCandidates(widths: List<Int>): List<String> {
    val candidates = LinkedHashSet<String>()
    playfieldAssetKeys.forEach { assetKey ->
        widths.forEach { width ->
            val path = "/pinball/images/playfields/$assetKey-playfield_${width}.webp"
            resolveLibraryUrl(path)?.let(candidates::add)
        }
    }
    return candidates.toList()
}

internal val PinballGame.playfieldLocalURL: String?
    get() = resolveLibraryUrl(playfieldLocal)

internal val PinballGame.playfieldLocalOriginalURL: String?
    get() = resolveLibraryUrl(playfieldLocalOriginal)

internal val PinballGame.alternatePlayfieldImageSourceUrl: String?
    get() = resolveLibraryUrl(alternatePlayfieldImageUrl)

internal fun PinballGame.libraryPlayfieldCandidate(): String? =
    libraryPlayfieldCandidates().firstOrNull()

internal fun PinballGame.cardArtworkCandidates(): List<String> =
    primaryArtworkCandidates

internal fun PinballGame.libraryPlayfieldCandidates(): List<String> =
    (preferredLocalPlayfieldCandidates + remotePlayfieldCandidates + listOfNotNull(
        fallbackPlayfieldUrl(700),
    )).distinct()

internal fun PinballGame.miniCardPlayfieldCandidates(): List<String> =
    (preferredLocalPlayfieldCandidates + remotePlayfieldCandidates + listOfNotNull(
        fallbackPlayfieldUrl(700),
        fallbackPlayfieldUrl(1400),
    )).distinct()

internal fun PinballGame.miniCardPlayfieldCandidate(): String? =
    miniCardPlayfieldCandidates().firstOrNull()

internal fun PinballGame.gameInlinePlayfieldCandidates(): List<String> =
    (actualFullscreenPlayfieldCandidates + listOfNotNull(fallbackPlayfieldUrl(700))).distinct()

internal fun PinballGame.detailArtworkCandidates(): List<String> =
    primaryArtworkCandidates

internal fun PinballGame.fullscreenPlayfieldCandidates(): List<String> =
    (actualFullscreenPlayfieldCandidates + listOfNotNull(fallbackPlayfieldUrl(700))).distinct()

internal val PinballGame.actualFullscreenPlayfieldCandidates: List<String>
    get() = (explicitLocalPlayfieldCandidates + remotePlayfieldCandidates).distinct()

internal val PinballGame.hasPlayfieldResource: Boolean
    get() = actualFullscreenPlayfieldCandidates.isNotEmpty()

internal fun PinballGame.resolvedPlayfieldCandidates(liveStatus: LivePlayfieldStatus?): List<String> =
    when (liveStatus?.effectiveKind) {
        LivePlayfieldKind.MISSING -> if (actualFullscreenPlayfieldCandidates.isEmpty()) emptyList() else actualFullscreenPlayfieldCandidates
        else -> (listOfNotNull(liveStatus?.effectiveUrl) + actualFullscreenPlayfieldCandidates).distinct()
    }

internal fun PinballGame.resolvedPlayfieldButtonLabel(liveStatus: LivePlayfieldStatus?): String =
    when (liveStatus?.effectiveKind) {
        LivePlayfieldKind.PILLYLIU -> "Local"
        LivePlayfieldKind.OPDB -> "OPDB"
        LivePlayfieldKind.EXTERNAL -> "Remote"
        LivePlayfieldKind.MISSING -> if (actualFullscreenPlayfieldCandidates.isEmpty()) "Unavailable" else playfieldButtonLabel
        null -> playfieldButtonLabel
    }

internal fun PinballGame.resolvedPlayfieldOptions(liveStatus: LivePlayfieldStatus?): List<PlayfieldOption> {
    val options = mutableListOf<PlayfieldOption>()
    val usedCandidates = mutableSetOf<String>()
    val explicitCandidates = actualFullscreenPlayfieldCandidates
    if (liveStatus?.effectiveKind == LivePlayfieldKind.MISSING && explicitCandidates.isEmpty()) {
        return emptyList()
    }

    if (explicitCandidates.isNotEmpty()) {
        options += PlayfieldOption(
            label = playfieldButtonLabel,
            candidates = explicitCandidates,
        )
        usedCandidates += explicitCandidates
    } else {
        val primaryCandidates = resolvedPlayfieldCandidates(liveStatus)
        if (primaryCandidates.isNotEmpty()) {
            options += PlayfieldOption(
                label = resolvedPlayfieldButtonLabel(liveStatus),
                candidates = primaryCandidates,
            )
            usedCandidates += primaryCandidates
        }
    }

    val liveUrl = liveStatus?.effectiveUrl
    if (liveUrl != null && liveStatus.effectiveKind != LivePlayfieldKind.MISSING && liveUrl !in usedCandidates) {
        options += PlayfieldOption(
            label = resolvedPlayfieldButtonLabel(liveStatus),
            candidates = listOf(liveUrl),
        )
        usedCandidates += liveUrl
    }

    val alternate = alternatePlayfieldImageSourceUrl
    if (alternate != null && alternate !in usedCandidates) {
        options += PlayfieldOption(
            label = "OPDB",
            candidates = listOf(alternate),
        )
        usedCandidates += alternate
    }
    return options
}

internal val PinballGame.playfieldButtonLabel: String
    get() {
        val explicitLabel = playfieldSourceLabel?.trim()?.takeIf { it.isNotEmpty() }
        if (explicitLabel != null) {
            return if (explicitLabel == "Playfield (OPDB)") "OPDB" else "Local"
        }
        if (playfieldLocalURL != null || playfieldLocalOriginalURL != null) {
            return "Local"
        }
        val resolved = resolveLibraryUrl(playfieldImageUrl)
        if (resolved != null) {
            return when {
                isCuratedPlayfieldUrl(resolved) -> "Local"
                isOpdbPlayfieldUrl(resolved) -> "OPDB"
                else -> "Remote"
            }
        }
        return "View"
    }

private fun isCuratedPlayfieldUrl(url: String?): Boolean {
    val resolved = url ?: return false
    return runCatching {
        val parsed = URL(resolved)
        parsed.host.equals("pillyliu.com", ignoreCase = true) && parsed.path.startsWith("/pinball/images/playfields/")
    }.getOrDefault(false)
}

private fun isOpdbPlayfieldUrl(url: String?): Boolean {
    val resolved = url ?: return false
    return runCatching {
        val parsed = URL(resolved)
        parsed.host?.contains("opdb.org", ignoreCase = true) == true
    }.getOrDefault(false)
}

internal val PinballGame.rulesheetPathCandidates: List<String>
    get() = listOfNotNull(
        localAssetKey?.let { "/pinball/rulesheets/${it}-rulesheet.md" },
    ).distinct()

internal val PinballGame.gameinfoPathCandidates: List<String>
    get() = listOfNotNull(
        localAssetKey?.let { "/pinball/gameinfo/${it}-gameinfo.md" },
    ).distinct()

internal val PinballGame.hasRulesheetResource: Boolean
    get() = rulesheetPathCandidates.isNotEmpty() || rulesheetLinks.isNotEmpty() || !rulesheetUrl.isNullOrBlank()
