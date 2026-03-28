package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.LibrarySourceType
import com.pillyliu.pinprofandroid.library.PinballGame
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.util.TimeZone

class PracticeLeagueImportTest {
    @Test
    fun importLeagueScoresFromRows_skipsExistingLeagueDuplicates() = runBlocking {
        val captured = mutableListOf<Triple<String, Double, Long>>()
        val repaired = mutableListOf<String>()
        val eventDateMs = LocalDate.of(2025, 3, 19)
            .atTime(22, 0)
            .atZone(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()
        val existingScores = listOf(
            ScoreEntry(
                id = "existing",
                gameSlug = "G-test",
                score = 12_345_678.0,
                context = "league",
                timestampMs = eventDateMs,
                leagueImported = true,
            ),
        )

        val result = importLeagueScoresFromRows(
            selectedPlayer = "Jane Doe",
            rows = listOf(
                LeagueCsvRow(
                    player = "Jane Doe",
                    machine = "Foo Fighters",
                    rawScore = 12_345_678.0,
                    eventDateMs = eventDateMs,
                    practiceIdentity = null,
                    opdbId = null,
                ),
                LeagueCsvRow(
                    player = "Jane Doe",
                    machine = "Foo Fighters",
                    rawScore = 22_222_222.0,
                    eventDateMs = eventDateMs,
                    practiceIdentity = null,
                    opdbId = null,
                ),
            ),
            games = listOf(game(name = "Foo Fighters", slug = "foo-fighters")),
            existingScores = existingScores,
            machineMappings = emptyMap(),
            onAddScore = { slug, score, timestampMs ->
                captured += Triple(slug, score, timestampMs)
            },
            onRepairScore = { existingId, _, _, _ ->
                repaired += existingId
            },
        )

        assertEquals(1, result.imported)
        assertEquals(0, result.repaired)
        assertEquals(1, result.duplicatesSkipped)
        assertEquals(0, result.unmatchedRows)
        assertEquals(1, captured.size)
        assertEquals(emptyList<String>(), repaired)
        assertEquals(Triple("G-test", 22_222_222.0, eventDateMs), captured.single())
    }

    @Test
    fun importLeagueScoresFromRows_rejectsLoosePartialMachineMatches() = runBlocking {
        val captured = mutableListOf<Triple<String, Double, Long>>()
        val eventDateMs = LocalDate.of(2025, 3, 19)
            .atTime(22, 0)
            .atZone(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()

        val result = importLeagueScoresFromRows(
            selectedPlayer = "Jane Doe",
            rows = listOf(
                LeagueCsvRow(
                    player = "Jane Doe",
                    machine = "Foo",
                    rawScore = 12_345_678.0,
                    eventDateMs = eventDateMs,
                    practiceIdentity = null,
                    opdbId = null,
                ),
            ),
            games = listOf(game(name = "Foo Fighters", slug = "foo-fighters")),
            existingScores = emptyList(),
            machineMappings = emptyMap(),
            onAddScore = { slug, score, timestampMs ->
                captured += Triple(slug, score, timestampMs)
            },
            onRepairScore = { _, _, _, _ -> },
        )

        assertEquals(0, result.imported)
        assertEquals(0, result.repaired)
        assertEquals(0, result.duplicatesSkipped)
        assertEquals(1, result.unmatchedRows)
        assertEquals(emptyList<Triple<String, Double, Long>>(), captured)
    }

    @Test
    fun importLeagueScoresFromRows_keepsUnmatchedSummaryGeneric() = runBlocking {
        val result = importLeagueScoresFromRows(
            selectedPlayer = "Jane Doe",
            rows = listOf(
                LeagueCsvRow(
                    player = "Jane Doe",
                    machine = "Foo",
                    rawScore = 12_345_678.0,
                    eventDateMs = null,
                    practiceIdentity = null,
                    opdbId = null,
                ),
                LeagueCsvRow(
                    player = "Jane Doe",
                    machine = "Foo",
                    rawScore = 23_456_789.0,
                    eventDateMs = null,
                    practiceIdentity = null,
                    opdbId = null,
                ),
                LeagueCsvRow(
                    player = "Jane Doe",
                    machine = "Bar",
                    rawScore = 34_567_890.0,
                    eventDateMs = null,
                    practiceIdentity = null,
                    opdbId = null,
                ),
            ),
            games = emptyList(),
            existingScores = emptyList(),
            machineMappings = emptyMap(),
            onAddScore = { _, _, _ -> },
            onRepairScore = { _, _, _, _ -> },
        )

        assertTrue(result.summaryLine.contains("3 unmatched."))
        assertTrue(!result.summaryLine.contains("Foo"))
        assertTrue(!result.summaryLine.contains("Bar"))
    }

    @Test
    fun importLeagueScoresFromRows_allowsKnownAliasMatches() = runBlocking {
        val captured = mutableListOf<Triple<String, Double, Long>>()
        val eventDateMs = LocalDate.of(2025, 3, 19)
            .atTime(22, 0)
            .atZone(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()

        val result = importLeagueScoresFromRows(
            selectedPlayer = "Jane Doe",
            rows = listOf(
                LeagueCsvRow(
                    player = "Jane Doe",
                    machine = "Jurassic Park",
                    rawScore = 12_345_678.0,
                    eventDateMs = eventDateMs,
                    practiceIdentity = null,
                    opdbId = null,
                ),
            ),
            games = listOf(game(name = "Jurassic Park Stern 2019", slug = "jurassic-park-stern-2019")),
            existingScores = emptyList(),
            machineMappings = emptyMap(),
            onAddScore = { slug, score, timestampMs ->
                captured += Triple(slug, score, timestampMs)
            },
            onRepairScore = { _, _, _, _ -> },
        )

        assertEquals(1, result.imported)
        assertEquals(0, result.repaired)
        assertEquals(0, result.duplicatesSkipped)
        assertEquals(0, result.unmatchedRows)
        assertEquals(
            listOf(Triple("G-test", 12_345_678.0, eventDateMs)),
            captured,
        )
    }

    @Test
    fun importLeagueScoresFromRows_matchesExactOpdbIdLikeIos() = runBlocking {
        val captured = mutableListOf<Triple<String, Double, Long>>()
        val eventDateMs = LocalDate.of(2025, 3, 19)
            .atTime(22, 0)
            .atZone(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()

        val result = importLeagueScoresFromRows(
            selectedPlayer = "Jane Doe",
            rows = listOf(
                LeagueCsvRow(
                    player = "Jane Doe",
                    machine = "Wonka League",
                    rawScore = 12_345_678.0,
                    eventDateMs = eventDateMs,
                    practiceIdentity = null,
                    opdbId = "GYWBZ-MW9B0",
                ),
            ),
            games = listOf(
                game(
                    name = "Willy Wonka & The Chocolate Factory (LE)",
                    slug = "willy-wonka-and-the-chocolate-factory-le",
                    practiceIdentity = null,
                    opdbId = "GYWBZ-MW9B0",
                ),
            ),
            existingScores = emptyList(),
            machineMappings = emptyMap(),
            onAddScore = { slug, score, timestampMs ->
                captured += Triple(slug, score, timestampMs)
            },
            onRepairScore = { _, _, _, _ -> },
        )

        assertEquals(1, result.imported)
        assertEquals(0, result.repaired)
        assertEquals(0, result.duplicatesSkipped)
        assertEquals(0, result.unmatchedRows)
        assertEquals(
            listOf(Triple("GYWBZ-MW9B0", 12_345_678.0, eventDateMs)),
            captured,
        )
    }

    @Test
    fun importLeagueScoresFromRows_repairsWrongImportedLeagueMatchBySameScoreAndDay() = runBlocking {
        val repaired = mutableListOf<List<String>>()
        val eventDateMs = LocalDate.of(2025, 3, 19)
            .atTime(22, 0)
            .atZone(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()

        val result = importLeagueScoresFromRows(
            selectedPlayer = "Jane Doe",
            rows = listOf(
                LeagueCsvRow(
                    player = "Jane Doe",
                    machine = "Scared Stiff",
                    rawScore = 66_666_666.0,
                    eventDateMs = eventDateMs,
                    practiceIdentity = null,
                    opdbId = null,
                ),
            ),
            games = listOf(
                game(name = "Scared Stiff", slug = "scared-stiff", practiceIdentity = "G-scared"),
                game(name = "Sharkey's Shootout", slug = "sharkeys-shootout", practiceIdentity = "G-sharkey"),
            ),
            existingScores = listOf(
                ScoreEntry(
                    id = "wrong-score",
                    gameSlug = "G-sharkey",
                    score = 66_666_666.0,
                    context = "league",
                    timestampMs = eventDateMs,
                    leagueImported = true,
                ),
            ),
            machineMappings = mapOf(
                normalizeMachine("Scared Stiff") to LeagueMachineMappingRecord(
                    machine = "Scared Stiff",
                    practiceIdentity = "G-scared",
                    opdbId = "G4xbP-Mp45Y",
                )
            ),
            onAddScore = { _, _, _ -> },
            onRepairScore = { existingId, score, slug, timestampMs ->
                repaired += listOf(existingId, score.toString(), slug, timestampMs.toString())
            },
        )

        assertEquals(0, result.imported)
        assertEquals(1, result.repaired)
        assertEquals(0, result.duplicatesSkipped)
        assertEquals(0, result.unmatchedRows)
        assertEquals(listOf(listOf("wrong-score", "6.6666666E7", "G-scared", eventDateMs.toString())), repaired)
    }

    @Test
    fun normalizeImportedLeagueTimestamps_repairsShiftedImportedRows() {
        val originalZone = TimeZone.getDefault()
        val zoneId = ZoneId.of("America/Detroit")
        TimeZone.setDefault(TimeZone.getTimeZone(zoneId))
        try {
            val shiftedTimestamp = LocalDate.of(2025, 3, 8)
                .atTime(1, 0)
                .atZone(zoneId)
                .toInstant()
                .toEpochMilli()
            val normalizedTimestamp = LocalDate.of(2025, 3, 8)
                .atTime(22, 0)
                .atZone(zoneId)
                .toInstant()
                .toEpochMilli()

            val state = emptyCanonicalPracticePersistedState().copy(
                scoreEntries = listOf(
                    CanonicalScoreLogEntry(
                        id = "score-1",
                        gameID = "foo-fighters",
                        score = 12_345_678.0,
                        context = "league",
                        tournamentName = null,
                        timestampMs = shiftedTimestamp,
                        leagueImported = true,
                    )
                ),
                journalEntries = listOf(
                    CanonicalJournalEntry(
                        id = "journal-1",
                        gameID = "foo-fighters",
                        action = "scoreLogged",
                        task = null,
                        progressPercent = null,
                        videoKind = null,
                        videoValue = null,
                        score = 12_345_678.0,
                        scoreContext = "league",
                        tournamentName = null,
                        noteCategory = null,
                        noteDetail = null,
                        note = null,
                        timestampMs = shiftedTimestamp,
                    )
                ),
            )

            val normalized = normalizeImportedLeagueTimestamps(state, zoneId)

            assertEquals(normalizedTimestamp, normalized.scoreEntries.single().timestampMs)
            assertEquals(normalizedTimestamp, normalized.journalEntries.single().timestampMs)
        } finally {
            TimeZone.setDefault(originalZone)
        }
    }

    private fun game(
        name: String,
        slug: String,
        practiceIdentity: String? = "G-test",
        opdbId: String? = null,
    ): PinballGame {
        return PinballGame(
            libraryEntryId = null,
            practiceIdentity = practiceIdentity,
            opdbId = opdbId,
            variant = null,
            sourceId = "venue--test",
            sourceName = "Test Venue",
            sourceType = LibrarySourceType.VENUE,
            area = null,
            areaOrder = null,
            group = null,
            position = null,
            bank = null,
            name = name,
            manufacturer = null,
            year = 2024,
            slug = slug,
            primaryImageUrl = null,
            primaryImageLargeUrl = null,
            playfieldImageUrl = null,
            alternatePlayfieldImageUrl = null,
            playfieldLocalOriginal = null,
            playfieldLocal = null,
            playfieldSourceLabel = null,
            gameinfoLocal = null,
            rulesheetLocal = null,
            rulesheetUrl = null,
            rulesheetLinks = emptyList(),
            videos = emptyList(),
        )
    }
}
