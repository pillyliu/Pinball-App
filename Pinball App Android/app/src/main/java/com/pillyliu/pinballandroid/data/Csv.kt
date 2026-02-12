package com.pillyliu.pinballandroid.data

private const val REDACTION_TOKEN_SALT = "pinball-app-redaction-v1"
private const val REDACTED_PLAYERS_CSV_PATH = "/pinball/data/redacted_players.csv"
@Volatile private var redactedPlayersNormalized: Set<String> = emptySet()

fun parseCsv(text: String): List<List<String>> {
    val rows = mutableListOf<List<String>>()
    val row = mutableListOf<String>()
    val field = StringBuilder()
    var inQuotes = false
    var i = 0

    while (i < text.length) {
        val c = text[i]
        if (inQuotes) {
            if (c == '"') {
                if (i + 1 < text.length && text[i + 1] == '"') {
                    field.append('"')
                    i += 1
                } else {
                    inQuotes = false
                }
            } else {
                field.append(c)
            }
        } else {
            when (c) {
                '"' -> inQuotes = true
                ',' -> {
                    row.add(field.toString())
                    field.setLength(0)
                }
                '\n' -> {
                    row.add(field.toString())
                    rows.add(row.toList())
                    row.clear()
                    field.setLength(0)
                }
                '\r' -> Unit
                else -> field.append(c)
            }
        }
        i += 1
    }

    if (field.isNotEmpty() || row.isNotEmpty()) {
        row.add(field.toString())
        rows.add(row.toList())
    }

    return rows
}

fun redactPlayerNameForDisplay(raw: String): String {
    val trimmed = raw.trim()
    return if (shouldRedactPlayerName(trimmed)) "Redacted ${redactionToken(trimmed)}" else trimmed
}

suspend fun refreshRedactedPlayersFromCsv() {
    try {
        val result = PinballDataCache.loadText(REDACTED_PLAYERS_CSV_PATH, allowMissing = true)
        redactedPlayersNormalized = parseRedactedPlayersCsv(result.text)
    } catch (_: Throwable) {
        // Keep prior values if CSV cannot be refreshed.
    }
}

private fun shouldRedactPlayerName(raw: String): Boolean {
    val normalized = normalizePlayerName(raw)
    if (normalized.isBlank()) return false
    return redactedPlayersNormalized.contains(normalized)
}

private fun normalizePlayerName(raw: String): String {
    return raw.trim().lowercase().split(Regex("\\s+")).filter { it.isNotBlank() }.joinToString(" ")
}

private fun redactionToken(raw: String): String {
    val normalized = normalizePlayerName(raw)
    val bytes = java.security.MessageDigest.getInstance("SHA-256")
        .digest("$REDACTION_TOKEN_SALT:$normalized".toByteArray(Charsets.UTF_8))
    return bytes.take(3).joinToString("") { "%02X".format(it.toInt() and 0xFF) }
}

private fun parseRedactedPlayersCsv(text: String?): Set<String> {
    if (text.isNullOrBlank()) return emptySet()
    val rows = parseCsv(text)
    if (rows.isEmpty()) return emptySet()

    val header = rows.first().map { it.replace("\uFEFF", "").trim().lowercase() }
    val hasHeader = header.contains("name") || header.contains("player") || header.contains("player_name")
    val nameIndex = header.indexOfFirst { it == "name" || it == "player" || it == "player_name" }.let {
        if (it >= 0) it else 0
    }
    val dataRows = if (hasHeader) rows.drop(1) else rows

    return dataRows.mapNotNull { row ->
        if (nameIndex >= row.size) return@mapNotNull null
        val normalized = normalizePlayerName(row[nameIndex])
        normalized.takeIf { it.isNotBlank() }
    }.toSet()
}
