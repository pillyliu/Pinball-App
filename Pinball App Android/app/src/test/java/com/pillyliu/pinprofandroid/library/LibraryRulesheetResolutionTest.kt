package com.pillyliu.pinprofandroid.library

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LibraryRulesheetResolutionTest {

    @Test
    fun resolveRulesheetLinks_keepsLocalPathWhenExternalSiblingSortsFirst() {
        val resolved = resolveRulesheetLinks(
            listOf(
                CatalogRulesheetLinkRecord(
                    practiceIdentity = "GrkL5",
                    provider = "pinprof",
                    label = "Rulesheet (PinProf)",
                    localPath = "/pinball/rulesheets/GrkL5-rulesheet.md",
                    url = null,
                    priority = 0,
                ),
                CatalogRulesheetLinkRecord(
                    practiceIdentity = "GrkL5",
                    provider = "pinprof",
                    label = "Rulesheet",
                    localPath = null,
                    url = "https://pinballnews.com/games/tron/index6b.html",
                    priority = 0,
                ),
                CatalogRulesheetLinkRecord(
                    practiceIdentity = "GrkL5",
                    provider = "pp",
                    label = "Rulesheet (PP)",
                    localPath = null,
                    url = "https://pinballprimer.github.io/tron_GrkL5.html",
                    priority = 0,
                ),
            ),
        )

        assertEquals("/pinball/rulesheets/GrkL5-rulesheet.md", resolved.localPath)
        assertEquals(2, resolved.links.size)
        assertTrue(resolved.links.any { it.url == "https://pinballnews.com/games/tron/index6b.html" })
        assertTrue(resolved.links.any { it.url == "https://pinballprimer.github.io/tron_GrkL5.html" })
    }
}
