package com.pillyliu.pinprofandroid.gameroom

import java.net.URL

internal fun buildPinsideCollectionURL(input: String): URL {
    if (input.contains("pinside.com", ignoreCase = true)) {
        val parsed = runCatching { URL(input) }.getOrNull()
        val host = parsed?.host?.lowercase().orEmpty()
        if (parsed == null || !host.contains("pinside.com")) {
            throw pinsideImportException(GameRoomPinsideImportError.invalidURL)
        }
        val path = parsed.path.orEmpty()
        if (path.contains("/collection/", ignoreCase = true)) return parsed
        val segments = path.split("/").filter { it.isNotBlank() }
        val pinsiderIndex = segments.indexOfLast { it.equals("pinsiders", ignoreCase = true) }
        val profileUsername = segments.getOrNull(pinsiderIndex + 1).orEmpty()
        if (pinsiderIndex >= 0 && profileUsername.isNotBlank()) {
            return URL("https://pinside.com/pinball/community/pinsiders/${profileUsername.lowercase()}/collection/current")
        }
        return parsed
    }

    val username = input.replace("@", "").trim().lowercase()
    if (username.isBlank()) {
        throw pinsideImportException(GameRoomPinsideImportError.invalidInput)
    }
    return runCatching {
        URL("https://pinside.com/pinball/community/pinsiders/$username/collection/current")
    }.getOrElse {
        throw pinsideImportException(GameRoomPinsideImportError.invalidURL)
    }
}
