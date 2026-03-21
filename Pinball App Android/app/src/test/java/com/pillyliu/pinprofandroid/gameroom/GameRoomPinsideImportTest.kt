package com.pillyliu.pinprofandroid.gameroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GameRoomPinsideImportTest {

    @Test
    fun canonicalPinsideDisplayedTitle_prefersSlugDerivedAnniversaryVariantOverPremiumSuffix() {
        val parsed = canonicalPinsideDisplayedTitle(
            title = "Godzilla (70th Anniversary Premium)",
            fallbackVariant = "70th Anniversary",
        )

        assertEquals("Godzilla", parsed.first)
        assertEquals("70th Anniversary", parsed.second)
    }

    @Test
    fun canonicalPinsideDisplayedTitle_keepsStandardPremiumVariantLabels() {
        val parsed = canonicalPinsideDisplayedTitle(
            title = "Foo Fighters (Premium)",
            fallbackVariant = null,
        )

        assertEquals("Foo Fighters", parsed.first)
        assertEquals("Premium", parsed.second)
    }

    @Test
    fun canonicalPinsideDisplayedTitle_returnsUnparsedTitleWhenSuffixIsNotVariant() {
        val parsed = canonicalPinsideDisplayedTitle(
            title = "Total Nuclear Annihilation (Spooky 2017)",
            fallbackVariant = null,
        )

        assertEquals("Total Nuclear Annihilation (Spooky 2017)", parsed.first)
        assertNull(parsed.second)
    }
}
