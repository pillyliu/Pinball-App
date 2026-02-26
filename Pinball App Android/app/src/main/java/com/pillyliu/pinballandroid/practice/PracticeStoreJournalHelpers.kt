package com.pillyliu.pinballandroid.practice

import java.util.Locale

internal fun studyJournalActionForCategory(category: String): String =
    if (category == "practice") "practice" else "study"

internal fun studyJournalSummaryForCategory(
    category: String,
    value: String,
    gameName: String,
    note: String?,
): String {
    val trimmedNote = note?.trim().orEmpty()
    return when (category) {
        "rulesheet" -> structuredStudyJournalSummary("Rulesheet", "Progress: $value", gameName, trimmedNote.ifBlank { null })
        "tutorial" -> structuredStudyJournalSummary("Tutorial Video", "Progress: $value", gameName, trimmedNote.ifBlank { null })
        "gameplay" -> structuredStudyJournalSummary("Gameplay Video", "Progress: $value", gameName, trimmedNote.ifBlank { null })
        "playfield" -> structuredStudyJournalSummary("Playfield", "Viewed playfield", gameName, trimmedNote.ifBlank { null })
        "practice" -> {
            val parts = parsePracticeSessionParts(value = value, note = note)
            buildString {
                append("Practice:\n")
                append(parts.value)
                if (!parts.note.isNullOrBlank()) {
                    append('\n')
                    append(parts.note)
                }
                append("\n• ")
                append(gameName)
            }
        }
        else -> if (trimmedNote.isNotEmpty()) {
            "Study update for $gameName: $trimmedNote"
        } else {
            "Study update for $gameName"
        }
    }
}

private fun structuredStudyJournalSummary(
    title: String,
    valueLine: String,
    gameName: String,
    note: String?,
): String = buildString {
    append(title)
    append(":\n")
    append(valueLine)
    if (!note.isNullOrBlank()) {
        append('\n')
        append(note)
    }
    append("\n• ")
    append(gameName)
}

internal fun practiceNoteJournalSummary(
    category: String,
    gameName: String,
    detail: String?,
    note: String,
): String {
    if (category.equals("general", ignoreCase = true) && detail.equals("Game Note", ignoreCase = true)) {
        return "Game Note:\n$note\n• $gameName"
    }
    val detailPart = detail?.takeIf { it.isNotBlank() }?.let { " ($it)" } ?: ""
    return "${category.replaceFirstChar { it.titlecase(Locale.US) }} note$detailPart: $note\n• $gameName"
}

internal data class PracticeSessionParts(
    val value: String,
    val note: String?,
)

internal fun parsePracticeSessionParts(
    value: String?,
    note: String?,
): PracticeSessionParts {
    val explicitValue = value?.trim().orEmpty()
    val explicitNote = note?.replace("\r\n", "\n")?.trim()?.ifBlank { null }
    if (explicitValue.isNotBlank() && explicitNote != null) {
        return PracticeSessionParts(explicitValue, explicitNote)
    }

    val raw = (if (explicitValue.isNotBlank()) explicitValue else explicitNote.orEmpty())
        .replace("\r\n", "\n")
        .trim()
    if (raw.isBlank()) return PracticeSessionParts("Practice session", null)

    if (raw.startsWith("Practice session")) {
        val newlineIdx = raw.indexOf('\n')
        if (newlineIdx > 0) {
            val parsedValue = raw.substring(0, newlineIdx).trim().ifBlank { "Practice session" }
            val parsedNote = raw.substring(newlineIdx + 1).trim().ifBlank { null }
            return PracticeSessionParts(parsedValue, parsedNote)
        }
        val dotIdx = raw.indexOf(". ")
        if (dotIdx > 0) {
            val parsedValue = raw.substring(0, dotIdx).trim().ifBlank { "Practice session" }
            val parsedNote = raw.substring(dotIdx + 2).trim().ifBlank { null }
            return PracticeSessionParts(parsedValue, parsedNote)
        }
        return PracticeSessionParts(raw, null)
    }

    return PracticeSessionParts("Practice session", raw)
}

internal fun composePracticeSessionNote(
    value: String,
    note: String?,
): String {
    val parsed = parsePracticeSessionParts(value = value, note = note)
    return if (parsed.note.isNullOrBlank()) parsed.value else "${parsed.value}\n${parsed.note}"
}

internal fun filteredJournalItems(
    journal: List<JournalEntry>,
    filter: JournalFilter,
): List<JournalEntry> {
    val filtered = when (filter) {
        JournalFilter.All -> journal
        JournalFilter.Study -> journal.filter { it.action == "study" }
        JournalFilter.Practice -> journal.filter { it.action == "practice" }
        JournalFilter.Scores -> journal.filter { it.action == "score" }
        JournalFilter.Notes -> journal.filter { it.action == "note" || it.action == "mechanics" }
        JournalFilter.League -> journal.filter { it.action == "score" && it.summary.contains("League", ignoreCase = true) }
    }
    return filtered.sortedByDescending { it.timestampMs }
}
