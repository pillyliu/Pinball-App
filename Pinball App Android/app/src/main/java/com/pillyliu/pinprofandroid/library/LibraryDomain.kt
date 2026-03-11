package com.pillyliu.pinprofandroid.library

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.net.toUri
import androidx.compose.ui.unit.dp
import org.json.JSONObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap

internal const val LIBRARY_URL = "https://pillyliu.com/pinball/data/pinball_library_v3.json"
internal const val OPDB_CATALOG_URL = "https://pillyliu.com/pinball/data/opdb_catalog_v1.json"
internal val LIBRARY_CONTENT_BOTTOM_FILLER = 60.dp

internal enum class LibrarySourceType(val rawValue: String) {
    VENUE("venue"),
    CATEGORY("category"),
    MANUFACTURER("manufacturer"),
    TOURNAMENT("tournament");

    companion object {
        fun fromRaw(raw: String?): LibrarySourceType? {
            return when (raw?.trim()?.lowercase()) {
                "venue" -> VENUE
                "category" -> CATEGORY
                "manufacturer" -> MANUFACTURER
                "tournament" -> TOURNAMENT
                else -> null
            }
        }
    }
}

internal data class LibrarySource(
    val id: String,
    val name: String,
    val type: LibrarySourceType,
) {
    val defaultSortOption: LibrarySortOption
        get() = when (type) {
            LibrarySourceType.VENUE -> LibrarySortOption.AREA
            LibrarySourceType.CATEGORY -> LibrarySortOption.ALPHABETICAL
            LibrarySourceType.MANUFACTURER -> LibrarySortOption.YEAR
            LibrarySourceType.TOURNAMENT -> LibrarySortOption.ALPHABETICAL
        }
}

internal data class ParsedLibraryData(
    val games: List<PinballGame>,
    val sources: List<LibrarySource>,
)

internal data class LibraryVenueSearchResult(
    val id: String,
    val name: String,
    val city: String?,
    val state: String?,
    val zip: String?,
    val distanceMiles: Double?,
    val machineCount: Int,
)

internal data class ReferenceLink(
    val label: String,
    val url: String? = null,
) {
    val embeddedRulesheetSource: RulesheetRemoteSource?
        get() {
            val destination = resolveLibraryUrl(destinationUrl) ?: return null
            val normalized = destination.lowercase()
            if (normalized.contains("pinballnews.com")) return null
            return when {
                normalized.contains("tiltforums.com") -> RulesheetRemoteSource.TiltForums(destination)
                normalized.contains("rules.silverballmania.com") ||
                    normalized.contains("silverballmania.com") ||
                    normalized.contains("flippers.be") ||
                    label.lowercase().contains("(bob)") -> RulesheetRemoteSource.BobsGuide(destination)
                normalized.contains("pinballprimer.github.io") ||
                    normalized.contains("pinballprimer.com") ||
                    label.lowercase().contains("(pp)") -> RulesheetRemoteSource.PinballPrimer(destination)
                normalized.contains("replayfoundation.org") ||
                    normalized.contains("pinball.org") ||
                    label.lowercase().contains("(papa)") -> RulesheetRemoteSource.Papa(destination)
                else -> null
            }
        }

    val destinationUrl: String?
        get() = url?.trim()?.ifBlank { null }
}

internal enum class RulesheetSourceKind(val rank: Int, val shortLabel: String) {
    LOCAL(0, "Local"),
    PROF(1, "Prof"),
    BOB(2, "Bob"),
    PAPA(3, "PAPA"),
    PP(4, "PP"),
    TF(5, "TF"),
    OPDB(6, "OPDB"),
    OTHER(7, "Local"),
}

