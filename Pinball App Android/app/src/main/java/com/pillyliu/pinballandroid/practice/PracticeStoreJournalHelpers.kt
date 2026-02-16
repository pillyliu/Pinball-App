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
    val optionalSuffix = if (trimmedNote.isNotEmpty()) ": $trimmedNote" else ""
    return when (category) {
        "rulesheet" -> "Read $value of $gameName rulesheet$optionalSuffix"
        "tutorial" -> "Tutorial progress on $gameName: $value$optionalSuffix"
        "gameplay" -> "Gameplay progress on $gameName: $value$optionalSuffix"
        "playfield" -> if (trimmedNote.isNotEmpty()) {
            "Viewed $gameName playfield: $trimmedNote"
        } else {
            "Viewed $gameName playfield"
        }
        "practice" -> if (trimmedNote.isNotEmpty()) {
            "$value on $gameName: $trimmedNote"
        } else {
            "$value on $gameName"
        }
        else -> if (trimmedNote.isNotEmpty()) {
            "Study update for $gameName: $trimmedNote"
        } else {
            "Study update for $gameName"
        }
    }
}

internal fun practiceNoteJournalSummary(
    category: String,
    gameName: String,
    detail: String?,
    note: String,
): String {
    val detailPart = detail?.takeIf { it.isNotBlank() }?.let { " ($it)" } ?: ""
    return "${category.replaceFirstChar { it.titlecase(Locale.US) }} note for $gameName$detailPart: $note"
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
