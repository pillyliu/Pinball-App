package com.pillyliu.pinprofandroid.practice

internal fun updatedPracticeCanonicalStateForLeaguePlayer(
    canonicalState: CanonicalPracticePersistedState,
    playerName: String,
): CanonicalPracticePersistedState {
    return canonicalState.copy(
        leagueSettings = canonicalState.leagueSettings.copy(
            playerName = playerName,
            csvAutoFillEnabled = true,
        ),
    )
}

internal fun updatedPracticeCanonicalStateAfterLeagueImport(
    canonicalState: CanonicalPracticePersistedState,
    selectedPlayer: String,
    importedAtMs: Long,
): CanonicalPracticePersistedState {
    return canonicalState.copy(
        leagueSettings = canonicalState.leagueSettings.copy(
            playerName = selectedPlayer,
            csvAutoFillEnabled = true,
            lastImportAtMs = importedAtMs,
            lastRepairVersion = PracticeLeagueIntegration.LEAGUE_SCORE_REPAIR_VERSION,
        ),
    )
}

internal fun shouldPracticeAutoImportLeagueScores(
    leaguePlayerName: String,
    practiceLookupGameCount: Int,
    isAutoImportingLeagueScores: Boolean,
    nowMs: Long,
    lastLeagueAutoImportAttemptMs: Long,
    hasRemoteUpdate: Boolean,
    statsUpdatedAtMs: Long?,
    leagueSettings: CanonicalLeagueSettings,
): Boolean {
    if (leaguePlayerName.isBlank() || practiceLookupGameCount == 0) return false
    if (isAutoImportingLeagueScores || (nowMs - lastLeagueAutoImportAttemptMs) < 60_000L) return false

    val csvIsNewerThanLastImport = leagueSettings.lastImportAtMs?.let { lastImportAtMs ->
        statsUpdatedAtMs?.let { it > lastImportAtMs }
    } == true
    val needsRepairPass =
        leagueSettings.lastRepairVersion != PracticeLeagueIntegration.LEAGUE_SCORE_REPAIR_VERSION

    return leagueSettings.lastImportAtMs == null ||
        hasRemoteUpdate ||
        csvIsNewerThanLastImport ||
        needsRepairPass
}

internal data class PracticePurgedImportedLeagueState(
    val canonicalState: CanonicalPracticePersistedState,
    val removedCount: Int,
)

internal fun purgedImportedLeagueState(
    canonicalState: CanonicalPracticePersistedState,
): PracticePurgedImportedLeagueState {
    val removedCount = canonicalState.scoreEntries.count { it.leagueImported }
    return PracticePurgedImportedLeagueState(
        canonicalState = canonicalState.copy(
            scoreEntries = canonicalState.scoreEntries.filterNot { it.leagueImported },
            journalEntries = canonicalState.journalEntries.filterNot { entry ->
                if (entry.action != "scoreLogged") {
                    false
                } else {
                    entry.scoreContext == "league" ||
                        (entry.note?.contains("Imported from LPL stats CSV", ignoreCase = true) == true)
                }
            },
            leagueSettings = canonicalState.leagueSettings.copy(
                csvAutoFillEnabled = true,
                lastImportAtMs = null,
                lastRepairVersion = null,
            ),
        ),
        removedCount = removedCount,
    )
}
