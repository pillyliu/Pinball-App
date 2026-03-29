package com.pillyliu.pinprofandroid.library

import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.ScrollState
import androidx.compose.runtime.collectAsState
import androidx.core.content.edit
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.pillyliu.pinprofandroid.practice.KEY_LIBRARY_LAST_VIEWED_SLUG
import com.pillyliu.pinprofandroid.practice.KEY_LIBRARY_LAST_VIEWED_TS
import com.pillyliu.pinprofandroid.practice.practiceSharedPreferences
import com.pillyliu.pinprofandroid.ui.LocalBottomBarVisible
import com.pillyliu.pinprofandroid.ui.iosEdgeSwipeBack
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.launch

@Composable
internal fun LibraryScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val prefs = remember { practiceSharedPreferences(context) }
    val bottomBarVisible = LocalBottomBarVisible.current
    val sourceVersion by LibrarySourceEvents.version.collectAsState()
    var games by remember { mutableStateOf(emptyList<PinballGame>()) }
    var sources by remember { mutableStateOf(emptyList<LibrarySource>()) }
    var sourceState by remember { mutableStateOf(LibrarySourceState()) }
    var selectedSourceId by rememberSaveable { mutableStateOf("") }
    var query by rememberSaveable { mutableStateOf("") }
    var sortOptionName by rememberSaveable { mutableStateOf(LibrarySortOption.AREA.name) }
    var yearSortDescending by rememberSaveable { mutableStateOf(false) }
    var selectedBank by rememberSaveable { mutableStateOf<Int?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var route by rememberSaveable(stateSaver = LibraryRouteSaver) { mutableStateOf<LibraryRoute>(LibraryRoute.List) }
    var listVisibleCount by rememberSaveable { mutableIntStateOf(48) }
    val listScrollState = rememberSaveable(saver = ScrollState.Saver) { ScrollState(0) }
    val scope = rememberCoroutineScope()
    val pinnedSourceIds = sourceState.pinnedSourceIds
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
            is LibraryRoute.Rulesheet -> LibraryRoute.Detail(current.gameId)
            is LibraryRoute.ExternalRulesheet -> LibraryRoute.Detail(current.gameId)
            is LibraryRoute.Playfield -> LibraryRoute.Detail(current.gameId)
        }
    }
    BackHandler(enabled = route != LibraryRoute.List) {
        goBack()
    }

    suspend fun reloadLibrary() {
        isLoading = true
        errorMessage = null
        try {
            val loadedState = loadLibraryScreenState(
                context = context,
                currentSelectedSourceId = selectedSourceId,
            )
            games = loadedState.games
            sources = loadedState.sources
            sourceState = loadedState.sourceState
            loadedState.selection?.let { resolution ->
                selectedSourceId = resolution.selectedSourceId
                sortOptionName = resolution.sortOptionName
                yearSortDescending = resolution.yearSortDescending
                selectedBank = resolution.selectedBank
                sourceState = persistLibraryScreenSelection(
                    context = context,
                    sourceState = loadedState.sourceState,
                    selection = resolution,
                )
            }
        } catch (t: Throwable) {
            games = emptyList()
            sources = emptyList()
            sourceState = LibrarySourceState()
            errorMessage = t.message ?: "Failed to load pinball library."
        } finally {
            isLoading = false
        }
    }

    fun resetListBrowsePosition() {
        listVisibleCount = 48
        scope.launch {
            listScrollState.scrollTo(0)
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

    val routeGame = route.gameId?.let { gameId -> games.firstOrNull { it.libraryRouteId == gameId } }

    androidx.compose.foundation.layout.Box(
        modifier = Modifier.iosEdgeSwipeBack(enabled = route != LibraryRoute.List, onBack = goBack),
    ) {
        LibraryRouteContent(
            contentPadding = contentPadding,
            games = games,
            isLoading = isLoading,
            errorMessage = errorMessage,
            browseState = browseState,
            listVisibleCount = listVisibleCount,
            onListVisibleCountChange = { listVisibleCount = it },
            listScrollState = listScrollState,
            route = route,
            routeGame = routeGame,
            onSourceChange = { sourceId ->
                resolveLibraryScreenSourceSelection(
                    sourceId = sourceId,
                    sources = sources,
                    games = games,
                    sourceState = sourceState,
                )?.let { resolution ->
                    selectedSourceId = resolution.selectedSourceId
                    sortOptionName = resolution.sortOptionName
                    yearSortDescending = resolution.yearSortDescending
                    selectedBank = resolution.selectedBank
                    sourceState = persistLibraryScreenSelection(
                        context = context,
                        sourceState = sourceState,
                        selection = resolution,
                    )
                    resetListBrowsePosition()
                }
            },
            onQueryChange = {
                query = it
                resetListBrowsePosition()
            },
            onSortOptionChange = { sortName ->
                if (sortName == "YEAR_DESC") {
                    sortOptionName = LibrarySortOption.YEAR.name
                    yearSortDescending = true
                } else {
                    sortOptionName = sortName
                    yearSortDescending = false
                }
                val persistedSelection = persistLibraryScreenSortSelection(
                    context = context,
                    sourceState = sourceState,
                    sourceId = selectedSourceId,
                    sortOptionName = sortOptionName,
                    yearSortDescending = yearSortDescending,
                )
                sortOptionName = persistedSelection.sortOptionName
                yearSortDescending = persistedSelection.yearSortDescending
                sourceState = persistedSelection.sourceState
                resetListBrowsePosition()
            },
            onBankChange = {
                selectedBank = it
                if (selectedSourceId.isNotBlank()) {
                    sourceState = persistLibraryScreenBankSelection(
                        context = context,
                        sourceState = sourceState,
                        sourceId = selectedSourceId,
                        selectedBank = it,
                    )
                }
                resetListBrowsePosition()
            },
            onOpenGame = {
                route = LibraryRoute.Detail(it.libraryRouteId)
                LibraryActivityLog.log(context, it.libraryRouteId, it.name, LibraryActivityKind.BrowseGame)
                prefs.edit {
                    putString(KEY_LIBRARY_LAST_VIEWED_SLUG, it.libraryRouteId)
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
                    game.libraryRouteId,
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
                    gameId = game.libraryRouteId,
                    sourceProvider = provider,
                    sourceUrl = source?.url,
                )
            },
            onShowExternalRulesheet = { url, detail ->
                val game = routeGame ?: return@LibraryRouteContent
                LibraryActivityLog.log(
                    context,
                    game.libraryRouteId,
                    game.name,
                    LibraryActivityKind.OpenRulesheet,
                    detail,
                )
                route = LibraryRoute.ExternalRulesheet(game.libraryRouteId, url)
            },
            onShowPlayfield = { imageUrls ->
                val game = routeGame ?: return@LibraryRouteContent
                LibraryActivityLog.log(context, game.libraryRouteId, game.name, LibraryActivityKind.OpenPlayfield)
                route = LibraryRoute.Playfield(game.libraryRouteId, imageUrls)
            },
            onBackToDetail = {
                val game = routeGame ?: return@LibraryRouteContent
                route = LibraryRoute.Detail(game.libraryRouteId)
            },
        )
    }
}
