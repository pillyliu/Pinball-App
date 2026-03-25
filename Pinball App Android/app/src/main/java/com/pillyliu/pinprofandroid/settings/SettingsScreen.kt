package com.pillyliu.pinprofandroid.settings

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.data.toggleShowAppIntroOverlayOnNextLaunch
import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.LibrarySourceEvents
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore
import com.pillyliu.pinprofandroid.library.LibrarySourceType
import com.pillyliu.pinprofandroid.library.builtinVenueSources
import com.pillyliu.pinprofandroid.ui.AppSuccessBanner
import com.pillyliu.pinprofandroid.ui.AppScreen
import kotlinx.coroutines.delay
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
    val state = rememberSettingsScreenState(context)
    var introOverlayToggleMessage by remember { mutableStateOf<String?>(null) }
    val builtinSources = remember {
        builtinVenueSources()
    }
    val sourceVersion by LibrarySourceEvents.version.collectAsState()

    LaunchedEffect(Unit) {
        state.reload()
    }
    LaunchedEffect(sourceVersion) {
        if (sourceVersion != 0L) {
            state.reload()
        }
    }
    LaunchedEffect(introOverlayToggleMessage) {
        if (introOverlayToggleMessage != null) {
            delay(1_200L)
            introOverlayToggleMessage = null
        }
    }

    when (state.route) {
        SettingsRoute.AddManufacturer -> {
            AddManufacturerScreen(
                contentPadding = contentPadding,
                manufacturers = state.manufacturers,
                onBack = { state.route = SettingsRoute.Home },
                onAdd = { manufacturer ->
                    state.applySourceSnapshot(addManufacturerSource(context, manufacturer))
                    state.route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.AddVenue -> {
            AddVenueScreen(
                contentPadding = contentPadding,
                onBack = { state.route = SettingsRoute.Home },
                onImport = { result, machineIds, query, radiusMiles ->
                    state.applySourceSnapshot(addVenueSource(context, result, machineIds, query, radiusMiles))
                    state.route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.AddTournament -> {
            AddTournamentScreen(
                contentPadding = contentPadding,
                onBack = { state.route = SettingsRoute.Home },
                onImport = { result ->
                    state.applySourceSnapshot(addTournamentSource(context, result))
                    state.route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.Home -> Unit
    }

    AppScreen(contentPadding) {
        Box(modifier = Modifier.fillMaxSize()) {
            SettingsHomeContent(
                builtinSources = builtinSources,
                manufacturers = state.manufacturers,
                importedSources = state.importedSources,
                sourceState = state.sourceState,
                loading = state.loading,
                error = state.error,
                refreshingHostedData = state.refreshingHostedData,
                hostedDataStatusMessage = state.hostedDataStatusMessage,
                hostedDataStatusIsError = state.hostedDataStatusIsError,
                clearingCache = state.clearingCache,
                cacheStatusMessage = state.cacheStatusMessage,
                cacheStatusIsError = state.cacheStatusIsError,
                onOpenAddManufacturer = { state.route = SettingsRoute.AddManufacturer },
                onOpenAddVenue = { state.route = SettingsRoute.AddVenue },
                onOpenAddTournament = { state.route = SettingsRoute.AddTournament },
                onToggleEnabled = { sourceId, isEnabled ->
                    LibrarySourceStateStore.setEnabled(context, sourceId, isEnabled)
                    state.afterSourceMutation()
                },
                onTogglePinned = { sourceId, isPinned ->
                    if (LibrarySourceStateStore.setPinned(context, sourceId, isPinned)) {
                        state.afterSourceMutation()
                    } else {
                        state.error = "Pinned sources are limited to ${LibrarySourceStateStore.MAX_PINNED_SOURCES}."
                    }
                },
                onRefreshSource = { source ->
                    scope.launch {
                        when (source.type) {
                            LibrarySourceType.VENUE -> {
                                runCatching { refreshVenueSource(context, source) }
                                    .onSuccess(state::applySourceSnapshot)
                                    .onFailure {
                                        state.error = "Venue refresh failed: ${it.message ?: "Unknown error"}"
                                    }
                            }

                            LibrarySourceType.TOURNAMENT -> {
                                runCatching { refreshTournamentSource(context, source) }
                                    .onSuccess(state::applySourceSnapshot)
                                    .onFailure {
                                        state.error = "Tournament refresh failed: ${it.message ?: "Unknown error"}"
                                    }
                            }

                            else -> Unit
                        }
                    }
                },
                onDeleteSource = { sourceId ->
                    state.applySourceSnapshot(removeSettingsSource(context, sourceId))
                },
                onRefreshHostedData = {
                    scope.launch { state.refreshHostedLibraryData() }
                },
                onClearCache = {
                    scope.launch { state.clearCachedData() }
                },
                onToggleIntroOverlayForNextLaunch = {
                    val enabled = toggleShowAppIntroOverlayOnNextLaunch(context)
                    introOverlayToggleMessage = if (enabled) {
                        "Intro enabled for next launch"
                    } else {
                        "Intro disabled for next launch"
                    }
                },
            )

            AnimatedVisibility(
                visible = introOverlayToggleMessage != null,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 4.dp),
                enter = fadeIn(animationSpec = tween(durationMillis = 250)),
                exit = fadeOut(animationSpec = tween(durationMillis = 250)),
            ) {
                introOverlayToggleMessage?.let { message ->
                    AppSuccessBanner(text = message)
                }
            }
        }
    }
}
