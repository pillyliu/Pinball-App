package com.pillyliu.pinprofandroid.settings

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption
import com.pillyliu.pinprofandroid.library.ImportedSourceRecord
import com.pillyliu.pinprofandroid.library.ImportedSourcesStore
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.LibrarySourceEvents
import com.pillyliu.pinprofandroid.library.LibrarySourceState
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore
import com.pillyliu.pinprofandroid.library.LibrarySourceType
import kotlinx.coroutines.launch

sealed interface SettingsRoute {
    data object Home : SettingsRoute
    data object AddManufacturer : SettingsRoute
    data object AddVenue : SettingsRoute
    data object AddTournament : SettingsRoute
}

@Composable
internal fun SettingsScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val builtinSources = remember {
        listOf(
            LibrarySource(id = "venue--rlm-amusements", name = "RLM Amusements", type = LibrarySourceType.VENUE),
            LibrarySource(id = "venue--the-avenue-cafe", name = "The Avenue Cafe", type = LibrarySourceType.VENUE),
        )
    }
    var route by remember { mutableStateOf<SettingsRoute>(SettingsRoute.Home) }
    val sourceVersion by LibrarySourceEvents.version.collectAsState()
    var manufacturers by remember { mutableStateOf<List<CatalogManufacturerOption>>(emptyList()) }
    var importedSources by remember { mutableStateOf<List<ImportedSourceRecord>>(emptyList()) }
    var sourceState by remember { mutableStateOf(LibrarySourceState()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var refreshingHostedData by remember { mutableStateOf(false) }
    var hostedDataStatusMessage by remember { mutableStateOf<String?>(null) }
    var hostedDataStatusIsError by remember { mutableStateOf(false) }

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

    fun refreshHostedLibraryData() {
        if (refreshingHostedData) return
        scope.launch {
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
    }

    LaunchedEffect(Unit) {
        reload()
    }
    LaunchedEffect(sourceVersion) {
        if (sourceVersion != 0L) {
            reload()
        }
    }

    when (route) {
        SettingsRoute.AddManufacturer -> {
            AddManufacturerScreen(
                contentPadding = contentPadding,
                manufacturers = manufacturers,
                onBack = { route = SettingsRoute.Home },
                onAdd = { manufacturer ->
                    applySourceSnapshot(addManufacturerSource(context, manufacturer))
                    route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.AddVenue -> {
            AddVenueScreen(
                contentPadding = contentPadding,
                onBack = { route = SettingsRoute.Home },
                onImport = { result, machineIds, query, radiusMiles ->
                    applySourceSnapshot(addVenueSource(context, result, machineIds, query, radiusMiles))
                    route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.AddTournament -> {
            AddTournamentScreen(
                contentPadding = contentPadding,
                onBack = { route = SettingsRoute.Home },
                onImport = { result ->
                    applySourceSnapshot(addTournamentSource(context, result))
                    route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.Home -> Unit
    }

    SettingsHomeContent(
        builtinSources = builtinSources,
        manufacturers = manufacturers,
        importedSources = importedSources,
        sourceState = sourceState,
        loading = loading,
        error = error,
        refreshingHostedData = refreshingHostedData,
        hostedDataStatusMessage = hostedDataStatusMessage,
        hostedDataStatusIsError = hostedDataStatusIsError,
        onOpenAddManufacturer = { route = SettingsRoute.AddManufacturer },
        onOpenAddVenue = { route = SettingsRoute.AddVenue },
        onOpenAddTournament = { route = SettingsRoute.AddTournament },
        onToggleEnabled = { sourceId, isEnabled ->
            LibrarySourceStateStore.setEnabled(context, sourceId, isEnabled)
            afterSourceMutation()
        },
        onTogglePinned = { sourceId, isPinned ->
            if (LibrarySourceStateStore.setPinned(context, sourceId, isPinned)) {
                afterSourceMutation()
            } else {
                error = "Pinned sources are limited to ${LibrarySourceStateStore.MAX_PINNED_SOURCES}."
            }
        },
        onRefreshSource = { source ->
            scope.launch {
                when (source.type) {
                    LibrarySourceType.VENUE -> {
                        runCatching { refreshVenueSource(context, source) }
                            .onSuccess(::applySourceSnapshot)
                            .onFailure {
                                error = "Venue refresh failed: ${it.message ?: "Unknown error"}"
                            }
                    }

                    LibrarySourceType.TOURNAMENT -> {
                        runCatching { refreshTournamentSource(context, source) }
                            .onSuccess(::applySourceSnapshot)
                            .onFailure {
                                error = "Tournament refresh failed: ${it.message ?: "Unknown error"}"
                            }
                    }

                    else -> Unit
                }
            }
        },
        onDeleteSource = { sourceId ->
            applySourceSnapshot(removeSettingsSource(context, sourceId))
        },
        onRefreshHostedData = ::refreshHostedLibraryData,
    )
}
