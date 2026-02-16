package com.pillyliu.pinballandroid.practice

import java.util.Locale

internal fun buildScoreEntry(
    gameSlug: String,
    score: Double,
    context: String,
    timestampMs: Long,
    leagueImported: Boolean,
): ScoreEntry {
    return ScoreEntry(
        id = "score-${System.nanoTime()}",
        gameSlug = gameSlug,
        score = score,
        context = context,
        timestampMs = timestampMs,
        leagueImported = leagueImported,
    )
}

internal fun buildScoreJournalEntry(
    gameSlug: String,
    gameName: String,
    score: Double,
    context: String,
    timestampMs: Long,
): JournalEntry {
    return JournalEntry(
        id = "journal-${System.nanoTime()}",
        gameSlug = gameSlug,
        action = "score",
        summary = "Logged ${formatScore(score)} on $gameName (${context.replaceFirstChar { it.titlecase(Locale.US) }})",
        timestampMs = timestampMs,
    )
}

internal fun buildStudyJournalEntry(
    gameSlug: String,
    action: String,
    summary: String,
    timestampMs: Long,
): JournalEntry {
    return JournalEntry(
        id = "journal-${System.nanoTime()}",
        gameSlug = gameSlug,
        action = action,
        summary = summary,
        timestampMs = timestampMs,
    )
}

internal fun buildPracticeNoteEntry(
    gameSlug: String,
    category: String,
    detail: String?,
    note: String,
    timestampMs: Long,
): NoteEntry {
    return NoteEntry(
        id = "note-${System.nanoTime()}",
        gameSlug = gameSlug,
        category = category,
        detail = detail?.trim()?.ifBlank { null },
        note = note,
        timestampMs = timestampMs,
    )
}

internal fun buildNoteJournalEntry(
    gameSlug: String,
    category: String,
    summary: String,
    timestampMs: Long,
): JournalEntry {
    return JournalEntry(
        id = "journal-${System.nanoTime()}",
        gameSlug = gameSlug,
        action = if (category == "mechanics") "mechanics" else "note",
        summary = summary,
        timestampMs = timestampMs,
    )
}
