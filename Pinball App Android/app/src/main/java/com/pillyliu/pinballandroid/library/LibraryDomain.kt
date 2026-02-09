package com.pillyliu.pinballandroid.library

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.unit.dp
import org.json.JSONArray
import org.json.JSONObject

internal const val LIBRARY_URL = "https://pillyliu.com/pinball/data/pinball_library.json"
internal val LIBRARY_CONTENT_BOTTOM_FILLER = 60.dp

internal data class Video(val label: String?, val url: String?)
internal data class LibraryGroupSection(val groupKey: Int?, val games: List<PinballGame>)
internal enum class LibrarySortOption(val label: String) {
    LOCATION("Sort: Location"),
    BANK("Sort: Bank"),
    ALPHABETICAL("Sort: Alphabetical"),
}

internal data class PinballGame(
    val group: Int?,
    val pos: Int?,
    val bank: Int?,
    val name: String,
    val manufacturer: String?,
    val year: Int?,
    val slug: String,
    val playfieldImageUrl: String?,
    val playfieldLocal: String?,
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
        LibrarySortOption.LOCATION -> games.sortedWith(
            compareBy<PinballGame> { it.group ?: Int.MAX_VALUE }
                .thenBy { it.pos ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )
        LibrarySortOption.BANK -> games.sortedWith(
            compareBy<PinballGame> { it.bank ?: Int.MAX_VALUE }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.pos ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )
        LibrarySortOption.ALPHABETICAL -> games.sortedWith(
            compareBy<PinballGame> { it.name.lowercase() }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.pos ?: Int.MAX_VALUE },
        )
    }
}

internal fun parseGames(array: JSONArray): List<PinballGame> {
    return (0 until array.length()).mapNotNull { i ->
        val obj = array.optJSONObject(i) ?: return@mapNotNull null
        val name = obj.optString("name")
        val slug = obj.optString("slug")
        if (name.isBlank() || slug.isBlank()) return@mapNotNull null

        PinballGame(
            group = obj.optIntOrNull("group"),
            pos = obj.optIntOrNull("pos"),
            bank = obj.optIntOrNull("bank"),
            name = name,
            manufacturer = obj.optStringOrNull("manufacturer"),
            year = obj.optIntOrNull("year"),
            slug = slug,
            playfieldImageUrl = obj.optStringOrNull("playfieldImageUrl"),
            playfieldLocal = obj.optStringOrNull("playfieldLocal"),
            rulesheetUrl = obj.optStringOrNull("rulesheetUrl"),
            videos = obj.optJSONArray("videos")?.let { vids ->
                (0 until vids.length()).mapNotNull { idx ->
                    vids.optJSONObject(idx)?.let { v -> Video(v.optStringOrNull("label"), v.optStringOrNull("url")) }
                }
            } ?: emptyList(),
        )
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

internal fun PinballGame.locationBankLine(): String {
    val parts = mutableListOf<String>()
    locationText()?.let { parts += it }
    bank?.takeIf { it > 0 }?.let { parts += "Bank $it" }
    return if (parts.isEmpty()) "-" else parts.joinToString(" • ")
}

private fun PinballGame.locationText(): String? {
    val g = group ?: return null
    val p = pos ?: return null
    val floor = if (g in 1..4) "U" else "D"
    return "$floor:$g:$p"
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
    return resolve("${path.substring(0, slash)}/${slug}_${width}.webp")
}

internal fun PinballGame.libraryPlayfieldCandidate(): String? = derivedPlayfield(700)
internal fun PinballGame.gameInlinePlayfieldCandidates(): List<String> =
    listOfNotNull(derivedPlayfield(1400), resolve(playfieldLocal), derivedPlayfield(700))
internal fun PinballGame.fullscreenPlayfieldCandidates(): List<String> =
    listOfNotNull(resolve(playfieldLocal), derivedPlayfield(1400), derivedPlayfield(700))

internal fun openYoutubeInApp(context: android.content.Context, url: String, fallbackVideoId: String): Boolean {
    return try {
        if (url.startsWith("intent:")) {
            val intent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } else {
            val id = youtubeId(url) ?: fallbackVideoId
            val appIntent = Intent(Intent.ACTION_VIEW, Uri.parse("vnd.youtube:$id")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                context.startActivity(appIntent)
            } catch (_: ActivityNotFoundException) {
                val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/watch?v=$id")).apply {
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
private fun JSONObject.optStringOrNull(name: String): String? = optString(name).takeIf { it.isNotBlank() }