internal val ReferenceLink.rulesheetSourceKind: RulesheetSourceKind
    get() {
        val normalizedLabel = label.lowercase()
        val resolved = resolveLibraryUrl(destinationUrl)
        return when {
            isPinProfRulesheetUrl(resolved) || "(prof)" in normalizedLabel -> RulesheetSourceKind.PROF
            resolved?.contains("tiltforums.com", ignoreCase = true) == true || "(tf)" in normalizedLabel -> RulesheetSourceKind.TF
            resolved?.contains("pinballprimer.github.io", ignoreCase = true) == true ||
                resolved?.contains("pinballprimer.com", ignoreCase = true) == true ||
                "(pp)" in normalizedLabel -> RulesheetSourceKind.PP
            resolved?.contains("replayfoundation.org", ignoreCase = true) == true ||
                resolved?.contains("pinball.org", ignoreCase = true) == true ||
                "(papa)" in normalizedLabel -> RulesheetSourceKind.PAPA
            resolved?.contains("silverballmania.com", ignoreCase = true) == true ||
                resolved?.contains("flippers.be", ignoreCase = true) == true ||
                "(bob)" in normalizedLabel -> RulesheetSourceKind.BOB
            "(opdb)" in normalizedLabel -> RulesheetSourceKind.OPDB
            "(local)" in normalizedLabel || "(source)" in normalizedLabel -> RulesheetSourceKind.LOCAL
            resolved == null && embeddedRulesheetSource == null -> RulesheetSourceKind.LOCAL
            else -> RulesheetSourceKind.OTHER
        }
    }

internal val ReferenceLink.shortRulesheetTitle: String
    get() = rulesheetSourceKind.shortLabel

internal data class Video(val kind: String?, val label: String?, val url: String?)
internal data class PlayableVideo(val id: String, val label: String) {
    val watchUrl: String
        get() = "https://www.youtube.com/watch?v=$id"

    val thumbnailUrl: String
        get() = "https://i.ytimg.com/vi/$id/hqdefault.jpg"
}

internal data class YouTubeVideoMetadata(val title: String, val channelName: String?)
internal data class LibraryGroupSection(val groupKey: Int?, val games: List<PinballGame>)
internal enum class LibraryRouteKind {
    LIST,
    DETAIL,
    RULESHEET,
    EXTERNAL_RULESHEET,
    PLAYFIELD,
}

internal enum class LibrarySortOption(val label: String) {
    AREA("Sort: Area"),
    BANK("Sort: Bank"),
    ALPHABETICAL("Sort: A-Z"),
    YEAR("Sort: Year"),
}

internal data class PinballGame(
    val libraryEntryId: String?,
    val practiceIdentity: String?,
    val opdbId: String? = null,
    val opdbGroupId: String? = null,
    val variant: String?,
    val sourceId: String,
    val sourceName: String,
    val sourceType: LibrarySourceType,
    val area: String?,
    val areaOrder: Int?,
    val group: Int?,
    val position: Int?,
    val bank: Int?,
    val name: String,
    val manufacturer: String?,
    val year: Int?,
    val slug: String,
    val primaryImageUrl: String? = null,
    val primaryImageLargeUrl: String? = null,
    val playfieldImageUrl: String?,
    val alternatePlayfieldImageUrl: String? = null,
    val playfieldLocalOriginal: String?,
    val playfieldLocal: String?,
    val playfieldSourceLabel: String? = null,
    val gameinfoLocal: String?,
    val rulesheetLocal: String?,
    val rulesheetUrl: String?,
    val rulesheetLinks: List<ReferenceLink> = emptyList(),
    val videos: List<Video>,
)

internal val PinballGame.orderedRulesheetLinks: List<ReferenceLink>
    get() = rulesheetLinks.sortedWith(
        compareBy<ReferenceLink> { it.rulesheetSourceKind.rank }
            .thenBy { it.label.lowercase() }
            .thenBy { resolveLibraryUrl(it.destinationUrl).orEmpty().lowercase() },
    )

internal fun buildSections(
    filtered: List<PinballGame>,
    keySelector: (PinballGame) -> Int?,
): List<LibraryGroupSection> {
    val out = mutableListOf<LibraryGroupSection>()
    filtered.forEach { game ->
        val key = keySelector(game)
        if (out.isNotEmpty() && out.last().groupKey == key) {
            val merged = out.last().games + game
            out[out.lastIndex] = LibraryGroupSection(groupKey = key, games = merged)
        } else {
            out += LibraryGroupSection(groupKey = key, games = listOf(game))
        }
    }
    return out
}

