package com.pillyliu.pinballandroid.practice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class PracticeCanonicalPersistenceTest {

    @Test
    fun legacyState_migratesToCanonicalIosSchema_andParsesBack() {
        val legacy = PracticePersistedState(
            playerName = "Pat",
            comparisonPlayerName = "Sam",
            leaguePlayerName = "League Pat",
            cloudSyncEnabled = true,
            selectedGroupID = "group-legacy",
            groups = listOf(
                PracticeGroup(
                    id = "group-legacy",
                    name = "League Set",
                    gameSlugs = listOf("Gd2Xb"),
                    type = "custom",
                    isActive = true,
                    isArchived = false,
                    isPriority = true,
                    startDateMs = 1_700_000_000_000,
                    endDateMs = null,
                ),
            ),
            scores = listOf(
                ScoreEntry(
                    id = "score-1",
                    gameSlug = "Gd2Xb",
                    score = 123456.0,
                    context = "practice",
                    timestampMs = 1_700_000_000_100,
                    leagueImported = false,
                ),
            ),
            notes = listOf(
                NoteEntry(
                    id = "note-1",
                    gameSlug = "Gd2Xb",
                    category = "mechanics",
                    detail = "Left ramp",
                    note = "Late flip",
                    timestampMs = 1_700_000_000_200,
                ),
            ),
            journal = listOf(
                JournalEntry(
                    id = "journal-1",
                    gameSlug = "Gd2Xb",
                    action = "study",
                    summary = "Tutorial progress on TMNT: 01:23: clip note",
                    timestampMs = 1_700_000_000_050,
                ),
                JournalEntry(
                    id = "journal-2",
                    gameSlug = "Gd2Xb",
                    action = "score",
                    summary = "Logged 123,456 on TMNT (Practice)",
                    timestampMs = 1_700_000_000_100,
                ),
                JournalEntry(
                    id = "journal-3",
                    gameSlug = "Gd2Xb",
                    action = "mechanics",
                    summary = "Mechanics note for TMNT (Left ramp): Late flip",
                    timestampMs = 1_700_000_000_200,
                ),
            ),
            rulesheetProgress = mapOf("Gd2Xb" to 0.42f),
            gameSummaryNotes = mapOf("Gd2Xb" to "Practice multiball starts"),
        )

        val canonical = canonicalPracticeStateFromLegacyState(legacy)
        assertEquals(CANONICAL_PRACTICE_SCHEMA_VERSION, canonical.schemaVersion)
        assertEquals("Pat", canonical.practiceSettings.playerName)
        assertEquals("League Pat", canonical.leagueSettings.playerName)
        assertEquals(1, canonical.scoreEntries.size)
        assertEquals(1, canonical.noteEntries.size)
        assertTrue(canonical.journalEntries.any { it.action == "tutorialWatch" && it.videoKind == "clock" })
        assertTrue(canonical.journalEntries.any { it.action == "scoreLogged" && it.score == 123456.0 })
        assertTrue(canonical.journalEntries.any { it.action == "noteAdded" && it.noteCategory == "mechanics" })
        assertEquals(0.42, canonical.rulesheetResumeOffsets["Gd2Xb"] ?: 0.0, 0.0001)

        canonical.customGroups.forEach { UUID.fromString(it.id) }
        canonical.scoreEntries.forEach { UUID.fromString(it.id) }
        canonical.noteEntries.forEach { UUID.fromString(it.id) }
        canonical.journalEntries.forEach { UUID.fromString(it.id) }

        val json = buildCanonicalPracticeStateJson(canonical)
        val reparsed = parsePracticeStatePayloadJson(json) { key -> if (key == "Gd2Xb") "Teenage Mutant Ninja Turtles" else key }
        assertNotNull(reparsed)
        reparsed!!
        assertEquals(CANONICAL_PRACTICE_SCHEMA_VERSION, reparsed.canonical.schemaVersion)
        assertTrue(reparsed.runtime.journal.any { it.action == "score" })
        assertTrue(reparsed.runtime.journal.any { it.action == "mechanics" })
        assertEquals("Pat", reparsed.runtime.playerName)
    }

    @Test
    fun canonicalJson_parsesIosMillisecondTimestamps_andOldReferenceDateNumbers() {
        val canonicalJson = """
            {
              "schemaVersion": 4,
              "studyEvents": [
                {"id":"${UUID.randomUUID()}","gameID":"Gd2Xb","task":"rulesheet","progressPercent":60,"timestamp":1700000000123}
              ],
              "videoProgressEntries": [],
              "scoreEntries": [
                {"id":"${UUID.randomUUID()}","gameID":"Gd2Xb","score":1000,"context":"tournament","tournamentName":"Expo","timestamp":1700000001000,"leagueImported":false}
              ],
              "noteEntries": [],
              "journalEntries": [
                {"id":"${UUID.randomUUID()}","gameID":"Gd2Xb","action":"scoreLogged","score":1000,"scoreContext":"tournament","tournamentName":"Expo","timestamp":1700000001000},
                {"id":"${UUID.randomUUID()}","gameID":"Gd2Xb","action":"gameBrowse","timestamp":788000000.0}
              ],
              "customGroups": [],
              "leagueSettings": {"playerName":"L", "csvAutoFillEnabled": true, "lastImportAt": 1700000002000},
              "syncSettings": {"cloudSyncEnabled": true, "endpoint":"pillyliu.com", "phaseLabel":"Phase 2: Optional cloud sync"},
              "analyticsSettings": {"gapMode":"compressInactive", "useMedian": true},
              "rulesheetResumeOffsets": {"Gd2Xb": 0.75},
              "videoResumeHints": {"Gd2Xb":"12:34"},
              "gameSummaryNotes": {"Gd2Xb":"hello"},
              "practiceSettings": {"playerName":"P","comparisonPlayerName":"C","selectedGroupID":"${UUID.randomUUID()}"}
            }
        """.trimIndent()

        val payload = parsePracticeStatePayloadJson(canonicalJson) { "TMNT" }
        assertNotNull(payload)
        payload!!
        assertEquals("P", payload.runtime.playerName)
        assertEquals("C", payload.runtime.comparisonPlayerName)
        assertEquals("L", payload.runtime.leaguePlayerName)
        assertTrue(payload.runtime.cloudSyncEnabled)
        assertEquals(1, payload.runtime.scores.size)
        assertEquals("tournament:Expo", payload.runtime.scores.first().context)
        assertEquals(0.6f, payload.runtime.rulesheetProgress["Gd2Xb"] ?: 0f, 0.0001f)
        assertEquals(0.75, payload.canonical.rulesheetResumeOffsets["Gd2Xb"] ?: 0.0, 0.0001)
        assertEquals("12:34", payload.canonical.videoResumeHints["Gd2Xb"])
        assertTrue(payload.canonical.journalEntries.any { it.action == "gameBrowse" && it.timestampMs > 1_600_000_000_000L })
        assertFalse(payload.runtime.journal.isEmpty())
    }
}

