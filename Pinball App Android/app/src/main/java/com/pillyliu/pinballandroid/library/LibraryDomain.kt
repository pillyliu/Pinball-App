package com.pillyliu.pinballandroid.library

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.net.toUri
import androidx.compose.ui.unit.dp
import org.json.JSONArray
import org.json.JSONObject

internal const val LIBRARY_URL = "https://pillyliu.com/pinball/data/pinball_library_v3.json"
internal const val OPDB_CATALOG_URL = "https://pillyliu.com/pinball/data/opdb_catalog_v1.json"
internal val LIBRARY_CONTENT_BOTTOM_FILLER = 60.dp
private const val FALLBACK_WHITEWOOD_PLAYFIELD_700 = "/pinball/images/playfields/fallback-whitewood-playfield_700.webp"
private const val FALLBACK_WHITEWOOD_PLAYFIELD_1400 = "/pinball/images/playfields/fallback-whitewood-playfield_1400.webp"

internal enum class LibrarySourceType(val rawValue: String) {
    VENUE("venue"),
    CATEGORY("category"),
    MANUFACTURER("manufacturer");

    companion object {
        fun fromRaw(raw: String?): LibrarySourceType? {
            return when (raw?.trim()?.lowercase()) {
                "venue" -> VENUE
                "category" -> CATEGORY
                "manufacturer" -> MANUFACTURER
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
            val destination = destinationUrl ?: return null
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

internal data class Video(val kind: String?, val label: String?, val url: String?)
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
    val playfieldLocalOriginal: String?,
    val playfieldLocal: String?,
    val playfieldSourceLabel: String? = null,
    val gameinfoLocal: String?,
    val rulesheetLocal: String?,
    val rulesheetUrl: String?,
    val rulesheetLinks: List<ReferenceLink> = emptyList(),
    val videos: List<Video>,
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
        LibrarySourceType.MANUFACTURER -> listOf(
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

internal fun parseLibraryPayload(raw: String): ParsedLibraryData {
    val trimmed = raw.trim()
    if (trimmed.startsWith("{")) {
        val root = JSONObject(trimmed)
        val gamesArray = root.optJSONArray("games")
            ?: root.optJSONArray("items")
            ?: JSONArray()
        val parsedGames = parseGames(gamesArray)
        val sourcesFromRoot = parseSources(root.optJSONArray("sources") ?: root.optJSONArray("libraries"))
        val sources = if (sourcesFromRoot.isNotEmpty()) {
            sourcesFromRoot
        } else {
            inferSourcesFromGames(parsedGames)
        }
        return ParsedLibraryData(games = parsedGames, sources = sources)
    }
    val parsedGames = parseGames(JSONArray(trimmed.ifEmpty { "[]" }))
    return ParsedLibraryData(games = parsedGames, sources = inferSourcesFromGames(parsedGames))
}

internal fun parseGames(array: JSONArray): List<PinballGame> {
    return (0 until array.length()).mapNotNull { i ->
        val obj = array.optJSONObject(i) ?: return@mapNotNull null
        val name = obj.optStringOrNull("name") ?: obj.optStringOrNull("game") ?: ""
        val slug = obj.optStringOrNull("slug")
            ?: obj.optStringOrNull("practice_identity")
            ?: obj.optStringOrNull("opdb_id")
            ?: ""
        if (name.isBlank() || slug.isBlank()) return@mapNotNull null
        val sourceType = parseSourceType(
            obj.optStringOrNull("libraryType")
                ?: obj.optStringOrNull("sourceType")
                ?: obj.optStringOrNull("library_type")
        )
        val fallbackVenue = obj.optStringOrNull("venueName") ?: obj.optStringOrNull("venue")
        val sourceName = obj.optStringOrNull("libraryName")
            ?: obj.optStringOrNull("sourceName")
            ?: obj.optStringOrNull("library_name")
            ?: fallbackVenue
            ?: "The Avenue"
        val sourceId = obj.optStringOrNull("libraryId")
            ?: obj.optStringOrNull("sourceId")
            ?: obj.optStringOrNull("library_id")
            ?: slugifySourceId(sourceName)
        val assets = obj.optJSONObject("assets")
        val rawPlayfieldLocal = obj.optStringOrNull("playfieldLocal")
            ?: assets?.optStringOrNull("playfield_local_practice")
            ?: assets?.optStringOrNull("playfield_local_legacy")
        val playfieldLocalOriginal = normalizeCachePath(rawPlayfieldLocal)
        val playfieldLocal = normalizePlayfieldLocalPath(rawPlayfieldLocal)
        val rulesheetLocal = obj.optStringOrNull("rulesheetLocal")
            ?: assets?.optStringOrNull("rulesheet_local_practice")
            ?: assets?.optStringOrNull("rulesheet_local_legacy")
        val gameinfoLocal = assets?.optStringOrNull("gameinfo_local_practice")
            ?: assets?.optStringOrNull("gameinfo_local_legacy")
        val rulesheetLinks = obj.optJSONArray("rulesheet_links")?.let { links ->
            (0 until links.length()).mapNotNull { idx ->
                links.optJSONObject(idx)?.let { link ->
                    ReferenceLink(
                        label = link.optStringOrNull("label") ?: "Rulesheet",
                        url = link.optStringOrNull("url"),
                    )
                }
            }
        } ?: emptyList()

        PinballGame(
            libraryEntryId = obj.optStringOrNull("library_entry_id"),
            practiceIdentity = obj.optStringOrNull("practice_identity"),
            opdbId = obj.optStringOrNull("opdb_id"),
            opdbGroupId = obj.optStringOrNull("opdb_group_id"),
            variant = obj.optStringOrNull("variant"),
            sourceId = sourceId,
            sourceName = sourceName,
            sourceType = sourceType,
            area = (obj.optStringOrNull("area") ?: obj.optStringOrNull("location"))?.trim(),
            areaOrder = obj.optIntOrNull("areaOrder") ?: parseIntFlexible(obj.opt("area_order")),
            group = obj.optIntOrNull("group") ?: parseIntFlexible(obj.opt("group")),
            position = obj.optIntOrNull("position") ?: parseIntFlexible(obj.opt("position")),
            bank = obj.optIntOrNull("bank") ?: parseIntFlexible(obj.opt("bank")),
            name = name,
            manufacturer = obj.optStringOrNull("manufacturer"),
            year = obj.optIntOrNull("year") ?: parseIntFlexible(obj.opt("year")),
            slug = slug,
            primaryImageUrl = obj.optStringOrNull("primary_image_url"),
            primaryImageLargeUrl = obj.optStringOrNull("primary_image_large_url"),
            playfieldImageUrl = obj.optStringOrNull("playfieldImageUrl") ?: obj.optStringOrNull("playfield_image_url"),
            playfieldLocalOriginal = playfieldLocalOriginal,
            playfieldLocal = playfieldLocal,
            playfieldSourceLabel = obj.optStringOrNull("playfield_source_label"),
            gameinfoLocal = gameinfoLocal,
            rulesheetLocal = rulesheetLocal,
            rulesheetUrl = obj.optStringOrNull("rulesheetUrl") ?: obj.optStringOrNull("rulesheet_url"),
            rulesheetLinks = rulesheetLinks,
            videos = obj.optJSONArray("videos")?.let { vids ->
                (0 until vids.length()).mapNotNull { idx ->
                    vids.optJSONObject(idx)?.let { v ->
                        Video(
                            kind = v.optStringOrNull("kind"),
                            label = v.optStringOrNull("label"),
                            url = v.optStringOrNull("url"),
                        )
                    }
                }
            } ?: emptyList(),
        )
    }
}

private fun parseSources(array: JSONArray?): List<LibrarySource> {
    if (array == null) return emptyList()
    return (0 until array.length()).mapNotNull { i ->
        val obj = array.optJSONObject(i) ?: return@mapNotNull null
        val id = obj.optStringOrNull("id") ?: obj.optStringOrNull("library_id") ?: return@mapNotNull null
        val name = obj.optStringOrNull("name") ?: obj.optStringOrNull("library_name") ?: id
        val type = parseSourceType(obj.optStringOrNull("type") ?: obj.optStringOrNull("library_type"))
        LibrarySource(id = id, name = name, type = type)
    }
}

private fun inferSourcesFromGames(games: List<PinballGame>): List<LibrarySource> {
    val seen = LinkedHashMap<String, LibrarySource>()
    games.forEach { game ->
        if (!seen.containsKey(game.sourceId)) {
            seen[game.sourceId] = LibrarySource(
                id = game.sourceId,
                name = game.sourceName,
                type = game.sourceType,
            )
        }
    }
    if (seen.isEmpty()) {
        seen["the-avenue"] = LibrarySource(
            id = "the-avenue",
            name = "The Avenue",
            type = LibrarySourceType.VENUE,
        )
    }
    return seen.values.toList()
}

private fun parseSourceType(raw: String?): LibrarySourceType {
    return when (raw?.trim()?.lowercase()) {
        "category" -> LibrarySourceType.CATEGORY
        "manufacturer" -> LibrarySourceType.MANUFACTURER
        else -> LibrarySourceType.VENUE
    }
}

private fun parseIntFlexible(value: Any?): Int? = when (value) {
    is Number -> value.toInt()
    is String -> value.trim().toIntOrNull()
    else -> null
}

private fun slugifySourceId(input: String): String {
    val trimmed = input.trim().lowercase()
    if (trimmed.isBlank()) return "the-avenue"
    return trimmed
        .replace("&", "and")
        .replace(Regex("[^a-z0-9]+"), "-")
        .trim('-')
        .ifBlank { "the-avenue" }
}

internal fun normalizePlayfieldLocalPath(path: String?): String? {
    val raw = path?.trim()?.takeIf { it.isNotEmpty() } ?: return null
    val target = when {
        raw.endsWith("_700.webp", ignoreCase = true) -> raw
        raw.endsWith("_1400.webp", ignoreCase = true) -> raw.replace(Regex("_1400\\.webp$", RegexOption.IGNORE_CASE), "_700.webp")
        raw.contains("/pinball/images/playfields/") -> raw.replace(Regex("\\.[A-Za-z0-9]+$"), "_700.webp")
        else -> raw
    }
    return target
}

internal fun normalizeCachePath(path: String?): String? {
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

internal fun PinballGame.resolve(pathOrUrl: String?): String? {
    pathOrUrl ?: return null
    if (pathOrUrl.startsWith("http://") || pathOrUrl.startsWith("https://")) return pathOrUrl
    return if (pathOrUrl.startsWith("/")) "https://pillyliu.com$pathOrUrl" else "https://pillyliu.com/$pathOrUrl"
}

internal fun PinballGame.derivedPlayfield(width: Int): String? {
    val local = playfieldLocal ?: return null
    val path = if (local.startsWith("http://") || local.startsWith("https://")) {
        java.net.URI(local).path ?: return null
    } else {
        local
    }
    val slash = path.lastIndexOf('/')
    if (slash < 0) return null
    val directory = path.substring(0, slash)
    val filename = path.substring(slash + 1)
    val dot = filename.lastIndexOf('.')
    val stem = if (dot > 0) filename.substring(0, dot) else filename
    val baseStem = stem.removeSuffix("_700").removeSuffix("_1400")
    return resolve("$directory/${baseStem}_${width}.webp")
}

internal fun PinballGame.libraryPlayfieldCandidate(): String? =
    resolve(primaryImageUrl) ?: resolve(FALLBACK_WHITEWOOD_PLAYFIELD_700)
internal fun PinballGame.miniCardPlayfieldCandidate(): String? =
    listOfNotNull(
        resolve(primaryImageUrl),
        resolve(primaryImageLargeUrl),
        derivedPlayfield(700),
        resolve(playfieldLocal),
        resolve(playfieldImageUrl),
        derivedPlayfield(1400),
        resolve(FALLBACK_WHITEWOOD_PLAYFIELD_700),
        resolve(FALLBACK_WHITEWOOD_PLAYFIELD_1400),
    ).distinct().firstOrNull()
internal fun PinballGame.gameInlinePlayfieldCandidates(): List<String> =
    listOfNotNull(
        resolve(primaryImageLargeUrl),
        resolve(primaryImageUrl),
        derivedPlayfield(1400),
        derivedPlayfield(700),
        resolve(FALLBACK_WHITEWOOD_PLAYFIELD_700),
    )
        .distinct()
internal fun PinballGame.fullscreenPlayfieldCandidates(): List<String> =
    listOfNotNull(
        resolve(playfieldLocalOriginal),
        resolve(playfieldImageUrl),
        derivedPlayfield(1400),
        derivedPlayfield(700),
        resolve(FALLBACK_WHITEWOOD_PLAYFIELD_700),
    )
        .distinct()

internal val PinballGame.actualFullscreenPlayfieldCandidates: List<String>
    get() = fullscreenPlayfieldCandidates().filterNot { it.endsWith(FALLBACK_WHITEWOOD_PLAYFIELD_700) }

internal val PinballGame.hasPlayfieldResource: Boolean
    get() = actualFullscreenPlayfieldCandidates.isNotEmpty()

internal val PinballGame.hasRulesheetResource: Boolean
    get() = !rulesheetLocal.isNullOrBlank() || rulesheetLinks.isNotEmpty() || !rulesheetUrl.isNullOrBlank()

internal val PinballGame.rulesheetPathCandidates: List<String>
    get() = listOfNotNull(
        rulesheetLocal,
        practiceIdentity?.let { "/pinball/rulesheets/${it}-rulesheet.md" },
        "/pinball/rulesheets/$slug.md",
    ).distinct()

internal val PinballGame.gameinfoPathCandidates: List<String>
    get() = listOfNotNull(
        gameinfoLocal,
        practiceIdentity?.let { "/pinball/gameinfo/${it}-gameinfo.md" },
        "/pinball/gameinfo/$slug.md",
    ).distinct()

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

private fun JSONObject.optIntOrNull(name: String): Int? = if (has(name) && !isNull(name)) optInt(name) else null
private fun JSONObject.optStringOrNull(name: String): String? =
    optString(name)
        .trim()
        .takeIf { it.isNotBlank() && !it.equals("null", ignoreCase = true) }
