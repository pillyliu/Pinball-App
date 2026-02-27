package com.pillyliu.pinballandroid.practice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.InputStreamReader
import java.util.UUID

class PracticeCanonicalPersistenceTest {

    @Test
    fun legacyFixture_migratesToCanonicalSchema_andParsesBack() {
        val legacyRaw = fixtureText("practice/legacy_state_v1.json")
        val legacy = parsePracticeStateJson(legacyRaw)
        assertNotNull(legacy)
        legacy!!

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
    fun canonicalFixture_parsesMillisAndReferenceDateNumbers() {
        val canonicalJson = fixtureText("practice/canonical_state_v4.json")

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

    private fun fixtureText(path: String): String {
        val stream = javaClass.classLoader?.getResourceAsStream(path)
        requireNotNull(stream) { "Missing fixture: $path" }
        return InputStreamReader(stream).use { it.readText() }
    }
}
