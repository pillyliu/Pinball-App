package com.pillyliu.pinprofandroid.league

import org.junit.Assert.assertEquals
import org.junit.Test

class LeaguePreviewParsingTest {
    @Test
    fun buildStandingsPreviewUsesSixAroundRowsWhenSelectedPlayerIsOutsideTopFive() {
        val payload = buildStandingsPreview(
            rows = standingsRows,
            selectedPlayer = "Player 8",
        )

        assertEquals(5, payload.topRows.size)
        assertEquals(6, payload.aroundRows.size)
        assertEquals(8, payload.currentPlayerStanding?.rank)
        assertEquals(listOf(5, 6, 7, 8, 9, 10), payload.aroundRows.map { it.rank })
    }

    @Test
    fun buildStandingsPreviewKeepsFiveAroundRowsWhenSelectedPlayerIsInsideTopFive() {
        val payload = buildStandingsPreview(
            rows = standingsRows,
            selectedPlayer = "Player 3",
        )

        assertEquals(5, payload.topRows.size)
        assertEquals(5, payload.aroundRows.size)
        assertEquals(3, payload.currentPlayerStanding?.rank)
        assertEquals(listOf(1, 2, 3, 4, 5), payload.aroundRows.map { it.rank })
    }

    private val standingsRows = listOf(
        StandingCsvRow(2026, "Player 1", 100.0, 1),
        StandingCsvRow(2026, "Player 2", 90.0, 2),
        StandingCsvRow(2026, "Player 3", 80.0, 3),
        StandingCsvRow(2026, "Player 4", 70.0, 4),
        StandingCsvRow(2026, "Player 5", 60.0, 5),
        StandingCsvRow(2026, "Player 6", 50.0, 6),
        StandingCsvRow(2026, "Player 7", 40.0, 7),
        StandingCsvRow(2026, "Player 8", 30.0, 8),
        StandingCsvRow(2026, "Player 9", 20.0, 9),
        StandingCsvRow(2026, "Player 10", 10.0, 10),
    )
}
