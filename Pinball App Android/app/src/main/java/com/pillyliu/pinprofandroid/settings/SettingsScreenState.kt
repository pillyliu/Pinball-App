package com.pillyliu.pinprofandroid.settings

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption
import com.pillyliu.pinprofandroid.library.ImportedSourceRecord
import com.pillyliu.pinprofandroid.library.LibrarySourceType
import com.pillyliu.pinprofandroid.library.LibrarySourceEvents
import com.pillyliu.pinprofandroid.library.LibrarySourceState
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore

@Stable
internal class SettingsScreenState(
    private val context: Context,
) {
    var route by mutableStateOf<SettingsRoute>(SettingsRoute.Home)
    var manufacturers by mutableStateOf<List<CatalogManufacturerOption>>(emptyList())
    var importedSources by mutableStateOf<List<ImportedSourceRecord>>(emptyList())
    var sourceState by mutableStateOf(LibrarySourceState())
    var loading by mutableStateOf(true)
    var error by mutableStateOf<String?>(null)
    var refreshingHostedData by mutableStateOf(false)
    var hostedDataStatusMessage by mutableStateOf<String?>(null)
    var hostedDataStatusIsError by mutableStateOf(false)
    var clearingCache by mutableStateOf(false)
    var cacheStatusMessage by mutableStateOf<String?>(null)
    var cacheStatusIsError by mutableStateOf(false)
    private var pendingLocalSourceReloadSuppressions = 0

    private fun markLocalSourceReloadSuppression() {
        pendingLocalSourceReloadSuppressions += 1
    }

    fun applySnapshot(snapshot: SettingsDataSnapshot) {
        manufacturers = snapshot.manufacturers
        importedSources = snapshot.importedSources
        sourceState = snapshot.sourceState
    }

    fun applySourceSnapshot(snapshot: SettingsSourceSnapshot) {
        importedSources = snapshot.importedSources
        sourceState = snapshot.sourceState
    }

    private fun completeSourceMutation(
        snapshot: SettingsSourceSnapshot,
        returnHome: Boolean = false,
    ) {
        applySourceSnapshot(snapshot)
        markLocalSourceReloadSuppression()
        if (returnHome) {
            route = SettingsRoute.Home
        }
        error = null
    }

    private suspend fun refreshImportedSource(
        source: ImportedSourceRecord,
        expectedType: LibrarySourceType,
        failurePrefix: String,
        refresh: suspend (ImportedSourceRecord) -> SettingsSourceSnapshot,
    ) {
        if (source.type != expectedType) return
        runCatching { refresh(source) }
            .onSuccess { completeSourceMutation(it) }
            .onFailure {
                error = "$failurePrefix: ${it.message ?: "Unknown error"}"
            }
    }

    suspend fun reload() {
        loading = true
        error = null
        runCatching { loadSettingsDataSnapshot(context) }
            .onSuccess(::applySnapshot)
            .onFailure { error = it.message ?: "Failed to load settings." }
        loading = false
    }

    fun afterSourceMutation() {
        applySourceSnapshot(
            SettingsSourceSnapshot(
                importedSources = com.pillyliu.pinprofandroid.library.ImportedSourcesStore.load(context),
                sourceState = LibrarySourceStateStore.load(context),
            ),
        )
        markLocalSourceReloadSuppression()
        LibrarySourceEvents.notifyChanged()
    }

    fun toggleEnabled(sourceId: String, isEnabled: Boolean) {
        LibrarySourceStateStore.setEnabled(context, sourceId, isEnabled)
        afterSourceMutation()
        error = null
    }

    fun togglePinned(sourceId: String, isPinned: Boolean) {
        if (LibrarySourceStateStore.setPinned(context, sourceId, isPinned)) {
            afterSourceMutation()
            error = null
        } else {
            error = "Pinned sources are limited to ${LibrarySourceStateStore.MAX_PINNED_SOURCES}."
        }
    }

    fun addManufacturer(manufacturer: CatalogManufacturerOption) {
        completeSourceMutation(addManufacturerSource(context, manufacturer), returnHome = true)
    }

    fun addVenue(
        result: com.pillyliu.pinprofandroid.library.LibraryVenueSearchResult,
        machineIds: List<String>,
        query: String,
        radiusMiles: Int,
    ) {
        completeSourceMutation(addVenueSource(context, result, machineIds, query, radiusMiles), returnHome = true)
    }

    fun addTournament(result: MatchPlayTournamentImportResult) {
        completeSourceMutation(addTournamentSource(context, result), returnHome = true)
    }

    fun deleteSource(sourceId: String) {
        completeSourceMutation(removeSettingsSource(context, sourceId))
    }

    suspend fun refreshSource(source: ImportedSourceRecord) {
        when (source.type) {
            LibrarySourceType.VENUE -> refreshImportedSource(
                source = source,
                expectedType = LibrarySourceType.VENUE,
                failurePrefix = "Venue refresh failed",
            ) { refreshVenueSource(context, it) }

            LibrarySourceType.TOURNAMENT -> refreshImportedSource(
                source = source,
                expectedType = LibrarySourceType.TOURNAMENT,
                failurePrefix = "Tournament refresh failed",
            ) { refreshTournamentSource(context, it) }

            else -> Unit
        }
    }

    suspend fun refreshHostedLibraryData() {
        if (refreshingHostedData) return
        refreshingHostedData = true
        hostedDataStatusMessage = null
        hostedDataStatusIsError = false
        runCatching { forceRefreshHostedSettingsData(context) }
            .onSuccess { snapshot ->
                markLocalSourceReloadSuppression()
                applySnapshot(snapshot)
                hostedDataStatusMessage = "Pinball data refreshed from pillyliu.com."
                hostedDataStatusIsError = false
            }.onFailure {
                hostedDataStatusMessage = "Hosted data refresh failed: ${it.message ?: "Unknown error"}"
                hostedDataStatusIsError = true
            }
        refreshingHostedData = false
    }

    suspend fun clearCachedData() {
        if (clearingCache) return
        clearingCache = true
        cacheStatusMessage = null
        cacheStatusIsError = false
        runCatching {
            clearAppRuntimeCaches(context)
        }.onSuccess {
            cacheStatusMessage = "Cached data cleared. Hosted data will refetch as screens reload."
            cacheStatusIsError = false
        }.onFailure {
            cacheStatusMessage = "Cache clear failed: ${it.message ?: "Unknown error"}"
            cacheStatusIsError = true
        }
        clearingCache = false
    }

    fun consumePendingSourceReloadSuppression(): Boolean {
        if (pendingLocalSourceReloadSuppressions <= 0) return false
        pendingLocalSourceReloadSuppressions -= 1
        return true
    }
}

@Composable
internal fun rememberSettingsScreenState(
    context: Context,
): SettingsScreenState = remember(context) {
    SettingsScreenState(context)
}