internal fun sortLibraryGames(
    games: List<PinballGame>,
    option: LibrarySortOption,
    yearSortDescending: Boolean = false,
): List<PinballGame> {
    return when (option) {
        LibrarySortOption.AREA -> games.sortedWith(
            compareBy<PinballGame> { it.areaOrder ?: Int.MAX_VALUE }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.position ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )
        LibrarySortOption.BANK -> games.sortedWith(
            compareBy<PinballGame> { it.bank ?: Int.MAX_VALUE }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.position ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )
        LibrarySortOption.ALPHABETICAL -> games.sortedWith(
            compareBy<PinballGame> { it.name.lowercase() }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.position ?: Int.MAX_VALUE },
        )
        LibrarySortOption.YEAR -> {
            if (yearSortDescending) {
                games.sortedWith(
                    compareByDescending<PinballGame> { it.year ?: Int.MIN_VALUE }
                        .thenBy { it.name.lowercase() },
                )
            } else {
                games.sortedWith(
                    compareBy<PinballGame> { it.year ?: Int.MAX_VALUE }
                        .thenBy { it.name.lowercase() },
                )
            }
        }
    }
}

internal fun sortOptionsForSource(source: LibrarySource, games: List<PinballGame>): List<LibrarySortOption> {
    return when (source.type) {
        LibrarySourceType.CATEGORY,
        LibrarySourceType.MANUFACTURER,
        LibrarySourceType.TOURNAMENT -> listOf(
            LibrarySortOption.YEAR,
            LibrarySortOption.ALPHABETICAL,
        )
        LibrarySourceType.VENUE -> {
            val hasBank = games.any { (it.bank ?: 0) > 0 }
            buildList {
                add(LibrarySortOption.AREA)
                if (hasBank) add(LibrarySortOption.BANK)
                add(LibrarySortOption.ALPHABETICAL)
                add(LibrarySortOption.YEAR)
            }
        }
    }
}

internal fun PinballGame.metaLine(): String {
    val parts = mutableListOf<String>()
    parts += manufacturer ?: "-"
    year?.let { parts += "$it" }
    locationText()?.let { parts += it }
    bank?.takeIf { it > 0 }?.let { parts += "Bank $it" }
    return parts.joinToString(" • ")
}

internal fun PinballGame.manufacturerYearLine(): String {
    return if (year != null) "${manufacturer ?: "-"} • $year" else (manufacturer ?: "-")
}

internal val PinballGame.normalizedVariant: String?
    get() = variant?.trim()?.takeIf { it.isNotBlank() && !it.equals("null", ignoreCase = true) }

internal fun PinballGame.locationBankLine(): String {
    val parts = mutableListOf<String>()
    locationText()?.let { parts += it }
    bank?.takeIf { it > 0 }?.let { parts += "Bank $it" }
    return if (parts.isEmpty()) "" else parts.joinToString(" • ")
}

private fun PinballGame.locationText(): String? {
    val g = group ?: return null
    val p = position ?: return null
    val normalizedArea = area
        ?.trim()
        ?.takeUnless { it.isBlank() || it.equals("null", ignoreCase = true) }
    return if (normalizedArea != null) {
        "📍 $normalizedArea:$g:$p"
    } else {
        "📍 $g:$p"
    }
}

internal val PinballGame.practiceKey: String
    get() = canonicalPracticeKey

internal val PinballGame.canonicalPracticeKey: String
    get() = practiceIdentity?.ifBlank { null } ?: opdbGroupId?.ifBlank { null } ?: slug

sealed interface RulesheetRemoteSource {
    val url: String
    val sourceName: String
    val originalLinkLabel: String
    val detailsText: String

