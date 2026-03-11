package com.pillyliu.pinprofandroid.library

import org.junit.Assert.assertEquals
import org.junit.Test

class LibraryDataLoaderParityTest {

    @Test
    fun resolvedPlayfieldSourceLabel_matchesIosSourcePrecedence() {
        assertEquals(
            "Local",
            resolvedPlayfieldSourceLabel(
                game(
                    playfieldImageUrl = "https://example.com/custom-playfield.jpg",
                    playfieldSourceLabel = "Local",
                ),
            ),
        )
        assertEquals(
            "Playfield (OPDB)",
            resolvedPlayfieldSourceLabel(
                game(
                    playfieldImageUrl = "https://img.opdb.org/images/playfields/sample.jpg",
                ),
            ),
        )
        assertEquals(
            "Prof",
            resolvedPlayfieldSourceLabel(
                game(
                    playfieldImageUrl = "https://pillyliu.com/pinball/images/playfields/sample.jpg",
                ),
            ),
        )
    }

    private fun game(
        playfieldImageUrl: String? = null,
        playfieldSourceLabel: String? = null,
        playfieldLocal: String? = null,
        playfieldLocalOriginal: String? = null,
    ): PinballGame {
        return PinballGame(
            libraryEntryId = null,
            practiceIdentity = "G-test",
            variant = null,
            sourceId = "venue--test",
            sourceName = "Test Venue",
            sourceType = LibrarySourceType.VENUE,
            area = null,
            areaOrder = null,
            group = null,
            position = null,
            bank = null,
            name = "Test Game",
            manufacturer = null,
            year = 2024,
            slug = "test-game",
            primaryImageUrl = null,
            primaryImageLargeUrl = null,
            playfieldImageUrl = playfieldImageUrl,
            alternatePlayfieldImageUrl = null,
            playfieldLocalOriginal = playfieldLocalOriginal,
            playfieldLocal = playfieldLocal,
            playfieldSourceLabel = playfieldSourceLabel,
            gameinfoLocal = null,
            rulesheetLocal = null,
            rulesheetUrl = null,
            rulesheetLinks = emptyList(),
            videos = emptyList(),
        )
    }
}
