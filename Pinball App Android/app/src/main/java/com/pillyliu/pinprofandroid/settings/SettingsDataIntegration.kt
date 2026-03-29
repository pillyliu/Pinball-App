package com.pillyliu.pinprofandroid.settings

import android.content.Context
import android.webkit.CookieManager
import android.webkit.WebStorage
import android.webkit.WebView
import coil.imageLoader
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.league.LeaguePreviewRefreshEvents
import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption
import com.pillyliu.pinprofandroid.library.ImportedSourceProvider
import com.pillyliu.pinprofandroid.library.ImportedSourceRecord
import com.pillyliu.pinprofandroid.library.ImportedSourcesStore
import com.pillyliu.pinprofandroid.library.LibrarySourceEvents
import com.pillyliu.pinprofandroid.library.LibrarySourceState
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore
import com.pillyliu.pinprofandroid.library.LibrarySourceType
import com.pillyliu.pinprofandroid.library.LibraryVenueSearchResult
import com.pillyliu.pinprofandroid.library.loadHostedCatalogManufacturerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal data class SettingsDataSnapshot(
    val manufacturers: List<CatalogManufacturerOption>,
    val importedSources: List<ImportedSourceRecord>,
    val sourceState: LibrarySourceState,
)

internal data class SettingsSourceSnapshot(
    val importedSources: List<ImportedSourceRecord>,
    val sourceState: LibrarySourceState,
)

internal suspend fun loadSettingsDataSnapshot(context: Context): SettingsDataSnapshot {
    val manufacturers = withContext(Dispatchers.IO) { loadHostedCatalogManufacturerOptions(context) }
    return SettingsDataSnapshot(
        manufacturers = manufacturers,
        importedSources = ImportedSourcesStore.load(context),
        sourceState = LibrarySourceStateStore.load(context),
    )
}

internal suspend fun forceRefreshHostedSettingsData(context: Context): SettingsDataSnapshot {
    withContext(Dispatchers.IO) {
        PinballDataCache.forceRefreshHostedLibraryData()
    }
    LeaguePreviewRefreshEvents.notifyChanged()
    LibrarySourceEvents.notifyChanged()
    return loadSettingsDataSnapshot(context)
}

internal suspend fun clearAppRuntimeCaches(context: Context) {
    withContext(Dispatchers.IO) {
        PinballDataCache.clearAllCachedData()
        context.cacheDir.resolve("pinprof-image-cache").takeIf { it.exists() }?.deleteRecursively()
        context.cacheDir.resolve("WebView").takeIf { it.exists() }?.deleteRecursively()
    }
    withContext(Dispatchers.Main) {
        context.imageLoader.memoryCache?.clear()
        runCatching {
            WebStorage.getInstance().deleteAllData()
            CookieManager.getInstance().removeAllCookies(null)
            CookieManager.getInstance().flush()
            WebView(context).apply {
                clearCache(true)
                clearHistory()
                destroy()
            }
        }
    }
}

internal fun addManufacturerSource(
    context: Context,
    manufacturer: CatalogManufacturerOption,
): SettingsSourceSnapshot {
    return persistSettingsSource(
        context = context,
        record = ImportedSourceRecord(
            id = "manufacturer--${manufacturer.id}",
            name = manufacturer.name,
            type = LibrarySourceType.MANUFACTURER,
            provider = ImportedSourceProvider.OPDB,
            providerSourceId = manufacturer.id,
            machineIds = emptyList(),
            lastSyncedAtMs = System.currentTimeMillis(),
        ),
    )
}

internal fun addVenueSource(
    context: Context,
    result: LibraryVenueSearchResult,
    machineIds: List<String>,
    query: String,
    radiusMiles: Int,
): SettingsSourceSnapshot {
    return persistSettingsSource(
        context = context,
        record = ImportedSourceRecord(
            id = result.id,
            name = result.name,
            type = LibrarySourceType.VENUE,
            provider = ImportedSourceProvider.PINBALL_MAP,
            providerSourceId = venueProviderSourceId(result.id),
            machineIds = machineIds,
            lastSyncedAtMs = System.currentTimeMillis(),
            searchQuery = query,
            distanceMiles = radiusMiles,
        ),
    )
}

internal fun addTournamentSource(
    context: Context,
    result: MatchPlayTournamentImportResult,
): SettingsSourceSnapshot {
    return persistSettingsSource(
        context = context,
        record = ImportedSourceRecord(
            id = "tournament--mp-${result.id}",
            name = result.name,
            type = LibrarySourceType.TOURNAMENT,
            provider = ImportedSourceProvider.MATCH_PLAY,
            providerSourceId = result.id,
            machineIds = result.machineIds,
            lastSyncedAtMs = System.currentTimeMillis(),
        ),
    )
}

internal fun removeSettingsSource(
    context: Context,
    sourceId: String,
): SettingsSourceSnapshot {
    ImportedSourcesStore.remove(context, sourceId)
    return publishSettingsSourceMutation(context)
}

internal suspend fun refreshVenueSource(
    context: Context,
    source: ImportedSourceRecord,
): SettingsSourceSnapshot {
    val machineIds = withContext(Dispatchers.IO) {
        PinballMapClient.fetchVenueMachineIds(source.providerSourceId)
    }
    return updateSettingsSource(context, source) {
        it.copy(machineIds = machineIds, lastSyncedAtMs = System.currentTimeMillis())
    }
}

internal suspend fun refreshTournamentSource(
    context: Context,
    source: ImportedSourceRecord,
): SettingsSourceSnapshot {
    val tournament = withContext(Dispatchers.IO) {
        MatchPlayClient.fetchTournament(source.providerSourceId)
    }
    return updateSettingsSource(context, source) {
        it.copy(
            name = tournament.name,
            machineIds = tournament.machineIds,
            lastSyncedAtMs = System.currentTimeMillis(),
        )
    }
}

private fun persistSettingsSource(
    context: Context,
    record: ImportedSourceRecord,
    enableAndPin: Boolean = true,
): SettingsSourceSnapshot {
    ImportedSourcesStore.upsert(context, record)
    if (enableAndPin) {
        LibrarySourceStateStore.upsertSource(context, record.id, enable = true, pinIfPossible = true)
    }
    return publishSettingsSourceMutation(context)
}

private fun updateSettingsSource(
    context: Context,
    source: ImportedSourceRecord,
    update: (ImportedSourceRecord) -> ImportedSourceRecord,
): SettingsSourceSnapshot {
    ImportedSourcesStore.upsert(context, update(source))
    return publishSettingsSourceMutation(context)
}

private fun venueProviderSourceId(sourceId: String): String = sourceId.removePrefix("venue--pm-")

private fun publishSettingsSourceMutation(context: Context): SettingsSourceSnapshot {
    LibrarySourceEvents.notifyChanged()
    return settingsSourceSnapshot(context)
}

private fun settingsSourceSnapshot(context: Context): SettingsSourceSnapshot {
    return SettingsSourceSnapshot(
        importedSources = ImportedSourcesStore.load(context),
        sourceState = LibrarySourceStateStore.load(context),
    )
}
