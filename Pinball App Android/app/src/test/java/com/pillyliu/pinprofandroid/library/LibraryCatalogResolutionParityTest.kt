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

    @Test
    fun shortRulesheetTitle_usesOtherForUnhandledWebRulesheet() {
        val link = ReferenceLink(
            label = "Pinball News",
            url = "https://www.pinballnews.com/games/tron/index.html",
        )

        assertEquals("Other", link.shortRulesheetTitle)
    }

    @Test
    fun shortRulesheetTitle_keepsLocalForLocalSource() {
        val link = ReferenceLink(
            label = "Rulesheet (source)",
            url = null,
        )

        assertEquals("Local", link.shortRulesheetTitle)
    }

    @Test
    fun resolveVideoLinks_ordersByKindThenNaturalLabel() {
        val resolved = resolveVideoLinks(
            listOf(
                video(provider = "matchplay", kind = "tutorial", label = "Tutorial 10", url = "https://www.youtube.com/watch?v=t10"),
                video(provider = "local", kind = "competition", label = "Competition 1", url = "https://www.youtube.com/watch?v=c1"),
                video(provider = "local", kind = "gameplay", label = "Gameplay 2", url = "https://www.youtube.com/watch?v=g2"),
                video(provider = "local", kind = "tutorial", label = "Tutorial 2", url = "https://www.youtube.com/watch?v=t2"),
                video(provider = "matchplay", kind = "gameplay", label = "Gameplay 10", url = "https://www.youtube.com/watch?v=g10"),
                video(provider = "local", kind = "tutorial", label = "Tutorial 1", url = "https://www.youtube.com/watch?v=t1"),
            ),
        )

        assertEquals(
            listOf("Tutorial 1", "Tutorial 2", "Tutorial 10", "Gameplay 2", "Gameplay 10", "Competition 1"),
            resolved.map { it.label },
        )
    }

    @Test
    fun mergeResolvedVideos_reordersCuratedAndCatalogVideosByDisplaySequence() {
        val merged = mergeResolvedVideos(
            primary = listOf(
                Video(kind = "competition", label = "Competition 2", url = "https://www.youtube.com/watch?v=c2"),
                Video(kind = "tutorial", label = "Tutorial 2", url = "https://www.youtube.com/watch?v=t2"),
            ),
            secondary = listOf(
                Video(kind = "gameplay", label = "Gameplay 3", url = "https://www.youtube.com/watch?v=g3"),
                Video(kind = "tutorial", label = "Tutorial 1", url = "https://www.youtube.com/watch?v=t1"),
                Video(kind = "competition", label = "Competition 1", url = "https://www.youtube.com/watch?v=c1"),
            ),
        )

        assertEquals(
            listOf("Tutorial 1", "Tutorial 2", "Gameplay 3", "Competition 1", "Competition 2"),
            merged.map { it.label },
        )
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

    private fun video(
        provider: String,
        kind: String,
        label: String,
        url: String,
        practiceIdentity: String = "g-test",
        priority: Int? = 0,
    ): CatalogVideoLinkRecord {
        return CatalogVideoLinkRecord(
            practiceIdentity = practiceIdentity,
            provider = provider,
            kind = kind,
            label = label,
            url = url,
            priority = priority,
        )
    }
}
