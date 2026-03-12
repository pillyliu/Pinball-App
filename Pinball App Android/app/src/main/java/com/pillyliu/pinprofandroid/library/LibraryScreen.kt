package com.pillyliu.pinprofandroid.library

import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.compose.runtime.collectAsState
import androidx.core.content.edit
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.pillyliu.pinprofandroid.practice.KEY_LIBRARY_LAST_VIEWED_SLUG
import com.pillyliu.pinprofandroid.practice.KEY_LIBRARY_LAST_VIEWED_TS
import com.pillyliu.pinprofandroid.practice.KEY_PREFERRED_LIBRARY_SOURCE_ID
import com.pillyliu.pinprofandroid.practice.practiceSharedPreferences
import com.pillyliu.pinprofandroid.ui.LocalBottomBarVisible
import com.pillyliu.pinprofandroid.ui.iosEdgeSwipeBack
import androidx.compose.ui.platform.LocalContext


@Composable
internal fun LibraryScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val prefs = remember { practiceSharedPreferences(context) }
    val bottomBarVisible = LocalBottomBarVisible.current
    val sourceVersion by LibrarySourceEvents.version.collectAsState()
    var games by remember { mutableStateOf(emptyList<PinballGame>()) }
    var sources by remember { mutableStateOf(emptyList<LibrarySource>()) }
    var selectedSourceId by rememberSaveable { mutableStateOf("") }
    var query by rememberSaveable { mutableStateOf("") }
    var sortOptionName by rememberSaveable { mutableStateOf(LibrarySortOption.AREA.name) }
    var yearSortDescending by rememberSaveable { mutableStateOf(false) }
    var selectedBank by rememberSaveable { mutableStateOf<Int?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var route by rememberSaveable(stateSaver = LibraryRouteSaver) { mutableStateOf<LibraryRoute>(LibraryRoute.List) }
    val pinnedSourceIds = remember(sources, selectedSourceId, sourceVersion) {
        LibrarySourceStateStore.load(context).pinnedSourceIds
    }
    val browseState = remember(
        games,
        sources,
        selectedSourceId,
        query,
        sortOptionName,
        yearSortDescending,
        selectedBank,
        pinnedSourceIds,
    ) {
        LibraryBrowseState(
            games = games,
            sources = sources,
            selectedSourceId = selectedSourceId,
            query = query,
            sortOptionName = sortOptionName,
            yearSortDescending = yearSortDescending,
            selectedBank = selectedBank,
            pinnedSourceIds = pinnedSourceIds,
        )
    }

    val goBack: () -> Unit = {
        route = when (val current = route) {
            LibraryRoute.List -> LibraryRoute.List
            is LibraryRoute.Detail -> LibraryRoute.List
            is LibraryRoute.Rulesheet -> LibraryRoute.Detail(current.slug)
            is LibraryRoute.ExternalRulesheet -> LibraryRoute.Detail(current.slug)
            is LibraryRoute.Playfield -> LibraryRoute.Detail(current.slug)
        }
    }
    BackHandler(enabled = route != LibraryRoute.List) {
        goBack()
    }

    suspend fun reloadLibrary() {
        isLoading = true
        errorMessage = null
        try {
            val extraction = loadLibraryExtraction(context)
            val payload = extraction.payload
            val sourceState = extraction.state
            games = payload.games
            sources = payload.sources
            resolveLibrarySelection(
                payload = payload,
                sourceState = sourceState,
                savedSourceId = prefs.getString(KEY_PREFERRED_LIBRARY_SOURCE_ID, null),
                currentSelectedSourceId = selectedSourceId,
            )?.let { resolution ->
                selectedSourceId = resolution.selectedSourceId
                sortOptionName = resolution.sortOptionName
                yearSortDescending = resolution.yearSortDescending
                selectedBank = resolution.selectedBank
                prefs.edit { putString(KEY_PREFERRED_LIBRARY_SOURCE_ID, resolution.selectedSourceId) }
                LibrarySourceStateStore.setSelectedSource(context, resolution.selectedSourceId)
            }
        } catch (t: Throwable) {
            games = emptyList()
            sources = emptyList()
            errorMessage = t.message ?: "Failed to load pinball library."
        } finally {
            isLoading = false
        }
    }
    LaunchedEffect(Unit) {
        reloadLibrary()
    }
    LaunchedEffect(sourceVersion) {
        if (sourceVersion != 0L) {
            reloadLibrary()
        }
    }
    LaunchedEffect(route) {
        if (route !is LibraryRoute.Playfield) {
            bottomBarVisible.value = true
        }
    }

    val routeGame = route.slug?.let { slug -> games.firstOrNull { it.slug == slug } }

    androidx.compose.foundation.layout.Box(
        modifier = Modifier.iosEdgeSwipeBack(enabled = route != LibraryRoute.List, onBack = goBack),
    ) {
        LibraryRouteContent(
            contentPadding = contentPadding,
            games = games,
            isLoading = isLoading,
            errorMessage = errorMessage,
            browseState = browseState,
            route = route,
            routeGame = routeGame,
            onSourceChange = { sourceId ->
                val source = sources.firstOrNull { it.id == sourceId }
                if (source != null) {
                    val resolution = resolveLibrarySelectionForSource(
                        source = source,
                        games = games,
                        sourceState = LibrarySourceStateStore.load(context),
                    )
                    selectedSourceId = resolution.selectedSourceId
                    sortOptionName = resolution.sortOptionName
                    yearSortDescending = resolution.yearSortDescending
                    selectedBank = resolution.selectedBank
                    prefs.edit { putString(KEY_PREFERRED_LIBRARY_SOURCE_ID, resolution.selectedSourceId) }
                    LibrarySourceStateStore.setSelectedSource(context, resolution.selectedSourceId)
                }
            },
            onQueryChange = { query = it },
            onSortOptionChange = { sortName ->
                if (sortName == "YEAR_DESC") {
                    sortOptionName = LibrarySortOption.YEAR.name
                    yearSortDescending = true
                } else {
                    sortOptionName = sortName
                    yearSortDescending = false
                }
                val persisted = if (sortOptionName == LibrarySortOption.YEAR.name && yearSortDescending) "YEAR_DESC" else sortOptionName
                LibrarySourceStateStore.setSelectedSort(context, selectedSourceId, persisted)
            },
            onBankChange = {
                selectedBank = it
                if (selectedSourceId.isNotBlank()) {
                    LibrarySourceStateStore.setSelectedBank(context, selectedSourceId, it)
                }
            },
            onOpenGame = {
                route = LibraryRoute.Detail(it.slug)
                LibraryActivityLog.log(context, it.slug, it.name, LibraryActivityKind.BrowseGame)
                prefs.edit {
                    putString(KEY_LIBRARY_LAST_VIEWED_SLUG, it.slug)
                    putLong(KEY_LIBRARY_LAST_VIEWED_TS, System.currentTimeMillis())
                }
            },
            onBackToList = {
                route = LibraryRoute.List
            },
            onShowRulesheet = { source, detail ->
                val game = routeGame ?: return@LibraryRouteContent
                LibraryActivityLog.log(
                    context,
                    game.slug,
                    game.name,
                    LibraryActivityKind.OpenRulesheet,
                    detail ?: source?.sourceName,
                )
                val provider = when (source) {
                    is RulesheetRemoteSource.TiltForums -> "tiltforums"
                    is RulesheetRemoteSource.PinballPrimer -> "primer"
                    is RulesheetRemoteSource.BobsGuide -> "bob"
                    is RulesheetRemoteSource.Papa -> "papa"
                    null -> null
                }
                route = LibraryRoute.Rulesheet(
                    slug = game.slug,
                    sourceProvider = provider,
                    sourceUrl = source?.url,
                )
            },
            onShowExternalRulesheet = { url, detail ->
                val game = routeGame ?: return@LibraryRouteContent
                LibraryActivityLog.log(
                    context,
                    game.slug,
                    game.name,
                    LibraryActivityKind.OpenRulesheet,
                    detail,
                )
                route = LibraryRoute.ExternalRulesheet(game.slug, url)
            },
            onShowPlayfield = { imageUrls ->
                val game = routeGame ?: return@LibraryRouteContent
                LibraryActivityLog.log(context, game.slug, game.name, LibraryActivityKind.OpenPlayfield)
                route = LibraryRoute.Playfield(game.slug, imageUrls)
            },
            onBackToDetail = {
                val game = routeGame ?: return@LibraryRouteContent
                route = LibraryRoute.Detail(game.slug)
            },
        )
    }
}
