package com.pillyliu.pinprofandroid.library

import org.json.JSONArray
import org.json.JSONObject

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
                ?: obj.optStringOrNull("library_type"),
        )
        val fallbackVenue = obj.optStringOrNull("venueName") ?: obj.optStringOrNull("venue")
        val sourceId = obj.optStringOrNull("libraryId")
            ?: obj.optStringOrNull("sourceId")
            ?: obj.optStringOrNull("library_id")
        val fallbackSourceName = obj.optStringOrNull("libraryName")
            ?: obj.optStringOrNull("sourceName")
            ?: obj.optStringOrNull("library_name")
            ?: fallbackVenue
            ?: builtinVenueSourceName(PM_AVENUE_LIBRARY_SOURCE_ID)
            ?: "The Avenue Cafe"
        val canonicalSourceId = canonicalLibrarySourceId(sourceId) ?: slugifySourceId(fallbackSourceName)
        val sourceName = builtinVenueSourceName(canonicalSourceId) ?: fallbackSourceName
        val assets = obj.optJSONObject("assets")
        val rawPlayfieldLocal = obj.optStringOrNull("playfieldLocal")
            ?: assets?.optStringOrNull("playfield_local_practice")
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
            opdbMachineId = obj.optStringOrNull("opdb_machine_id"),
            variant = obj.optStringOrNull("variant"),
            sourceId = canonicalSourceId,
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
            opdbName = obj.optStringOrNull("opdb_name"),
            opdbCommonName = obj.optStringOrNull("opdb_common_name"),
            opdbShortname = obj.optStringOrNull("opdb_shortname"),
            opdbDescription = obj.optStringOrNull("opdb_description"),
            opdbType = obj.optStringOrNull("opdb_type"),
            opdbDisplay = obj.optStringOrNull("opdb_display"),
            opdbPlayerCount = obj.optIntOrNull("opdb_player_count") ?: parseIntFlexible(obj.opt("opdb_player_count")),
            opdbManufactureDate = obj.optStringOrNull("opdb_manufacture_date"),
            opdbIpdbId = obj.optIntOrNull("opdb_ipdb_id") ?: parseIntFlexible(obj.opt("opdb_ipdb_id")),
            opdbGroupShortname = obj.optStringOrNull("opdb_group_shortname"),
            opdbGroupDescription = obj.optStringOrNull("opdb_group_description"),
            primaryImageUrl = obj.optStringOrNull("primary_image_url"),
            primaryImageLargeUrl = obj.optStringOrNull("primary_image_large_url"),
            playfieldImageUrl = obj.optStringOrNull("playfieldImageUrl") ?: obj.optStringOrNull("playfield_image_url"),
            alternatePlayfieldImageUrl = obj.optStringOrNull("alternate_playfield_image_url"),
            playfieldLocalOriginal = normalizeLibraryCachePath(rawPlayfieldLocal),
            playfieldLocal = normalizeLibraryPlayfieldLocalPath(rawPlayfieldLocal),
            playfieldSourceLabel = obj.optStringOrNull("playfield_source_label"),
            gameinfoLocal = assets?.optStringOrNull("gameinfo_local_practice"),
            rulesheetLocal = obj.optStringOrNull("rulesheetLocal")
                ?: assets?.optStringOrNull("rulesheet_local_practice"),
            rulesheetUrl = obj.optStringOrNull("rulesheetUrl") ?: obj.optStringOrNull("rulesheet_url"),
            rulesheetLinks = rulesheetLinks,
            videos = obj.optJSONArray("videos")?.let { vids ->
                (0 until vids.length()).mapNotNull { idx ->
                    vids.optJSONObject(idx)?.let { video ->
                        Video(
                            kind = video.optStringOrNull("kind"),
                            label = video.optStringOrNull("label"),
                            url = video.optStringOrNull("url"),
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
        val id = canonicalLibrarySourceId(obj.optStringOrNull("id") ?: obj.optStringOrNull("library_id")) ?: return@mapNotNull null
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
        builtinVenueSources().firstOrNull { it.id == PM_AVENUE_LIBRARY_SOURCE_ID }?.let { avenue ->
            seen[avenue.id] = avenue
        }
    }
    return seen.values.toList()
}

private fun parseSourceType(raw: String?): LibrarySourceType {
    return when (raw?.trim()?.lowercase()) {
        "category" -> LibrarySourceType.CATEGORY
        "manufacturer" -> LibrarySourceType.MANUFACTURER
        "tournament" -> LibrarySourceType.TOURNAMENT
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
    if (trimmed.isBlank()) return PM_AVENUE_LIBRARY_SOURCE_ID
    val slug = trimmed
        .replace("&", "and")
        .replace(Regex("[^a-z0-9]+"), "-")
        .trim('-')
        .ifBlank { PM_AVENUE_LIBRARY_SOURCE_ID }
    return canonicalLibrarySourceId(slug) ?: slug
}

private fun JSONObject.optIntOrNull(name: String): Int? = if (has(name) && !isNull(name)) optInt(name) else null

private fun JSONObject.optStringOrNull(name: String): String? =
    optString(name)
        .trim()
        .takeIf { it.isNotBlank() && !it.equals("null", ignoreCase = true) }
