package com.pillyliu.pinballandroid.practice

import com.pillyliu.pinballandroid.library.PinballGame
import java.util.Calendar
import kotlin.math.roundToInt

internal fun scoreValuesForGame(scores: List<ScoreEntry>, gameSlug: String): List<Double> =
    scores.filter { it.gameSlug == gameSlug }.sortedByDescending { it.timestampMs }.map { it.score }

internal fun scoreTrendValuesForGame(scores: List<ScoreEntry>, gameSlug: String, limit: Int): List<Double> =
    scores
        .filter { it.gameSlug == gameSlug }
        .sortedBy { it.timestampMs }
        .takeLast(limit)
        .map { it.score }

internal fun computeScoreSummaryForGame(scores: List<ScoreEntry>, gameSlug: String): ScoreSummary? {
    val values = scoreValuesForGame(scores, gameSlug)
    if (values.isEmpty()) return null
    val sorted = values.sorted()
    val mean = values.average()
    val median = if (sorted.size % 2 == 0) {
        val upper = sorted.size / 2
        (sorted[upper - 1] + sorted[upper]) / 2.0
    } else {
        sorted[sorted.size / 2]
    }
    val p75 = percentile(sorted, 0.75)
    val p25 = percentile(sorted, 0.25)
    return ScoreSummary(
        high = sorted.last(),
        low = sorted.first(),
        mean = mean,
        median = median,
        stdev = stddev(values, mean),
        p25 = p25,
        targetHigh = p75,
        targetMain = median,
        targetFloor = sorted.first(),
    )
}

internal fun computeTaskProgressForGame(
    journal: List<JournalEntry>,
    rulesheetProgress: Map<String, Float>,
    gameSlug: String,
    startDateMs: Long? = null,
    endDateMs: Long? = null,
): Map<String, Int> {
    val scopedJournal = filterJournalByDateWindow(journal, startDateMs, endDateMs)
    val rulesheetPercent = if (startDateMs != null || endDateMs != null) {
        latestStudyPercentFromJournal(scopedJournal, gameSlug, "rulesheet")
    } else {
        rulesheetProgress[gameSlug]?.times(100)?.roundToInt()
            ?: latestStudyPercentFromJournal(scopedJournal, gameSlug, "rulesheet")
    }
    return mapOf(
        "rulesheet" to rulesheetPercent,
        "tutorial" to latestStudyPercentFromJournal(scopedJournal, gameSlug, "tutorial"),
        "gameplay" to latestStudyPercentFromJournal(scopedJournal, gameSlug, "gameplay"),
        "playfield" to if (scopedJournal.any { it.gameSlug == gameSlug && it.summary.contains("playfield", ignoreCase = true) }) 100 else 0,
        "practice" to if (scopedJournal.any { it.gameSlug == gameSlug && it.action == "practice" }) 100 else 0,
    )
}

internal fun computeGroupDashboardScore(
    group: PracticeGroup,
    games: List<PinballGame>,
    scores: List<ScoreEntry>,
    journal: List<JournalEntry>,
    rulesheetProgress: Map<String, Float>,
): GroupDashboardScore {
    val scopedJournal = filterJournalByDateWindow(journal, group.startDateMs, group.endDateMs)
    val groupGames = groupGamesFromList(group, games)
    if (groupGames.isEmpty()) {
        return GroupDashboardScore(
            completionAverage = 0,
            staleGameCount = 0,
            weakerGameCount = 0,
            recommendedSlug = null,
        )
    }

    val completionValues = groupGames.map { game ->
        studyCompletionPercentForGame(scopedJournal, rulesheetProgress, game.practiceKey)
    }
    val completionAverage = (completionValues.average()).roundToInt()
    val now = System.currentTimeMillis()
    val staleCount = groupGames.count { game ->
        val latest = latestPracticeTimestampForGame(scopedJournal, game.practiceKey)
        latest == null || ((now - latest) / (1000L * 60L * 60L * 24L)) >= 14
    }
    val weakerCount = groupGames.count { game ->
        val summary = computeScoreSummaryForGame(scores, game.practiceKey) ?: return@count true
        val median = summary.median
        if (median <= 0) true else ((summary.targetHigh - summary.targetFloor) / median) >= 0.6
    }

    return GroupDashboardScore(
        completionAverage = completionAverage,
        staleGameCount = staleCount,
        weakerGameCount = weakerCount,
        recommendedSlug = computeRecommendedGame(group, games, scores, scopedJournal, rulesheetProgress)?.practiceKey,
    )
}

