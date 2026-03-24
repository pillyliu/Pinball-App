package com.pillyliu.pinprofandroid.library

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LibraryDataLoaderParityTest {

    @Test
    fun normalizedOptionalString_treatsNullishStringsAsMissing() {
        assertNull(normalizedOptionalString(null))
        assertNull(normalizedOptionalString(""))
        assertNull(normalizedOptionalString("   "))
        assertNull(normalizedOptionalString("null"))
        assertNull(normalizedOptionalString(" NONE "))
        assertEquals("/pinball/rulesheets/G5pe4-rulesheet.md", normalizedOptionalString(" /pinball/rulesheets/G5pe4-rulesheet.md "))
    }

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

    @Test
    fun decodeOPDBExportCatalogMachines_doesNotTreatBackglassAsPlayfield() {
        val machines = decodeOPDBExportCatalogMachines(
            """
            [
              {
                "opdb_id": "GTEST-MBACK",
                "name": "Backglass Only",
                "manufacture_date": "2024-01-01",
                "manufacturer": { "manufacturer_id": 1, "name": "Stern" },
                "images": [
                  {
                    "type": "backglass",
                    "primary": true,
                    "urls": {
                      "medium": "https://img.opdb.org/images/backglasses/backglass-medium.webp",
                      "large": "https://img.opdb.org/images/backglasses/backglass-large.webp"
                    }
                  }
                ]
              }
            ]
            """.trimIndent(),
        )

        val machine = machines.single { it.opdbMachineId == "GTEST-MBACK" }
        assertEquals("https://img.opdb.org/images/backglasses/backglass-medium.webp", machine.primaryImageMediumUrl)
        assertEquals("https://img.opdb.org/images/backglasses/backglass-large.webp", machine.primaryImageLargeUrl)
        assertNull(machine.playfieldImageMediumUrl)
        assertNull(machine.playfieldImageLargeUrl)
    }

    @Test
    fun decodeCatalogManufacturerOptionsFromOPDBExport_usesCuratedModernListInsteadOfYear() {
        val manufacturers = decodeCatalogManufacturerOptionsFromOPDBExport(
            """
            [
              {
                "opdb_id": "GSTERN-MPRO",
                "name": "Foo Fighters",
                "manufacture_date": "2023-01-01",
                "manufacturer": { "manufacturer_id": 1, "name": "Stern" },
                "images": []
              },
              {
                "opdb_id": "GSTERN-MLE-A1",
                "name": "Foo Fighters",
                "manufacture_date": "2023-02-01",
                "manufacturer": { "manufacturer_id": 1, "name": "Stern" },
                "images": []
              },
              {
                "opdb_id": "GJJP-MPRO",
                "name": "Avatar",
                "manufacture_date": "2025-01-01",
                "manufacturer": { "manufacturer_id": 2, "name": "Jersey Jack Pinball" },
                "images": []
              },
              {
                "opdb_id": "GGOT-MEM",
                "name": "Surf Champ",
                "manufacture_date": "2025-01-01",
                "manufacturer": { "manufacturer_id": 3, "name": "Gottlieb" },
                "images": []
              }
            ]
            """.trimIndent(),
        )

        val stern = manufacturers.first { it.name == "Stern" }
        val jjp = manufacturers.first { it.name == "Jersey Jack Pinball" }
        val gottlieb = manufacturers.first { it.name == "Gottlieb" }

        assertTrue(stern.isModern)
        assertTrue(jjp.isModern)
        assertFalse(gottlieb.isModern)
        assertEquals(1, stern.gameCount)
    }

    @Test
    fun decodeOPDBExportCatalogMachines_appendsPinProfFinalExamWhenMissing() {
        val machines = decodeOPDBExportCatalogMachines("[]")
        val machine = machines.single { it.opdbMachineId == "G900001-1" }

        assertEquals("G900001", machine.practiceIdentity)
        assertEquals("PinProf: The Final Exam", machine.name)
        assertEquals("PinProf Labs", machine.manufacturerName)
        assertEquals("/pinball/images/backglasses/G900001-1-backglass.webp", machine.primaryImageMediumUrl)
        assertEquals("/pinball/images/playfields/G900001-1-playfield_700.webp", machine.playfieldImageMediumUrl)
    }

    @Test
    fun decodeCatalogManufacturerOptionsFromOPDBExport_keepsPinProfLabsAtBottomOfModernBucket() {
        val manufacturers = decodeCatalogManufacturerOptionsFromOPDBExport(
            """
            [
              {
                "opdb_id": "GSTERN-MPRO",
                "name": "Foo Fighters",
                "manufacture_date": "2023-01-01",
                "manufacturer": { "manufacturer_id": 1, "name": "Stern" },
                "images": []
              },
              {
                "opdb_id": "GJJP-MPRO",
                "name": "Avatar",
                "manufacture_date": "2025-01-01",
                "manufacturer": { "manufacturer_id": 2, "name": "Jersey Jack Pinball" },
                "images": []
              }
            ]
            """.trimIndent(),
        )

        val modernNames = manufacturers.filter { it.isModern }.map { it.name }
        assertEquals(listOf("Stern", "Jersey Jack Pinball", "PinProf Labs"), modernNames)
    }

    @Test
    fun resolveImportedGame_suppressesStaleLocalRulesheetWhenTfExists() {
        val game = resolveImportedGame(
            machine = catalogMachine(),
            source = ImportedSourceRecord(
                id = "manufacturer--stern",
                name = "Stern",
                type = LibrarySourceType.CATEGORY,
                provider = ImportedSourceProvider.OPDB,
                providerSourceId = "manufacturer-1",
                machineIds = listOf("GQKyP-MPRO"),
            ),
            manufacturerById = emptyMap(),
            curatedOverride = LegacyCuratedOverride(
                practiceIdentity = "GQKyP",
                rulesheetLocalPath = "/pinball/rulesheets/GQKyP-rulesheet.md",
            ),
            opdbRulesheets = listOf(
                CatalogRulesheetLinkRecord(
                    practiceIdentity = "GQKyP",
                    provider = "tf",
                    label = "Rulesheet (TF)",
                    url = "https://tiltforums.com/t/james-bond-007-rulesheet/7893",
                    localPath = null,
                    priority = 0,
                ),
            ),
            opdbVideos = emptyList(),
            venueMetadata = null,
        )

        assertNull(game.rulesheetLocal)
        assertEquals(1, game.rulesheetLinks.size)
        assertEquals("Rulesheet (TF)", game.rulesheetLinks.single().label)
    }

    @Test
    fun resolveLegacyGame_suppressesStaleLocalRulesheetWhenTfExists() {
        val game = resolveLegacyGame(
            legacyGame = PinballGame(
                libraryEntryId = "legacy-gqkyp",
                practiceIdentity = "GQKyP",
                opdbId = "GQKyP-MPRO",
                opdbGroupId = "GQKyP",
                opdbMachineId = "GQKyP-MPRO",
                variant = "Pro",
                sourceId = "manufacturer--stern",
                sourceName = "Stern",
                sourceType = LibrarySourceType.CATEGORY,
                area = null,
                areaOrder = null,
                group = null,
                position = null,
                bank = null,
                name = "James Bond 007",
                manufacturer = "Stern",
                year = 2022,
                slug = "james-bond-007",
                primaryImageUrl = null,
                primaryImageLargeUrl = null,
                playfieldImageUrl = null,
                alternatePlayfieldImageUrl = null,
                playfieldLocalOriginal = null,
                playfieldLocal = null,
                playfieldSourceLabel = null,
                gameinfoLocal = null,
                rulesheetLocal = "/pinball/rulesheets/GQKyP-rulesheet.md",
                rulesheetUrl = null,
                rulesheetLinks = emptyList(),
                videos = emptyList(),
            ),
            curatedOverridesByPracticeIdentity = emptyMap(),
            machineByPracticeIdentity = mapOf("GQKyP" to listOf(catalogMachine())),
            machineByOpdbId = mapOf("GQKyP-MPRO" to catalogMachine()),
            manufacturerById = emptyMap(),
            opdbRulesheetsByPracticeIdentity = mapOf(
                "GQKyP" to listOf(
                    CatalogRulesheetLinkRecord(
                        practiceIdentity = "GQKyP",
                        provider = "tf",
                        label = "Rulesheet (TF)",
                        url = "https://tiltforums.com/t/james-bond-007-rulesheet/7893",
                        localPath = null,
                        priority = 0,
                    ),
                ),
            ),
            opdbVideosByPracticeIdentity = emptyMap(),
        )

        assertNull(game.rulesheetLocal)
        assertEquals(1, game.rulesheetLinks.size)
        assertEquals("Rulesheet (TF)", game.rulesheetLinks.single().label)
    }

    @Test
    fun displayedRulesheetLinks_hidesActionlessPinProfEntriesWhenLocalMarkdownExists() {
        val game = PinballGame(
            libraryEntryId = "legacy-g5pe4",
            practiceIdentity = "G5pe4",
            opdbId = "G5pe4-MePZv",
            opdbGroupId = "G5pe4",
            opdbMachineId = "G5pe4-MePZv",
            variant = null,
            sourceId = "manufacturer--williams",
            sourceName = "Williams",
            sourceType = LibrarySourceType.MANUFACTURER,
            area = null,
            areaOrder = null,
            group = null,
            position = null,
            bank = null,
            name = "Medieval Madness",
            manufacturer = "Williams",
            year = 1997,
            slug = "medieval-madness",
            primaryImageUrl = null,
            primaryImageLargeUrl = null,
            playfieldImageUrl = null,
            alternatePlayfieldImageUrl = null,
            playfieldLocalOriginal = null,
            playfieldLocal = null,
            playfieldSourceLabel = null,
            gameinfoLocal = null,
            rulesheetLocal = "/pinball/rulesheets/G5pe4-rulesheet.md",
            rulesheetUrl = null,
            rulesheetLinks = listOf(
                ReferenceLink(label = "Rulesheet (PinProf)", url = null),
                ReferenceLink(label = "Rulesheet (PAPA)", url = "https://pinball.org/rules/medievalmadness.html"),
                ReferenceLink(label = "Rulesheet (PP)", url = "https://pinballprimer.github.io/medieval_G5pe4.html"),
            ),
            videos = emptyList(),
        )

        val displayed = game.displayedRulesheetLinks
        assertEquals(2, displayed.size)
        assertEquals(listOf("Rulesheet (PAPA)", "Rulesheet (PP)"), displayed.map { it.label })
    }

    @Test
    fun displayedRulesheetLinks_hidesHostedPinProfMarkdownLinksWhenLocalMarkdownExists() {
        val game = PinballGame(
            libraryEntryId = "legacy-g5pe4",
            practiceIdentity = "G5pe4",
            opdbId = "G5pe4-MePZv",
            opdbGroupId = "G5pe4",
            opdbMachineId = "G5pe4-MePZv",
            variant = null,
            sourceId = "manufacturer--williams",
            sourceName = "Williams",
            sourceType = LibrarySourceType.MANUFACTURER,
            area = null,
            areaOrder = null,
            group = null,
            position = null,
            bank = null,
            name = "Medieval Madness",
            manufacturer = "Williams",
            year = 1997,
            slug = "medieval-madness",
            primaryImageUrl = null,
            primaryImageLargeUrl = null,
            playfieldImageUrl = null,
            alternatePlayfieldImageUrl = null,
            playfieldLocalOriginal = null,
            playfieldLocal = null,
            playfieldSourceLabel = null,
            gameinfoLocal = null,
            rulesheetLocal = "/pinball/rulesheets/G5pe4-rulesheet.md",
            rulesheetUrl = null,
            rulesheetLinks = listOf(
                ReferenceLink(label = "Rulesheet", url = "https://pillyliu.com/pinball/rulesheets/G5pe4-rulesheet.md"),
                ReferenceLink(label = "Rulesheet (PAPA)", url = "https://pinball.org/rules/medievalmadness.html"),
            ),
            videos = emptyList(),
        )

        val displayed = game.displayedRulesheetLinks
        assertEquals(1, displayed.size)
        assertEquals("Rulesheet (PAPA)", displayed.single().label)
    }

    @Test
    fun displayedRulesheetLinks_hidesMalformedPinProfMarkdownLinksWhenLocalMarkdownExists() {
        val game = PinballGame(
            libraryEntryId = "legacy-g5pe4",
            practiceIdentity = "G5pe4",
            opdbId = "G5pe4-MePZv",
            opdbGroupId = "G5pe4",
            opdbMachineId = "G5pe4-MePZv",
            variant = null,
            sourceId = "manufacturer--williams",
            sourceName = "Williams",
            sourceType = LibrarySourceType.MANUFACTURER,
            area = null,
            areaOrder = null,
            group = null,
            position = null,
            bank = null,
            name = "Medieval Madness",
            manufacturer = "Williams",
            year = 1997,
            slug = "medieval-madness",
            primaryImageUrl = null,
            primaryImageLargeUrl = null,
            playfieldImageUrl = null,
            alternatePlayfieldImageUrl = null,
            playfieldLocalOriginal = null,
            playfieldLocal = null,
            playfieldSourceLabel = null,
            gameinfoLocal = null,
            rulesheetLocal = "/pinball/rulesheets/G5pe4-rulesheet.md",
            rulesheetUrl = null,
            rulesheetLinks = listOf(
                ReferenceLink(label = "Rulesheet", url = "G5pe4-rulesheet.md"),
                ReferenceLink(label = "Rulesheet", url = "https://pillyliu.com/rules/G5pe4?source=local"),
                ReferenceLink(label = "Rulesheet (PAPA)", url = "https://pinball.org/rules/medievalmadness.html"),
                ReferenceLink(label = "Rulesheet (PP)", url = "https://pinballprimer.github.io/medieval_G5pe4.html"),
            ),
            videos = emptyList(),
        )

        val displayed = game.displayedRulesheetLinks
        assertEquals(2, displayed.size)
        assertEquals(listOf("Rulesheet (PAPA)", "Rulesheet (PP)"), displayed.map { it.label })
    }

    @Test
    fun nullishRulesheetLocal_doesNotCreateBogusPinProfRulesheetResource() {
        val game = PinballGame(
            libraryEntryId = "legacy-g5pe4",
            practiceIdentity = "G5pe4",
            opdbId = "G5pe4-MePZv",
            opdbGroupId = "G5pe4",
            opdbMachineId = "G5pe4-MePZv",
            variant = null,
            sourceId = "manufacturer--williams",
            sourceName = "Williams",
            sourceType = LibrarySourceType.MANUFACTURER,
            area = null,
            areaOrder = null,
            group = null,
            position = null,
            bank = null,
            name = "Medieval Madness",
            manufacturer = "Williams",
            year = 1997,
            slug = "medieval-madness",
            primaryImageUrl = null,
            primaryImageLargeUrl = null,
            playfieldImageUrl = null,
            alternatePlayfieldImageUrl = null,
            playfieldLocalOriginal = null,
            playfieldLocal = null,
            playfieldSourceLabel = null,
            gameinfoLocal = null,
            rulesheetLocal = "null",
            rulesheetUrl = null,
            rulesheetLinks = listOf(
                ReferenceLink(label = "Rulesheet (PinProf)", url = null),
                ReferenceLink(label = "Rulesheet (PAPA)", url = "https://pinball.org/rules/medievalmadness.html"),
            ),
            videos = emptyList(),
        )

        assertTrue(game.rulesheetPathCandidates.isEmpty())
        assertFalse(game.hasLocalRulesheetResource)
        assertEquals(listOf("Rulesheet (PAPA)"), game.displayedRulesheetLinks.map { it.label })
    }

    private fun catalogMachine(): CatalogMachineRecord =
        CatalogMachineRecord(
            practiceIdentity = "GQKyP",
            opdbMachineId = "GQKyP-MPRO",
            opdbGroupId = "GQKyP",
            slug = "james-bond-007",
            name = "James Bond 007 (Pro)",
            variant = "Pro",
            manufacturerId = "manufacturer-1",
            manufacturerName = "Stern",
            year = 2022,
            primaryImageMediumUrl = null,
            primaryImageLargeUrl = null,
            playfieldImageMediumUrl = null,
            playfieldImageLargeUrl = null,
        )

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
