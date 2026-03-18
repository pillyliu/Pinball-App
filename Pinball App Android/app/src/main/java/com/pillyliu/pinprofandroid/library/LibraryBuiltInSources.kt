package com.pillyliu.pinprofandroid.library

internal const val PM_AVENUE_LIBRARY_SOURCE_ID = "venue--pm-8760"
internal const val PM_RLM_LIBRARY_SOURCE_ID = "venue--pm-16470"
internal const val BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID = "venue--gameroom"

private val builtinVenueSourceIdAliases = mapOf(
    "the-avenue" to PM_AVENUE_LIBRARY_SOURCE_ID,
    "the-avenue-cafe" to PM_AVENUE_LIBRARY_SOURCE_ID,
    "venue--the-avenue-cafe" to PM_AVENUE_LIBRARY_SOURCE_ID,
    "rlm-amusements" to PM_RLM_LIBRARY_SOURCE_ID,
    "venue--rlm-amusements" to PM_RLM_LIBRARY_SOURCE_ID,
)

private val builtinVenueSourceNames = mapOf(
    PM_RLM_LIBRARY_SOURCE_ID to "RLM Amusements",
    PM_AVENUE_LIBRARY_SOURCE_ID to "The Avenue Cafe",
    BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID to "GameRoom",
)

internal val defaultBuiltinVenueSourceIds = listOf(
    PM_RLM_LIBRARY_SOURCE_ID,
    PM_AVENUE_LIBRARY_SOURCE_ID,
)

internal fun canonicalBuiltinVenueLibrarySourceId(raw: String?): String? {
    val trimmed = raw?.trim().orEmpty()
    if (trimmed.isEmpty()) return null
    return builtinVenueSourceIdAliases[trimmed]
}

internal fun canonicalLibrarySourceId(raw: String?): String? {
    val trimmed = raw?.trim().orEmpty()
    if (trimmed.isEmpty()) return null
    return canonicalBuiltinVenueLibrarySourceId(trimmed) ?: trimmed
}

internal fun builtinVenueSourceName(sourceId: String?): String? {
    val canonicalId = canonicalLibrarySourceId(sourceId) ?: return null
    return builtinVenueSourceNames[canonicalId]
}

internal fun builtinVenueSources(includeGameRoom: Boolean = false): List<LibrarySource> {
    val ids = buildList {
        addAll(defaultBuiltinVenueSourceIds)
        if (includeGameRoom) add(BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID)
    }
    return ids.mapNotNull { id ->
        builtinVenueSourceNames[id]?.let { name ->
            LibrarySource(id = id, name = name, type = LibrarySourceType.VENUE)
        }
    }
}

internal fun isAvenueLibrarySourceId(raw: String?): Boolean =
    canonicalLibrarySourceId(raw) == PM_AVENUE_LIBRARY_SOURCE_ID

internal fun isGameRoomLibrarySourceId(raw: String?): Boolean =
    canonicalLibrarySourceId(raw) == BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID

internal fun isImportedPinballMapSourceId(raw: String?): Boolean =
    canonicalLibrarySourceId(raw)?.lowercase()?.startsWith("venue--pm-") == true
