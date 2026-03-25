package com.pillyliu.pinprofandroid.library

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.net.URL

internal const val libraryMissingArtworkPath = "/pinball/images/playfields/fallback-image-not-available_2048.webp"
private val supportedPlayfieldOriginalExtensions = listOf("webp", "jpg", "jpeg", "png")
private val pinProfHosts = setOf(
    "pillyliu.com",
    "www.pillyliu.com",
    "pinprof.com",
    "www.pinprof.com",
)
private val bundledOnlyAppGroupIds = setOf("G900001")

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

private fun normalizedRulesheetMarkdownPath(pathOrUrl: String?): String? {
    val resolved = resolveLibraryUrl(pathOrUrl) ?: return null
    return runCatching { URL(resolved).path.lowercase() }
        .getOrNull()
        ?.takeIf { it.isNotBlank() }
}

internal fun isLikelyPinProfMarkdownRulesheetUrl(url: String?): Boolean {
    val raw = url?.trim()?.takeIf { it.isNotEmpty() } ?: return false
    val normalizedRaw = raw.lowercase()
    if (
        normalizedRaw.endsWith("-rulesheet.md") ||
        normalizedRaw.contains("/pinball/rulesheets/") ||
        normalizedRaw.contains("/rules/") && normalizedRaw.contains("source=local")
    ) {
        return true
    }
    val resolvedPath = normalizedRulesheetMarkdownPath(raw) ?: return false
    return resolvedPath.startsWith("/pinball/rulesheets/") ||
        resolvedPath.endsWith("-rulesheet.md") ||
        (resolvedPath.startsWith("/rules/") && normalizedRaw.contains("source=local"))
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

internal val PinballGame.primaryArtworkCandidates: List<String>
    get() = listOfNotNull(
        resolveLibraryUrl(primaryImageLargeUrl),
        resolveLibraryUrl(primaryImageUrl),
    ).distinct()

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

private fun missingArtworkUrl(): String? =
    resolveLibraryUrl(libraryMissingArtworkPath)

internal val PinballGame.usesBundledOnlyAppAssetException: Boolean
    get() = listOfNotNull(practiceIdentity, opdbGroupId)
        .map { raw ->
            val trimmed = raw.trim()
            val dash = trimmed.indexOf('-')
            if (dash >= 0) trimmed.substring(0, dash) else trimmed
        }
        .any(bundledOnlyAppGroupIds::contains)

internal val PinballGame.localRulesheetChipLabel: String
    get() = if (usesBundledOnlyAppAssetException) "Local" else "PinProf"

internal val PinballGame.localPlayfieldChipLabel: String
    get() = if (usesBundledOnlyAppAssetException) "Local" else "PinProf"

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

private val PinballGame.supportedSourcePlayfieldCandidates: List<String>
    get() = listOfNotNull(
        resolveLibraryUrl(playfieldImageUrl)?.takeIf {
            isPinProfPlayfieldUrl(it) || isOpdbPlayfieldUrl(it)
        },
        alternatePlayfieldImageSourceUrl?.takeIf {
            isPinProfPlayfieldUrl(it) || isOpdbPlayfieldUrl(it)
        },
    ).distinct()

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
    artworkCandidatesOrMissingArtwork()

internal fun PinballGame.libraryPlayfieldCandidates(): List<String> =
    realPlayfieldCandidatesOrMissingArtwork()

internal fun PinballGame.miniCardPlayfieldCandidates(): List<String> =
    realPlayfieldCandidatesOrMissingArtwork()

internal fun PinballGame.miniCardPlayfieldCandidate(): String? =
    miniCardPlayfieldCandidates().firstOrNull()

internal fun PinballGame.gameInlinePlayfieldCandidates(): List<String> =
    fullscreenArtworkCandidatesOrMissingArtwork()

internal fun PinballGame.detailArtworkCandidates(): List<String> =
    artworkCandidatesOrMissingArtwork()

internal fun PinballGame.fullscreenPlayfieldCandidates(): List<String> =
    fullscreenArtworkCandidatesOrMissingArtwork()

internal val PinballGame.actualFullscreenPlayfieldCandidates: List<String>
    get() = (explicitLocalPlayfieldCandidates + supportedSourcePlayfieldCandidates).distinct()

private val PinballGame.localFallbackPlayfieldCandidates: List<String>
    get() = listOfNotNull(playfieldLocalURL).distinct()

private val PinballGame.profPlayfieldBaseCandidates: List<String>
    get() = listOfNotNull(
        playfieldLocalOriginalURL?.takeIf(::isPinProfPlayfieldUrl),
        resolveLibraryUrl(playfieldImageUrl)?.takeIf(::isPinProfPlayfieldUrl),
    ).distinct().let { candidates ->
        if (usesBundledOnlyAppAssetException) emptyList() else candidates
    }

private fun PinballGame.profPlayfieldCandidates(liveStatus: LivePlayfieldStatus?): List<String> {
    val liveUrl = liveStatus?.effectiveUrl?.takeIf { liveStatus.effectiveKind == LivePlayfieldKind.PILLYLIU }
    val hasHostedCandidate = liveUrl != null || profPlayfieldBaseCandidates.isNotEmpty()
    return buildList {
        liveUrl?.let(::add)
        addAll(profPlayfieldBaseCandidates)
        if (hasHostedCandidate) {
            addAll(localFallbackPlayfieldCandidates)
        }
    }.distinct()
}

private fun PinballGame.opdbPlayfieldCandidates(liveStatus: LivePlayfieldStatus?): List<String> =
    listOfNotNull(
        liveStatus?.effectiveUrl?.takeIf { liveStatus.effectiveKind == LivePlayfieldKind.OPDB },
        resolveLibraryUrl(playfieldImageUrl)?.takeIf(::isOpdbPlayfieldUrl),
        alternatePlayfieldImageSourceUrl?.takeIf(::isOpdbPlayfieldUrl),
    ).distinct()

private fun PinballGame.artworkCandidatesOrMissingArtwork(): List<String> {
    val candidates = primaryArtworkCandidates
    if (candidates.isNotEmpty()) {
        return candidates
    }
    return listOfNotNull(missingArtworkUrl()).distinct()
}

private fun PinballGame.realPlayfieldCandidates(): List<String> =
    (preferredLocalPlayfieldCandidates + supportedSourcePlayfieldCandidates).distinct()

private fun PinballGame.realPlayfieldCandidatesOrMissingArtwork(): List<String> {
    val candidates = realPlayfieldCandidates()
    if (candidates.isNotEmpty()) {
        return candidates
    }
    return listOfNotNull(missingArtworkUrl()).distinct()
}

private fun PinballGame.fullscreenArtworkCandidatesOrMissingArtwork(): List<String> {
    if (actualFullscreenPlayfieldCandidates.isNotEmpty()) {
        return actualFullscreenPlayfieldCandidates
    }
    val candidates = realPlayfieldCandidates()
    if (candidates.isNotEmpty()) {
        return candidates
    }
    return listOfNotNull(missingArtworkUrl()).distinct()
}

internal val PinballGame.hasPlayfieldResource: Boolean
    get() = actualFullscreenPlayfieldCandidates.isNotEmpty()

internal fun PinballGame.resolvedPlayfieldCandidates(liveStatus: LivePlayfieldStatus?): List<String> =
    when {
        profPlayfieldCandidates(liveStatus).isNotEmpty() -> profPlayfieldCandidates(liveStatus)
        localFallbackPlayfieldCandidates.isNotEmpty() -> localFallbackPlayfieldCandidates
        opdbPlayfieldCandidates(liveStatus).isNotEmpty() -> opdbPlayfieldCandidates(liveStatus)
        else -> emptyList()
    }

internal fun PinballGame.resolvedPlayfieldButtonLabel(liveStatus: LivePlayfieldStatus?): String =
    when (liveStatus?.effectiveKind) {
        LivePlayfieldKind.PILLYLIU -> "PinProf"
        LivePlayfieldKind.OPDB -> "OPDB"
        LivePlayfieldKind.EXTERNAL -> playfieldButtonLabel
        LivePlayfieldKind.MISSING -> if (actualFullscreenPlayfieldCandidates.isEmpty()) "Unavailable" else playfieldButtonLabel
        null -> playfieldButtonLabel
    }

internal fun PinballGame.resolvedPlayfieldOptions(liveStatus: LivePlayfieldStatus?): List<PlayfieldOption> {
    val options = mutableListOf<PlayfieldOption>()
    val usedCandidates = mutableSetOf<String>()
    if (liveStatus?.effectiveKind == LivePlayfieldKind.MISSING &&
        actualFullscreenPlayfieldCandidates.isEmpty() &&
        resolvedPlayfieldCandidates(liveStatus).isEmpty()
    ) {
        return emptyList()
    }

    fun appendOption(label: String, candidates: List<String>) {
        val filtered = candidates.filter { candidate -> usedCandidates.add(candidate) }
        if (filtered.isEmpty()) return
        options += PlayfieldOption(label = label, candidates = filtered)
    }

    val profCandidates = profPlayfieldCandidates(liveStatus)
    if (profCandidates.isNotEmpty()) {
        appendOption(label = "PinProf", candidates = profCandidates)
    } else {
        appendOption(label = localPlayfieldChipLabel, candidates = localFallbackPlayfieldCandidates)
    }

    appendOption(label = "OPDB", candidates = opdbPlayfieldCandidates(liveStatus))
    return options
}

internal val PinballGame.playfieldButtonLabel: String
    get() {
        val explicitLabel = playfieldSourceLabel?.trim()?.takeIf { it.isNotEmpty() }
        if (explicitLabel != null) {
            val normalized = explicitLabel.lowercase()
            return when {
                "opdb" in normalized -> "OPDB"
                "prof" in normalized -> "PinProf"
                "local" in normalized -> localPlayfieldChipLabel
                "remote" in normalized || "external" in normalized -> "View"
                else -> explicitLabel
            }
        }
        if (profPlayfieldBaseCandidates.isNotEmpty()) {
            return "PinProf"
        }
        if (localFallbackPlayfieldCandidates.isNotEmpty()) {
            return localPlayfieldChipLabel
        }
        val resolved = resolveLibraryUrl(playfieldImageUrl)
        if (resolved != null) {
            return when {
                isPinProfPlayfieldUrl(resolved) -> "PinProf"
                isOpdbPlayfieldUrl(resolved) -> "OPDB"
                else -> "View"
            }
        }
        if (alternatePlayfieldImageSourceUrl?.let(::isOpdbPlayfieldUrl) == true) {
            return "OPDB"
        }
        return "View"
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
        normalizeLibraryCachePath(rulesheetLocal),
    ).distinct()

internal val PinballGame.hasLocalRulesheetResource: Boolean
    get() = rulesheetPathCandidates.isNotEmpty()

internal val PinballGame.displayedRulesheetLinks: List<ReferenceLink>
    get() {
        val localRulesheetBasenames = rulesheetPathCandidates.mapNotNull { candidate ->
            normalizedRulesheetMarkdownPath(candidate)
                ?.substringAfterLast('/')
                ?.takeIf { it.isNotBlank() }
        }.toSet()

        return orderedRulesheetLinks
            .filterNot { link ->
                val destination = resolveLibraryUrl(link.destinationUrl)
                val destinationBasename = normalizedRulesheetMarkdownPath(destination)
                    ?.substringAfterLast('/')
                    ?.takeIf { it.isNotBlank() }
                hasLocalRulesheetResource && (
                    link.rulesheetSourceKind == RulesheetSourceKind.PROF ||
                        link.rulesheetSourceKind == RulesheetSourceKind.LOCAL ||
                        isPinProfRulesheetUrl(destination) ||
                        isLikelyPinProfMarkdownRulesheetUrl(destination) ||
                        (destinationBasename != null && destinationBasename in localRulesheetBasenames)
                    )
            }
        .filter { link ->
            link.destinationUrl != null || link.embeddedRulesheetSource != null
        }
    }

internal val PinballGame.gameinfoPathCandidates: List<String>
    get() = listOfNotNull(
        localAssetKey?.let { "/pinball/gameinfo/${it}-gameinfo.md" },
    ).distinct()

internal val PinballGame.hasRulesheetResource: Boolean
    get() = hasLocalRulesheetResource || rulesheetLinks.isNotEmpty() || !rulesheetUrl.isNullOrBlank()
