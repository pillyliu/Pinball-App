package com.pillyliu.pinballandroid.library

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.net.toUri
import androidx.compose.ui.unit.dp
import org.json.JSONArray
import org.json.JSONObject

internal const val LIBRARY_URL = "https://pillyliu.com/pinball/data/pinball_library_v2.json"
internal val LIBRARY_CONTENT_BOTTOM_FILLER = 60.dp
private const val FALLBACK_WHITEWOOD_PLAYFIELD_700 = "/pinball/images/playfields/fallback-whitewood-playfield_700.webp"
private const val FALLBACK_WHITEWOOD_PLAYFIELD_1400 = "/pinball/images/playfields/fallback-whitewood-playfield_1400.webp"

internal enum class LibrarySourceType {
    VENUE,
    CATEGORY,
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
        }
}

internal data class ParsedLibraryData(
    val games: List<PinballGame>,
    val sources: List<LibrarySource>,
)

internal data class Video(val kind: String?, val label: String?, val url: String?)
internal data class LibraryGroupSection(val groupKey: Int?, val games: List<PinballGame>)
internal enum class LibraryRouteKind {
    LIST,
    DETAIL,
    RULESHEET,
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
    val playfieldImageUrl: String?,
    val playfieldLocal: String?,
    val gameinfoLocal: String?,
    val rulesheetLocal: String?,
    val rulesheetUrl: String?,
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

internal fun sortLibraryGames(games: List<PinballGame>, option: LibrarySortOption): List<PinballGame> {
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
        LibrarySortOption.YEAR -> games.sortedWith(
            compareBy<PinballGame> { it.year ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )
    }
}

internal fun sortOptionsForSource(source: LibrarySource, games: List<PinballGame>): List<LibrarySortOption> {
    return when (source.type) {
        LibrarySourceType.CATEGORY -> listOf(
            LibrarySortOption.ALPHABETICAL,
            LibrarySortOption.YEAR,
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
        val slug = obj.optStringOrNull("slug") ?: obj.optStringOrNull("pinside_slug") ?: ""
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
        val playfieldLocal = obj.optStringOrNull("playfieldLocal")
            ?: assets?.optStringOrNull("playfield_local_practice")
            ?: assets?.optStringOrNull("playfield_local_legacy")
        val rulesheetLocal = obj.optStringOrNull("rulesheetLocal")
            ?: assets?.optStringOrNull("rulesheet_local_practice")
            ?: assets?.optStringOrNull("rulesheet_local_legacy")
        val gameinfoLocal = assets?.optStringOrNull("gameinfo_local_practice")
            ?: assets?.optStringOrNull("gameinfo_local_legacy")

        PinballGame(
            libraryEntryId = obj.optStringOrNull("library_entry_id"),
            practiceIdentity = obj.optStringOrNull("practice_identity"),
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
            playfieldImageUrl = obj.optStringOrNull("playfieldImageUrl") ?: obj.optStringOrNull("playfield_image_url"),
            playfieldLocal = playfieldLocal,
            gameinfoLocal = gameinfoLocal,
            rulesheetLocal = rulesheetLocal,
            rulesheetUrl = obj.optStringOrNull("rulesheetUrl") ?: obj.optStringOrNull("rulesheet_url"),
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
        "category", "manufacturer" -> LibrarySourceType.CATEGORY
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

internal fun PinballGame.locationBankLine(): String {
    val parts = mutableListOf<String>()
    locationText()?.let { parts += it }
    bank?.takeIf { it > 0 }?.let { parts += "Bank $it" }
    return if (parts.isEmpty()) "-" else parts.joinToString(" • ")
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
    derivedPlayfield(700) ?: resolve(playfieldLocal) ?: resolve(FALLBACK_WHITEWOOD_PLAYFIELD_700)
internal fun PinballGame.miniCardPlayfieldCandidate(): String? =
    derivedPlayfield(700) ?: resolve(playfieldLocal) ?: resolve(FALLBACK_WHITEWOOD_PLAYFIELD_700)
internal fun PinballGame.gameInlinePlayfieldCandidates(): List<String> =
    listOfNotNull(
        derivedPlayfield(1400),
        resolve(playfieldLocal),
        derivedPlayfield(700),
    )
internal fun PinballGame.fullscreenPlayfieldCandidates(): List<String> =
    listOfNotNull(
        resolve(playfieldLocal),
        derivedPlayfield(1400),
        derivedPlayfield(700),
    )

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
