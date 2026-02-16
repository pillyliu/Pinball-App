package com.pillyliu.pinballandroid.practice

internal data class PracticeGroup(
    val id: String,
    val name: String,
    val gameSlugs: List<String>,
    val type: String,
    val isActive: Boolean,
    val isPriority: Boolean,
    val startDateMs: Long?,
    val endDateMs: Long?,
)

internal data class ScoreEntry(
    val id: String,
    val gameSlug: String,
    val score: Double,
    val context: String,
    val timestampMs: Long,
    val leagueImported: Boolean,
)

internal data class NoteEntry(
    val id: String,
    val gameSlug: String,
    val category: String,
    val detail: String?,
    val note: String,
    val timestampMs: Long,
)

internal data class JournalEntry(
    val id: String,
    val gameSlug: String,
    val action: String,
    val summary: String,
    val timestampMs: Long,
)

internal data class LeagueTargetScores(
    val great: Double,
    val main: Double,
    val floor: Double,
)

internal data class HeadToHeadGameStats(
    val gameSlug: String,
    val gameName: String,
    val yourCount: Int,
    val opponentCount: Int,
    val yourMean: Double,
    val opponentMean: Double,
    val yourHigh: Double,
    val opponentHigh: Double,
    val yourLow: Double,
    val opponentLow: Double,
) {
    val meanDelta: Double get() = yourMean - opponentMean
}

internal data class HeadToHeadComparison(
    val yourPlayerName: String,
    val opponentPlayerName: String,
    val totalGamesCompared: Int,
    val gamesYouLeadByMean: Int,
    val gamesOpponentLeadsByMean: Int,
    val averageMeanDelta: Double,
    val games: List<HeadToHeadGameStats>,
)

internal data class GroupDashboardScore(
    val completionAverage: Int,
    val staleGameCount: Int,
    val weakerGameCount: Int,
    val recommendedSlug: String?,
)

internal data class MechanicsSkillSummary(
    val totalLogs: Int,
    val latestComfort: Int?,
    val averageComfort: Double?,
    val trendDelta: Double?,
)

internal data class ScoreSummary(
    val high: Double,
    val low: Double,
    val mean: Double,
    val median: Double,
    val stdev: Double,
    val p25: Double,
    val targetHigh: Double,
    val targetMain: Double,
    val targetFloor: Double,
)
