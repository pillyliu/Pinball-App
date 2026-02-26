package com.pillyliu.pinballandroid.practice

internal enum class PracticeJournalEditKind {
    Score,
    Study,
    Practice,
    Note,
    Mechanics,
}

internal data class PracticeJournalEditDraft(
    val id: String,
    val kind: PracticeJournalEditKind,
    val gameSlug: String,
    val timestampMs: Long,
    val score: Double? = null,
    val scoreContext: String? = null,
    val tournamentName: String? = null,
    val studyCategory: String? = null,
    val studyValue: String? = null,
    val studyNote: String? = null,
    val noteCategory: String? = null,
    val noteDetail: String? = null,
    val noteText: String? = null,
)

internal fun isUserEditablePracticeJournalEntry(entry: JournalEntry): Boolean {
    return when (entry.action) {
        "score", "study", "practice", "note", "mechanics" -> true
        else -> false
    }
}

internal fun parsePracticeJournalEditDraft(
    entry: JournalEntry,
    gameName: String,
    scores: List<ScoreEntry>,
    notes: List<NoteEntry>,
): PracticeJournalEditDraft? {
    return when (entry.action) {
        "score" -> {
            val match = scores
                .filter { it.gameSlug == entry.gameSlug }
                .minByOrNull { kotlin.math.abs(it.timestampMs - entry.timestampMs) }
                ?: return null
            val rawContext = match.context
            val scoreContext = if (rawContext.startsWith("tournament:")) "tournament" else rawContext
            val tournamentName = rawContext.removePrefix("tournament:").takeIf { rawContext.startsWith("tournament:") && it.isNotBlank() }
            PracticeJournalEditDraft(
                id = entry.id,
                kind = PracticeJournalEditKind.Score,
                gameSlug = entry.gameSlug,
                timestampMs = entry.timestampMs,
                score = match.score,
                scoreContext = scoreContext,
                tournamentName = tournamentName,
            )
        }

        "note", "mechanics" -> {
            val match = notes
                .filter { it.gameSlug == entry.gameSlug }
                .minByOrNull { kotlin.math.abs(it.timestampMs - entry.timestampMs) }
                ?: return null
            PracticeJournalEditDraft(
                id = entry.id,
                kind = if (entry.action == "mechanics") PracticeJournalEditKind.Mechanics else PracticeJournalEditKind.Note,
                gameSlug = entry.gameSlug,
                timestampMs = entry.timestampMs,
                noteCategory = match.category,
                noteDetail = match.detail,
                noteText = match.note,
            )
        }

        "study", "practice" -> {
            val parsed = parseStudyLikeSummary(entry.summary, gameName, entry.action)
            PracticeJournalEditDraft(
                id = entry.id,
                kind = if (entry.action == "practice") PracticeJournalEditKind.Practice else PracticeJournalEditKind.Study,
                gameSlug = entry.gameSlug,
                timestampMs = entry.timestampMs,
                studyCategory = parsed.category,
                studyValue = parsed.value,
                studyNote = parsed.note,
            )
        }

        else -> null
    }
}

internal data class ParsedStudyLikeSummary(
    val category: String,
    val value: String,
    val note: String?,
)

private fun splitOptionalSuffix(raw: String): Pair<String, String?> {
    val idx = raw.indexOf(": ")
    if (idx < 0) return raw.trim() to null
    return raw.substring(0, idx).trim() to raw.substring(idx + 2).trim().ifBlank { null }
}

