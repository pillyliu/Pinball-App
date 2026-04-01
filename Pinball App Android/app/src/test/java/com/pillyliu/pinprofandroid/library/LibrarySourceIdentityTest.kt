package com.pillyliu.pinprofandroid.library

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LibrarySourceIdentityTest {

    @Test
    fun importedPinballMapVenueNeedsStaleRefresh_whenSyncedBeforeCutoff() {
        assertTrue(
            importedPinballMapVenueNeedsStaleRefresh(
                ImportedSourceRecord(
                    id = PM_RLM_LIBRARY_SOURCE_ID,
                    name = PM_RLM_LIBRARY_SOURCE_NAME,
                    type = LibrarySourceType.VENUE,
                    provider = ImportedSourceProvider.PINBALL_MAP,
                    providerSourceId = "16470",
                    machineIds = listOf("old-game"),
                    lastSyncedAtMs = STALE_IMPORTED_PINBALL_MAP_VENUE_REFRESH_CUTOFF_MS - 1L,
                ),
            ),
        )
    }

    @Test
    fun importedPinballMapVenueNeedsStaleRefresh_skipsNewerUnsyncedOrNonVenueSources() {
        assertFalse(
            importedPinballMapVenueNeedsStaleRefresh(
                ImportedSourceRecord(
                    id = PM_RLM_LIBRARY_SOURCE_ID,
                    name = PM_RLM_LIBRARY_SOURCE_NAME,
                    type = LibrarySourceType.VENUE,
                    provider = ImportedSourceProvider.PINBALL_MAP,
                    providerSourceId = "16470",
                    machineIds = listOf("new-game"),
                    lastSyncedAtMs = STALE_IMPORTED_PINBALL_MAP_VENUE_REFRESH_CUTOFF_MS,
                ),
            ),
        )
        assertFalse(
            importedPinballMapVenueNeedsStaleRefresh(
                ImportedSourceRecord(
                    id = PM_RLM_LIBRARY_SOURCE_ID,
                    name = PM_RLM_LIBRARY_SOURCE_NAME,
                    type = LibrarySourceType.VENUE,
                    provider = ImportedSourceProvider.PINBALL_MAP,
                    providerSourceId = "16470",
                    machineIds = listOf("unsynced-game"),
                    lastSyncedAtMs = null,
                ),
            ),
        )
        assertFalse(
            importedPinballMapVenueNeedsStaleRefresh(
                ImportedSourceRecord(
                    id = "manufacturer-12",
                    name = "Stern",
                    type = LibrarySourceType.MANUFACTURER,
                    provider = ImportedSourceProvider.OPDB,
                    providerSourceId = "12",
                    machineIds = listOf("foo-fighters"),
                    lastSyncedAtMs = STALE_IMPORTED_PINBALL_MAP_VENUE_REFRESH_CUTOFF_MS - 1L,
                ),
            ),
        )
    }
}