    data class TiltForums(override val url: String) : RulesheetRemoteSource {
        override val sourceName: String = "Tilt Forums community rulesheet"
        override val originalLinkLabel: String = "Original thread"
        override val detailsText: String = "License/source terms remain with Tilt Forums and the original authors."
    }

    data class BobsGuide(override val url: String) : RulesheetRemoteSource {
        override val sourceName: String = "Silverball Rules (Bob Matthews source)"
        override val originalLinkLabel: String = "Original page"
        override val detailsText: String = "Preserve source attribution and any author/site rights notes from the original page."
    }

    data class PinballPrimer(override val url: String) : RulesheetRemoteSource {
        override val sourceName: String = "Pinball Primer"
        override val originalLinkLabel: String = "Original page"
        override val detailsText: String = "Preserve source attribution and any author/site rights notes from the original page."
    }

    data class Papa(override val url: String) : RulesheetRemoteSource {
        override val sourceName: String = "PAPA / pinball.org rulesheet archive"
        override val originalLinkLabel: String = "Original page"
        override val detailsText: String = "Preserve source attribution and any author/site rights notes from the original page."
    }
}

internal fun openYoutubeInApp(context: android.content.Context, url: String, fallbackVideoId: String): Boolean {
    return try {
        if (url.startsWith("intent:")) {
            val intent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } else {
            val id = youtubeId(url) ?: fallbackVideoId
            val appIntent = Intent(Intent.ACTION_VIEW, "vnd.youtube:$id".toUri()).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                context.startActivity(appIntent)
            } catch (_: ActivityNotFoundException) {
                val webIntent = Intent(Intent.ACTION_VIEW, "https://www.youtube.com/watch?v=$id".toUri()).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(webIntent)
            }
            true
        }
    } catch (_: Throwable) {
        false
    }
}

internal fun youtubeId(raw: String?): String? {
    raw ?: return null
    return try {
        val uri = java.net.URI(raw)
        val host = uri.host?.lowercase() ?: return null
        when {
            host.contains("youtu.be") -> uri.path.removePrefix("/").takeIf { it.isNotBlank() }
            host.contains("youtube.com") -> {
                val queryID = uri.query
                    ?.split("&")
                    ?.mapNotNull {
                        val pair = it.split("=", limit = 2)
                        if (pair.size == 2 && pair[0] == "v") pair[1] else null
                    }
                    ?.firstOrNull()
                queryID
                    ?: uri.path.removePrefix("/shorts/").takeIf { uri.path.startsWith("/shorts/") && it.isNotBlank() }
                    ?: uri.path.removePrefix("/embed/").takeIf { uri.path.startsWith("/embed/") && it.isNotBlank() }
            }
            else -> null
        }
    } catch (_: Throwable) {
        null
    }
}

private val youTubeMetadataCache = ConcurrentHashMap<String, YouTubeVideoMetadata>()

internal suspend fun loadYouTubeVideoMetadata(videoId: String): YouTubeVideoMetadata? {
    youTubeMetadataCache[videoId]?.let { return it }

    return withContext(Dispatchers.IO) {
        try {
            val watchUrl = "https://www.youtube.com/watch?v=$videoId"
            val encodedWatchUrl = URLEncoder.encode(watchUrl, StandardCharsets.UTF_8.toString())
            val requestUrl = URL("https://www.youtube.com/oembed?url=$encodedWatchUrl&format=json")
            val connection = requestUrl.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 5_000
            connection.readTimeout = 5_000
            connection.setRequestProperty("Accept", "application/json")
            try {
                if (connection.responseCode !in 200..299) {
                    return@withContext null
                }
                val body = connection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(body)
                val title = json.optString("title").trim()
                if (title.isBlank()) {
                    return@withContext null
                }
                val channelName = json.optString("author_name").trim().ifBlank { null }
                YouTubeVideoMetadata(title = title, channelName = channelName).also {
                    youTubeMetadataCache[videoId] = it
                }
            } finally {
                connection.disconnect()
            }
        } catch (_: Throwable) {
            null
        }
    }
}
