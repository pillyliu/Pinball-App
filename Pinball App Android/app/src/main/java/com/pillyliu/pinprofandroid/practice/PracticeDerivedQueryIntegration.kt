package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.PinballGame

internal class PracticeDerivedQueryIntegration {
    fun scoreValues(
        scores: List<ScoreEntry>,
        canonicalGameID: String,
    ): List<Double> = scoreValuesForGame(scores, canonicalGameID)

    fun scoreTrendValues(
        scores: List<ScoreEntry>,
        canonicalGameID: String,
        limit: Int,
    ): List<Double> = scoreTrendValuesForGame(scores, canonicalGameID, limit)

    fun scoreSummary(
        scores: List<ScoreEntry>,
        canonicalGameID: String,
    ): ScoreSummary? = computeScoreSummaryForGame(scores, canonicalGameID)

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
}
