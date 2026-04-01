package com.pillyliu.pinprofandroid.library

import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class LibraryImportedSourcesStoreTest {

    @Test
    fun upsert_replacesExistingVenueMachineIds() {
        val context = RuntimeEnvironment.getApplication().applicationContext as Context
        ImportedSourcesStore.save(context, emptyList())

        ImportedSourcesStore.upsert(
            context,
            ImportedSourceRecord(
                id = PM_RLM_LIBRARY_SOURCE_ID,
                name = PM_RLM_LIBRARY_SOURCE_NAME,
                type = LibrarySourceType.VENUE,
                provider = ImportedSourceProvider.PINBALL_MAP,
                providerSourceId = "16470",
                machineIds = listOf("deadpool", "dune", "foo-fighters"),
                lastSyncedAtMs = 1L,
            ),
        )
        ImportedSourcesStore.upsert(
            context,
            ImportedSourceRecord(
                id = PM_RLM_LIBRARY_SOURCE_ID,
                name = PM_RLM_LIBRARY_SOURCE_NAME,
                type = LibrarySourceType.VENUE,
                provider = ImportedSourceProvider.PINBALL_MAP,
                providerSourceId = "16470",
                machineIds = listOf("foo-fighters"),
                lastSyncedAtMs = 2L,
            ),
        )

        val stored = ImportedSourcesStore.load(context).single { it.id == PM_RLM_LIBRARY_SOURCE_ID }
        assertEquals(listOf("foo-fighters"), stored.machineIds)
        assertEquals(2L, stored.lastSyncedAtMs)
    }
}
