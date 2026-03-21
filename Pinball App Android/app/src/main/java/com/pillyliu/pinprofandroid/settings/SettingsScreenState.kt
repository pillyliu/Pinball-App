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
import com.pillyliu.pinprofandroid.library.ImportedSourcesStore
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

    fun applySnapshot(snapshot: SettingsDataSnapshot) {
        manufacturers = snapshot.manufacturers
        importedSources = snapshot.importedSources
        sourceState = snapshot.sourceState
    }

    fun applySourceSnapshot(snapshot: SettingsSourceSnapshot) {
        importedSources = snapshot.importedSources
        sourceState = snapshot.sourceState
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
                importedSources = ImportedSourcesStore.load(context),
                sourceState = LibrarySourceStateStore.load(context),
            ),
        )
        LibrarySourceEvents.notifyChanged()
    }

    suspend fun refreshHostedLibraryData() {
        if (refreshingHostedData) return
        refreshingHostedData = true
        hostedDataStatusMessage = null
        hostedDataStatusIsError = false
        runCatching { forceRefreshHostedSettingsData(context) }
            .onSuccess { snapshot ->
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
}

@Composable
internal fun rememberSettingsScreenState(
    context: Context,
): SettingsScreenState = remember(context) {
    SettingsScreenState(context)
}