internal fun parseStudyLikeSummary(summary: String, gameName: String, action: String): ParsedStudyLikeSummary {
    if (action == "practice") {
        if (summary.startsWith("Practice:\n")) {
            val bodyAndGame = summary.removePrefix("Practice:\n").split("\n• ", limit = 2)
            val body = bodyAndGame.firstOrNull().orEmpty().trim()
            val bodyLines = body.lines().map { it.trimEnd() }.dropLastWhile { it.isBlank() }
            val value = bodyLines.firstOrNull()?.trim()?.ifBlank { "Practice session" } ?: "Practice session"
            val note = bodyLines.drop(1).joinToString("\n").trim().ifBlank { null }
            return ParsedStudyLikeSummary(category = "practice", value = value, note = note)
        }
        val marker = " on $gameName"
        val (head, note) = splitOptionalSuffix(summary)
        val value = head.substringBefore(marker).ifBlank { "Practice session" }.trim()
        return ParsedStudyLikeSummary(category = "practice", value = value, note = note)
    }

    parseStructuredStudySummary(summary)?.let { return it }

    if (summary.startsWith("Read ") && summary.contains(" rulesheet")) {
        val prefix = "Read "
        val suffix = " of $gameName rulesheet"
        val (head, note) = splitOptionalSuffix(summary)
        val value = head.removePrefix(prefix).substringBefore(suffix).trim().ifBlank { "0%" }
        return ParsedStudyLikeSummary(category = "rulesheet", value = value, note = note)
    }
    if (summary.startsWith("Tutorial progress on $gameName: ")) {
        val raw = summary.removePrefix("Tutorial progress on $gameName: ")
        val (value, note) = splitOptionalSuffix(raw)
        return ParsedStudyLikeSummary(category = "tutorial", value = value, note = note)
    }
    if (summary.startsWith("Gameplay progress on $gameName: ")) {
        val raw = summary.removePrefix("Gameplay progress on $gameName: ")
        val (value, note) = splitOptionalSuffix(raw)
        return ParsedStudyLikeSummary(category = "gameplay", value = value, note = note)
    }
    if (summary.startsWith("Viewed $gameName playfield")) {
        val raw = summary.removePrefix("Viewed $gameName playfield")
        val note = raw.removePrefix(": ").trim().ifBlank { null }
        return ParsedStudyLikeSummary(category = "playfield", value = "Viewed", note = note)
    }
    return ParsedStudyLikeSummary(category = "study", value = summary, note = null)
}

private fun parseStructuredStudySummary(summary: String): ParsedStudyLikeSummary? {
    val headers = listOf(
        "Rulesheet" to "rulesheet",
        "Tutorial Video" to "tutorial",
        "Gameplay Video" to "gameplay",
        "Playfield" to "playfield",
    )
    val match = headers.firstOrNull { summary.startsWith("${it.first}:\n") } ?: return null
    val bodyAndGame = summary.removePrefix("${match.first}:\n").split("\n• ", limit = 2)
    val body = bodyAndGame.firstOrNull().orEmpty().trim()
    if (body.isBlank()) return null
    val bodyLines = body.lines().map { it.trimEnd() }.dropLastWhile { it.isBlank() }
    val first = bodyLines.firstOrNull()?.trim().orEmpty()
    val note = bodyLines.drop(1).joinToString("\n").trim().ifBlank { null }
    val value = when (match.second) {
        "rulesheet", "tutorial", "gameplay" -> first.removePrefix("Progress: ").ifBlank { "0%" }
        "playfield" -> "Viewed"
        else -> first
    }
    return ParsedStudyLikeSummary(category = match.second, value = value, note = note)
}

internal fun rebuildRulesheetProgressFromJournal(
    journal: List<JournalEntry>,
): Map<String, Float> {
    val sorted = journal.sortedBy { it.timestampMs }
    val next = linkedMapOf<String, Float>()
    sorted.forEach { entry ->
        if (entry.action != "study") return@forEach
        val parsed = parseStudyLikeSummary(entry.summary, gameName = "", action = "study")
        if (parsed.category != "rulesheet") return@forEach
        val percent = Regex("""(\d{1,3})\s*%""").find(parsed.value)?.groupValues?.getOrNull(1)?.toIntOrNull()
        if (percent != null) {
            next[entry.gameSlug] = (percent.coerceIn(0, 100) / 100f)
        }
    }
    return next
}