internal fun computeRecommendedGame(
    group: PracticeGroup,
    games: List<PinballGame>,
    scores: List<ScoreEntry>,
    journal: List<JournalEntry>,
    rulesheetProgress: Map<String, Float>,
): PinballGame? {
    val groupSet = group.gameSlugs.toSet()
    return distinctGamesByPracticeIdentity(games).filter { groupSet.contains(it.practiceKey) }
        .maxByOrNull { game ->
            focusPriorityForGame(game.practiceKey, scores, journal, rulesheetProgress)
        }
}

private fun filterJournalByDateWindow(
    journal: List<JournalEntry>,
    startDateMs: Long?,
    endDateMs: Long?,
): List<JournalEntry> {
    val endBoundary = endDateMs?.let(::endOfDayMs)
    return journal.filter { entry ->
        val ts = entry.timestampMs
        (startDateMs == null || ts >= startDateMs) && (endBoundary == null || ts <= endBoundary)
    }
}

private fun endOfDayMs(inputMs: Long): Long {
    val cal = Calendar.getInstance().apply { timeInMillis = inputMs }
    cal.set(Calendar.HOUR_OF_DAY, 23)
    cal.set(Calendar.MINUTE, 59)
    cal.set(Calendar.SECOND, 59)
    cal.set(Calendar.MILLISECOND, 999)
    return cal.timeInMillis
}

private fun latestStudyPercentFromJournal(journal: List<JournalEntry>, gameSlug: String, category: String): Int {
    val latest = journal
        .asReversed()
        .firstOrNull { it.gameSlug == gameSlug && it.action == "study" && it.summary.contains(category, ignoreCase = true) }
        ?.summary
        ?: return 0
    val withPercent = Regex("""(\d{1,3})\s*%""").find(latest)?.groupValues?.getOrNull(1)?.toIntOrNull()
    if (withPercent != null) return withPercent.coerceIn(0, 100)

    val afterColon = latest.substringAfter(':', missingDelimiterValue = "").trim()
    if (afterColon.matches(Regex("""\d{1,3}"""))) {
        return afterColon.toInt().coerceIn(0, 100)
    }

    return 0
}

private fun studyCompletionPercentForGame(
    journal: List<JournalEntry>,
    rulesheetProgress: Map<String, Float>,
    gameSlug: String,
): Int {
    val progress = computeTaskProgressForGame(journal, rulesheetProgress, gameSlug).values
    return if (progress.isEmpty()) 0 else progress.average().roundToInt()
}

private fun latestPracticeTimestampForGame(journal: List<JournalEntry>, gameSlug: String): Long? {
    return journal.filter { it.gameSlug == gameSlug && it.action == "practice" }
        .maxOfOrNull { it.timestampMs }
}

private fun focusPriorityForGame(
    gameSlug: String,
    scores: List<ScoreEntry>,
    journal: List<JournalEntry>,
    rulesheetProgress: Map<String, Float>,
): Double {
    val summary = computeScoreSummaryForGame(scores, gameSlug)
    val varianceWeight = if (summary == null || summary.median <= 0) {
        1.0
    } else {
        ((summary.targetHigh - summary.targetFloor) / summary.median).coerceAtMost(1.0)
    }

    val now = System.currentTimeMillis()
    val practiceGapDays = latestPracticeTimestampForGame(journal, gameSlug)
        ?.let { ((now - it) / (1000L * 60L * 60L * 24L)).toDouble() }
        ?: 30.0
    val completionGap = 1.0 - (studyCompletionPercentForGame(journal, rulesheetProgress, gameSlug) / 100.0)
    return (varianceWeight * 0.45) + ((practiceGapDays.coerceAtMost(30.0) / 30.0) * 0.4) + (completionGap * 0.15)
}
