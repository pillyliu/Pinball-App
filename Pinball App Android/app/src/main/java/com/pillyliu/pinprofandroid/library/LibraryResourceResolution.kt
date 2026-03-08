package com.pillyliu.pinprofandroid.library

import com.pillyliu.pinprofandroid.data.PinballDataCache
import org.json.JSONObject
import java.net.URL

private const val FALLBACK_WHITEWOOD_PLAYFIELD_700 = "/pinball/images/playfields/fallback-whitewood-playfield_700.webp"
private const val FALLBACK_WHITEWOOD_PLAYFIELD_1400 = "/pinball/images/playfields/fallback-whitewood-playfield_1400.webp"

private val bundledPlayfieldPaths: Set<String> by lazy {
    val manifestText = PinballDataCache.loadBundledStarterText("/pinball/cache-manifest.json") ?: return@lazy emptySet()
    val files = JSONObject(manifestText).optJSONObject("files") ?: return@lazy emptySet()
    buildSet {
        val keys = files.keys()
        while (keys.hasNext()) {
            val path = keys.next()
            if (path.startsWith("/pinball/images/playfields/") && path.endsWith(".webp", ignoreCase = true)) {
                add(path)
            }
        }
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

private fun PinballGame.localPlayfieldCandidates(widths: List<Int>): List<String> {
    val candidates = LinkedHashSet<String>()
    playfieldAssetKeys.forEach { assetKey ->
        widths.forEach { width ->
            val path = "/pinball/images/playfields/$assetKey-playfield_${width}.webp"
            if (path in bundledPlayfieldPaths) {
                resolveLibraryUrl(path)?.let(candidates::add)
            }
        }
    }
    return candidates.toList()
}

internal val PinballGame.playfieldLocalURL: String?
    get() = resolveLibraryUrl(playfieldLocal)

internal val PinballGame.playfieldLocalOriginalURL: String?
    get() = resolveLibraryUrl(playfieldLocalOriginal)

internal fun PinballGame.libraryPlayfieldCandidate(): String? =
    libraryPlayfieldCandidates().firstOrNull()

internal fun PinballGame.cardArtworkCandidates(): List<String> =
    (primaryArtworkCandidates + miniCardPlayfieldCandidates()).distinct()

internal fun PinballGame.libraryPlayfieldCandidates(): List<String> =
    (localPlayfieldCandidates(listOf(700)) + remotePlayfieldCandidates + listOfNotNull(
        fallbackPlayfieldUrl(700),
    )).distinct()

internal fun PinballGame.miniCardPlayfieldCandidates(): List<String> =
    (localPlayfieldCandidates(listOf(700, 1400)) + remotePlayfieldCandidates + listOfNotNull(
        fallbackPlayfieldUrl(700),
        fallbackPlayfieldUrl(1400),
    )).distinct()

internal fun PinballGame.miniCardPlayfieldCandidate(): String? =
    miniCardPlayfieldCandidates().firstOrNull()

internal fun PinballGame.gameInlinePlayfieldCandidates(): List<String> =
    (actualFullscreenPlayfieldCandidates + listOfNotNull(fallbackPlayfieldUrl(700))).distinct()

internal fun PinballGame.detailArtworkCandidates(): List<String> =
    (primaryArtworkCandidates + gameInlinePlayfieldCandidates()).distinct()

internal fun PinballGame.fullscreenPlayfieldCandidates(): List<String> =
    (actualFullscreenPlayfieldCandidates + listOfNotNull(fallbackPlayfieldUrl(700))).distinct()

internal val PinballGame.actualFullscreenPlayfieldCandidates: List<String>
    get() = (localPlayfieldCandidates(listOf(1400, 700)) + remotePlayfieldCandidates).distinct()

internal val PinballGame.hasPlayfieldResource: Boolean
    get() = actualFullscreenPlayfieldCandidates.isNotEmpty()

internal val PinballGame.playfieldButtonLabel: String
    get() {
        val explicitLabel = playfieldSourceLabel?.trim()?.takeIf { it.isNotEmpty() }
        if (explicitLabel != null) {
            return if (explicitLabel == "Playfield (OPDB)") "OPDB" else "Local"
        }
        if (playfieldLocalURL != null || playfieldLocalOriginalURL != null || isCuratedPlayfieldUrl(resolveLibraryUrl(playfieldImageUrl))) {
            return "Local"
        }
        return if (playfieldImageUrl.isNullOrBlank()) "View" else "OPDB"
    }

private fun isCuratedPlayfieldUrl(url: String?): Boolean {
    val resolved = url ?: return false
    return runCatching {
        val parsed = URL(resolved)
        parsed.host.equals("pillyliu.com", ignoreCase = true) && parsed.path.startsWith("/pinball/images/playfields/")
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
