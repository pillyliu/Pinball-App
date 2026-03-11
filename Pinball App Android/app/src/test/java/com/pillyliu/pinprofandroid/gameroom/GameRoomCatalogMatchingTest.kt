package com.pillyliu.pinprofandroid.gameroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GameRoomCatalogMatchingTest {

    @Test
    fun addMachineSearch_matchesTitleVariantManufacturerAndYear() {
        val game = catalogGame(
            title = "Godzilla",
            variant = "70th Anniversary",
            manufacturer = "Stern Pinball",
            year = 2024,
        )

        assertTrue(gameRoomCatalogMatchesSearch(game, "godzilla"))
        assertTrue(gameRoomCatalogMatchesSearch(game, "70th"))
        assertTrue(gameRoomCatalogMatchesSearch(game, "stern"))
        assertTrue(gameRoomCatalogMatchesSearch(game, "2024"))
        assertFalse(gameRoomCatalogMatchesSearch(game, "1998"))
    }

    @Test
    fun addMachineSearch_matchesGroupedVariantAliasesForRepresentativeRows() {
        val game = catalogGame(
            title = "Godzilla",
            variant = "Premium",
            manufacturer = "Stern Pinball",
            year = 2021,
        )

        assertTrue(
            gameRoomCatalogMatchesSearch(
                game = game,
                query = "godzilla 70th",
                variantAliases = listOf("70th Anniversary", "LE", "Pro"),
            ),
        )
        assertTrue(
            gameRoomCatalogMatchesSearch(
                game = game,
                query = "godzilla le",
                variantAliases = listOf("70th Anniversary", "LE", "Pro"),
            ),
        )
    }

    @Test
    fun preferredCatalogGame_followsIosVariantPreferenceOrder() {
        val premium = catalogGame(title = "Foo Fighters", variant = "Premium", year = 2023, imageUrl = "https://example.com/premium.jpg")
        val anniversary = catalogGame(title = "Foo Fighters", variant = "25th Anniversary", year = 2023, imageUrl = "https://example.com/anniversary.jpg")

        val preferred = preferredCatalogGame(listOf(anniversary, premium))

        assertNotNull(preferred)
        assertEquals("Premium", preferred?.displayVariant)
    }

    @Test
    fun preferredCatalogGame_breaksTiesByKeepingArtworkBearingRepresentative() {
        val noImage = catalogGame(
            title = "Jurassic Park",
            variant = "LE",
            year = 2019,
            imageUrl = null,
            practiceIdentity = "Gjp-no-image",
        )
        val withImage = catalogGame(
            title = "Jurassic Park",
            variant = "LE",
            year = 2019,
            imageUrl = "https://example.com/jp.jpg",
            practiceIdentity = "Gjp-with-image",
        )

        val preferred = preferredCatalogGame(listOf(noImage, withImage))

        assertNotNull(preferred)
        assertEquals("https://example.com/jp.jpg", preferred?.primaryImageUrl)
    }

    @Test
    fun importNormalization_matchesIosDiacriticFolding() {
        assertEquals("jersey jack pinball", normalizeGameRoomImportText("Jérsey Jäck Pinball"))
    }

    private fun catalogGame(
        title: String,
        variant: String? = null,
        manufacturer: String? = null,
        year: Int? = null,
        imageUrl: String? = null,
        catalogGameID: String = "G-test",
        practiceIdentity: String = "G-test-practice",
    ): GameRoomCatalogGame {
        return GameRoomCatalogGame(
            catalogGameID = catalogGameID,
            canonicalPracticeIdentity = practiceIdentity,
            displayTitle = title,
            displayVariant = variant,
            manufacturerID = null,
            manufacturer = manufacturer,
            year = year,
            primaryImageUrl = imageUrl,
        )
    }
}
