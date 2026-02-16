package com.pillyliu.pinballandroid.practice

internal data class ScoreEntryMutation(
    val scores: List<ScoreEntry>,
    val journal: List<JournalEntry>,
)

internal data class StudyEntryMutation(
    val rulesheetProgress: Map<String, Float>,
    val journal: List<JournalEntry>,
)

internal data class PracticeNoteMutation(
    val notes: List<NoteEntry>,
    val journal: List<JournalEntry>,
)

internal fun applyScoreEntryMutation(
    scores: List<ScoreEntry>,
    journal: List<JournalEntry>,
    gameSlug: String,
    gameName: String,
    score: Double,
    context: String,
    timestampMs: Long,
    leagueImported: Boolean,
): ScoreEntryMutation {
    val entry = buildScoreEntry(gameSlug, score, context, timestampMs, leagueImported)
    return ScoreEntryMutation(
        scores = scores + entry,
        journal = journal + buildScoreJournalEntry(gameSlug, gameName, score, context, timestampMs),
    )
}

internal fun applyStudyEntryMutation(
    journal: List<JournalEntry>,
    rulesheetProgress: Map<String, Float>,
    gameSlug: String,
    gameName: String,
    category: String,
    value: String,
    note: String?,
    timestampMs: Long,
): StudyEntryMutation {
    val nextRulesheetProgress = if (category == "rulesheet") {
        val percent = Regex("""(\d{1,3})\s*%?""").find(value.trim())?.groupValues?.getOrNull(1)?.toIntOrNull()
        if (percent != null) {
            rulesheetProgress + (gameSlug to (percent.coerceIn(0, 100) / 100f))
        } else {
            rulesheetProgress
        }
    } else {
        rulesheetProgress
    }
    val action = studyJournalActionForCategory(category)
    val summary = studyJournalSummaryForCategory(category, value, gameName, note)
    return StudyEntryMutation(
        rulesheetProgress = nextRulesheetProgress,
        journal = journal + buildStudyJournalEntry(
            gameSlug = gameSlug,
            action = action,
            summary = summary,
            timestampMs = timestampMs,
        ),
    )
}

internal fun applyPracticeNoteMutation(
    notes: List<NoteEntry>,
    journal: List<JournalEntry>,
    gameSlug: String,
    gameName: String,
    category: String,
    detail: String?,
    note: String,
    timestampMs: Long,
): PracticeNoteMutation? {
    val trimmed = note.trim()
    if (trimmed.isEmpty()) return null
    val entry = buildPracticeNoteEntry(
        gameSlug = gameSlug,
        category = category,
        detail = detail,
        note = trimmed,
        timestampMs = timestampMs,
    )
    return PracticeNoteMutation(
        notes = notes + entry,
        journal = journal + buildNoteJournalEntry(
            gameSlug = gameSlug,
            category = category,
            summary = practiceNoteJournalSummary(
                category = category,
                gameName = gameName,
                detail = entry.detail,
                note = entry.note,
            ),
            timestampMs = entry.timestampMs,
        ),
    )
}
