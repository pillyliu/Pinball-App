package com.pillyliu.pinprofandroid.settings

import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SettingsImportScreensTest {

    @Test
    fun filteredForBucket_keepsCuratedModernsAndTopTwentyClassicsSeparate() {
        val moderns = listOf(
            manufacturer("manufacturer-stern", "Stern", 80, isModern = true, featuredRank = 1),
            manufacturer("manufacturer-jjp", "Jersey Jack Pinball", 11, isModern = true, featuredRank = 2),
        )
        val classics = (1..21).map { index ->
            manufacturer(
                id = "manufacturer-classic-$index",
                name = "Classic $index",
                gameCount = 400 - index,
                isModern = false,
            )
        }
        val options = moderns + classics

        val modernBucket = options.filteredForBucket(ManufacturerBucket.MODERN)
        val classicBucket = options.filteredForBucket(ManufacturerBucket.CLASSIC)
        val otherBucket = options.filteredForBucket(ManufacturerBucket.OTHER)

        assertEquals(listOf("Stern", "Jersey Jack Pinball"), modernBucket.map { it.name })
        assertEquals(20, classicBucket.size)
        assertTrue(classicBucket.all { !it.isModern })
        assertFalse(classicBucket.any { it.name == "Classic 21" })
        assertEquals(listOf("Classic 21"), otherBucket.map { it.name })
    }

    private fun manufacturer(
        id: String,
        name: String,
        gameCount: Int,
        isModern: Boolean,
        featuredRank: Int? = null,
    ): CatalogManufacturerOption {
        return CatalogManufacturerOption(
            id = id,
            name = name,
            gameCount = gameCount,
            isModern = isModern,
            featuredRank = featuredRank,
            sortBucket = if (isModern) 0 else 1,
        )
    }
}
