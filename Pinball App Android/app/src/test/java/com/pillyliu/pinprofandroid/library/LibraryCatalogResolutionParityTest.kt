package com.pillyliu.pinprofandroid.library

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LibraryCatalogResolutionParityTest {

    @Test
    fun catalogVariantScore_doesNotTreatLeAsPremiumFallback() {
        assertEquals(0, catalogVariantScore(machineVariant = "LE", requestedVariant = "premium"))
    }

    @Test
    fun catalogVariantScore_doesNotTreatAnniversaryAsLeFallback() {
        assertEquals(0, catalogVariantScore(machineVariant = "70th Anniversary", requestedVariant = "le"))
    }

    @Test
    fun preferredMachineForVariant_matchesIosIdTieBreakAfterEqualScore() {
        val selected = preferredMachineForVariant(
            candidates = listOf(
                machine(opdbMachineId = "a-id", name = "Zulu Premium"),
                machine(opdbMachineId = "b-id", name = "Alpha Premium"),
            ),
            requestedVariant = "premium",
        )

        assertEquals("a-id", selected?.opdbMachineId)
    }

    @Test
    fun preferredMachineForVariant_returnsNullWhenBestScoreIsZero() {
        val selected = preferredMachineForVariant(
            candidates = listOf(
                machine(opdbMachineId = "a-id", variant = "Pro"),
                machine(opdbMachineId = "b-id", variant = "LE"),
            ),
            requestedVariant = "premium",
        )

        assertNull(selected)
    }

    private fun machine(
        opdbMachineId: String,
        name: String = "Test Machine",
        variant: String = "Premium",
        year: Int = 2024,
        practiceIdentity: String = "g-test",
    ): CatalogMachineRecord {
        return CatalogMachineRecord(
            practiceIdentity = practiceIdentity,
            opdbMachineId = opdbMachineId,
            opdbGroupId = practiceIdentity,
            slug = "$practiceIdentity-$opdbMachineId",
            name = name,
            variant = variant,
            manufacturerId = "stern",
            manufacturerName = "Stern",
            year = year,
            primaryImageMediumUrl = "https://img.example.com/$opdbMachineId.jpg",
            primaryImageLargeUrl = null,
            playfieldImageMediumUrl = null,
            playfieldImageLargeUrl = null,
        )
    }
}
