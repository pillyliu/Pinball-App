package com.pillyliu.pinprofandroid.practice

import java.time.Instant
import java.time.ZoneId

private data class ImportedLeagueScoreSignature(
    val gameID: String,
    val score: Double,
    val timestampMs: Long,
)

internal fun normalizeImportedLeagueTimestamps(
    loaded: LoadedPracticeStatePayload,
    gameNameForKey: (String) -> String,
    zoneId: ZoneId = ZoneId.systemDefault(),
): LoadedPracticeStatePayload {
    val normalizedCanonical = normalizeImportedLeagueTimestamps(loaded.payload.canonical, zoneId)
    if (normalizedCanonical == loaded.payload.canonical) {
        return loaded
    }

    return LoadedPracticeStatePayload(
        payload = ParsedPracticeStatePayload(
            runtime = runtimePracticeStateFromCanonicalState(normalizedCanonical, gameNameForKey),
            canonical = normalizedCanonical,
        ),
        requiresCanonicalSave = true,
    )
}

internal fun normalizeImportedLeagueTimestamps(
    state: CanonicalPracticePersistedState,
    zoneId: ZoneId = ZoneId.systemDefault(),
): CanonicalPracticePersistedState {
    val timestampUpdates = linkedMapOf<ImportedLeagueScoreSignature, MutableList<Long>>()
    var didChange = false

    val normalizedScores = state.scoreEntries.map { entry ->
        if (!entry.leagueImported) return@map entry

        val normalizedTimestamp = normalizeSyntheticLeagueTimestampMs(entry.timestampMs, zoneId)
        timestampUpdates
            .getOrPut(
                ImportedLeagueScoreSignature(
                    gameID = entry.gameID,
                    score = entry.score,
                    timestampMs = entry.timestampMs,
                )
            ) { mutableListOf() }
            .add(normalizedTimestamp)

        if (normalizedTimestamp != entry.timestampMs) {
            didChange = true
            entry.copy(timestampMs = normalizedTimestamp)
        } else {
            entry
        }
    }

    val normalizedJournal = state.journalEntries.map { entry ->
        if (entry.action != "scoreLogged" || entry.scoreContext != "league" || entry.score == null) {
            return@map entry
        }

        val normalizedTimestamp = timestampUpdates[
            ImportedLeagueScoreSignature(
                gameID = entry.gameID,
                score = entry.score,
                timestampMs = entry.timestampMs,
            )
        ]?.let { matches ->
            if (matches.isEmpty()) {
                null
            } else {
                matches.removeAt(0)
            }
        } ?: return@map entry

        if (normalizedTimestamp != entry.timestampMs) {
            didChange = true
            entry.copy(timestampMs = normalizedTimestamp)
        } else {
            entry
        }
    }

    return if (didChange) {
        state.copy(
            scoreEntries = normalizedScores,
            journalEntries = normalizedJournal,
        )
    } else {
        state
    }
}

internal fun normalizeSyntheticLeagueTimestampMs(
    timestampMs: Long,
    zoneId: ZoneId = ZoneId.systemDefault(),
): Long {
    if (timestampMs <= 0L) return timestampMs
    val localDate = Instant.ofEpochMilli(timestampMs).atZone(zoneId).toLocalDate()
    return leagueEventTimestampMsForDate(localDate, zoneId)
}
