package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.PinballGame

internal class PracticeDerivedQueryIntegration {
    private var cachedScoresRef: List<ScoreEntry>? = null
    private var cachedJournalRef: List<JournalEntry>? = null
    private var cachedScoreEntriesByGame: Map<String, List<ScoreEntry>> = emptyMap()
    private var cachedJournalEntriesByGame: Map<String, List<JournalEntry>> = emptyMap()
    private val cachedScoreSummariesByGame = mutableMapOf<String, ScoreSummary?>()

    fun scoreValues(
        scores: List<ScoreEntry>,
        canonicalGameID: String,
    ): List<Double> = cachedScoreEntries(scores, canonicalGameID).map { it.score }

    fun scoreTrendValues(
        scores: List<ScoreEntry>,
        canonicalGameID: String,
        limit: Int,
    ): List<Double> = cachedScoreEntries(scores, canonicalGameID)
        .sortedBy { it.timestampMs }
        .takeLast(limit)
        .map { it.score }

    fun scoreSummary(
        scores: List<ScoreEntry>,
        canonicalGameID: String,
    ): ScoreSummary? {
        ensureScoreCaches(scores)
        if (cachedScoreSummariesByGame.containsKey(canonicalGameID)) {
            return cachedScoreSummariesByGame[canonicalGameID]
        }

        val summary = computeScoreSummaryForGame(cachedScoreEntries(scores, canonicalGameID), canonicalGameID)
        cachedScoreSummariesByGame[canonicalGameID] = summary
        return summary
    }

    fun journalEntriesForGame(
        journal: List<JournalEntry>,
        canonicalGameID: String,
    ): List<JournalEntry> {
        ensureJournalCaches(journal)
        return cachedJournalEntriesByGame[canonicalGameID].orEmpty()
    }

    fun groupDashboardScore(
        group: PracticeGroup,
        games: List<PinballGame>,
        scores: List<ScoreEntry>,
        journal: List<JournalEntry>,
        rulesheetProgress: Map<String, Float>,
    ): GroupDashboardScore = computeGroupDashboardScore(group, games, scores, journal, rulesheetProgress)

    fun recommendedGame(
        group: PracticeGroup,
        games: List<PinballGame>,
        scores: List<ScoreEntry>,
        journal: List<JournalEntry>,
        rulesheetProgress: Map<String, Float>,
    ): PinballGame? = computeRecommendedGame(group, games, scores, journal, rulesheetProgress)

    fun taskProgress(
        journal: List<JournalEntry>,
        rulesheetProgress: Map<String, Float>,
        canonicalGameID: String,
        group: PracticeGroup?,
    ): Map<String, Int> = computeTaskProgressForGame(
        journal = journal,
        rulesheetProgress = rulesheetProgress,
        gameSlug = canonicalGameID,
        startDateMs = group?.startDateMs,
        endDateMs = group?.endDateMs,
    )

    fun mechanicsSkills(): List<String> = defaultMechanicsSkills()

    fun detectedMechanicsTags(
        text: String,
        skills: List<String>,
    ): List<String> = detectMechanicsTags(text, skills)

    fun trackedMechanicsSkills(
        notes: List<NoteEntry>,
        skills: List<String>,
    ): List<String> = com.pillyliu.pinprofandroid.practice.trackedMechanicsSkills(notes, skills)

    fun mechanicsSummary(
        skill: String,
        notes: List<NoteEntry>,
        skills: List<String>,
    ): MechanicsSkillSummary = mechanicsSummaryForSkill(skill, notes, skills)

    fun mechanicsLogs(
        skill: String,
        notes: List<NoteEntry>,
        skills: List<String>,
    ): List<NoteEntry> = mechanicsLogsForSkill(skill, notes, skills)

    fun activeGroups(groups: List<PracticeGroup>): List<PracticeGroup> =
        activeGroupsFromList(groups)

    fun activeGroupForGame(
        groups: List<PracticeGroup>,
        canonicalGameID: String,
        lookupGames: List<PinballGame>,
    ): PracticeGroup? = com.pillyliu.pinprofandroid.practice.activeGroupForGame(groups, canonicalGameID, lookupGames)

    fun groupGames(
        group: PracticeGroup,
        visibleGames: List<PinballGame>,
        lookupGames: List<PinballGame>,
    ): List<PinballGame> {
        return group.gameSlugs.mapNotNull { key ->
            findGameByPracticeLookupKey(visibleGames, key) ?: findGameByPracticeLookupKey(lookupGames, key)
        }
    }

    fun gameName(
        lookupGames: List<PinballGame>,
        canonicalGameID: String,
    ): String = practiceDisplayTitleForKey(canonicalGameID, lookupGames)
        ?: gameNameForSlug(lookupGames, canonicalGameID)

    private fun ensureScoreCaches(scores: List<ScoreEntry>) {
        if (cachedScoresRef === scores) return
        cachedScoresRef = scores
        cachedScoreEntriesByGame = scores
            .groupBy { it.gameSlug }
            .mapValues { (_, entries) -> entries.sortedByDescending { it.timestampMs } }
        cachedScoreSummariesByGame.clear()
    }

    private fun ensureJournalCaches(journal: List<JournalEntry>) {
        if (cachedJournalRef === journal) return
        cachedJournalRef = journal
        cachedJournalEntriesByGame = journal
            .groupBy { it.gameSlug }
            .mapValues { (_, entries) -> entries.sortedByDescending { it.timestampMs } }
    }

    private fun cachedScoreEntries(
        scores: List<ScoreEntry>,
        canonicalGameID: String,
    ): List<ScoreEntry> {
        ensureScoreCaches(scores)
        return cachedScoreEntriesByGame[canonicalGameID].orEmpty()
    }
}
