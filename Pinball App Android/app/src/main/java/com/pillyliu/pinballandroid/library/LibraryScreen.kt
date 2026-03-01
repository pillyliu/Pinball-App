package com.pillyliu.pinballandroid.library

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
import com.pillyliu.pinballandroid.practice.KEY_LIBRARY_LAST_VIEWED_SLUG
import com.pillyliu.pinballandroid.practice.KEY_LIBRARY_LAST_VIEWED_TS
import com.pillyliu.pinballandroid.practice.KEY_PREFERRED_LIBRARY_SOURCE_ID
import com.pillyliu.pinballandroid.practice.practiceSharedPreferences
import com.pillyliu.pinballandroid.ui.LocalBottomBarVisible
import com.pillyliu.pinballandroid.ui.iosEdgeSwipeBack
import androidx.compose.ui.platform.LocalContext


@Composable
internal fun LibraryScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val prefs = remember { practiceSharedPreferences(context) }
    val bottomBarVisible = LocalBottomBarVisible.current
    val sourceVersion by LibrarySourceEvents.version.collectAsState()
    var games by remember { mutableStateOf(emptyList<PinballGame>()) }
    var sources by remember { mutableStateOf(emptyList<LibrarySource>()) }
    var selectedSourceId by rememberSaveable { mutableStateOf("the-avenue") }
    var query by rememberSaveable { mutableStateOf("") }
    var sortOptionName by rememberSaveable { mutableStateOf(LibrarySortOption.AREA.name) }
    var yearSortDescending by rememberSaveable { mutableStateOf(false) }
    var selectedBank by rememberSaveable { mutableStateOf<Int?>(null) }
    var route by rememberSaveable(stateSaver = LibraryRouteSaver) { mutableStateOf<LibraryRoute>(LibraryRoute.List) }
    val avenueSourceCandidates = remember { listOf("venue--the-avenue-cafe", "the-avenue") }
    val visibleSources = remember(sources, selectedSourceId, sourceVersion) {
        val state = LibrarySourceStateStore.load(context)
        val pinned = state.pinnedSourceIds.mapNotNull { pinnedId -> sources.firstOrNull { it.id == pinnedId } }
        if (pinned.isEmpty()) {
            sources
        } else {
            val selected = sources.firstOrNull { it.id == selectedSourceId }
            if (selected != null && pinned.none { it.id == selected.id }) {
                pinned + selected
            } else {
                pinned
            }
        }
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
        try {
            val extraction = loadLibraryExtraction(context)
            val payload = extraction.payload
            val sourceState = extraction.state
            games = payload.games
            sources = payload.sources
            val savedSourceId = prefs.getString(KEY_PREFERRED_LIBRARY_SOURCE_ID, null)
            val preferredSourceId = listOfNotNull(sourceState.selectedSourceId, savedSourceId, selectedSourceId)
                .plus(avenueSourceCandidates)
                .firstOrNull { candidate -> payload.sources.any { it.id == candidate } }
            val chosenSource = payload.sources.firstOrNull { it.id == preferredSourceId } ?: payload.sources.firstOrNull()
            if (chosenSource != null) {
                selectedSourceId = chosenSource.id
                prefs.edit { putString(KEY_PREFERRED_LIBRARY_SOURCE_ID, chosenSource.id) }
                LibrarySourceStateStore.setSelectedSource(context, chosenSource.id)
                val sourceGames = payload.games.filter { it.sourceId == chosenSource.id }
                val options = sortOptionsForSource(chosenSource, sourceGames)
                val persistedSort = sourceState.selectedSortBySource[chosenSource.id]
                val normalizedSort = when (persistedSort) {
                    "YEAR_DESC" -> {
                        yearSortDescending = true
                        LibrarySortOption.YEAR.name
                    }
                    null -> null
                    else -> {
                        yearSortDescending = false
                        persistedSort
                    }
                }
                if (chosenSource.type == LibrarySourceType.MANUFACTURER) {
                    sortOptionName = LibrarySortOption.YEAR.name
                    yearSortDescending = true
                } else if (normalizedSort != null && options.any { it.name == normalizedSort }) {
                    sortOptionName = normalizedSort
                    yearSortDescending = normalizedSort == LibrarySortOption.YEAR.name && persistedSort == "YEAR_DESC"
                } else {
                    val defaultSort = preferredDefaultSortOption(chosenSource, sourceGames)
                    sortOptionName = (defaultSort.takeIf { options.contains(it) } ?: options.first()).name
                    yearSortDescending = preferredDefaultYearSortDescending(chosenSource, sourceGames)
                }
                val persistedBank = sourceState.selectedBankBySource[chosenSource.id]
                selectedBank = if (chosenSource.type == LibrarySourceType.VENUE && sourceGames.any { (it.bank ?: 0) > 0 }) {
                    persistedBank
                } else {
                    null
                }
                if (chosenSource.type != LibrarySourceType.VENUE || sourceGames.none { (it.bank ?: 0) > 0 }) {
                    selectedBank = null
                }
            }
        } catch (t: Throwable) {
            games = emptyList()
            sources = emptyList()
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
            visibleSources = visibleSources,
            selectedSourceId = selectedSourceId,
            query = query,
            sortOptionName = sortOptionName,
            yearSortDescending = yearSortDescending,
            selectedBank = selectedBank,
            route = route,
            routeGame = routeGame,
            onSourceChange = { sourceId ->
                selectedSourceId = sourceId
                prefs.edit { putString(KEY_PREFERRED_LIBRARY_SOURCE_ID, sourceId) }
                LibrarySourceStateStore.setSelectedSource(context, sourceId)
                val source = sources.firstOrNull { it.id == sourceId }
                if (source != null) {
                    val sourceGames = games.filter { it.sourceId == source.id }
                    val options = sortOptionsForSource(source, sourceGames)
                    val persistedSort = LibrarySourceStateStore.load(context).selectedSortBySource[source.id]
                    if (source.type == LibrarySourceType.MANUFACTURER) {
                        sortOptionName = LibrarySortOption.YEAR.name
                        yearSortDescending = true
                    } else if (persistedSort == "YEAR_DESC") {
                        sortOptionName = LibrarySortOption.YEAR.name
                        yearSortDescending = true
                    } else if (persistedSort != null && options.any { it.name == persistedSort }) {
                        sortOptionName = persistedSort
                        yearSortDescending = false
                    } else {
                        val defaultSort = preferredDefaultSortOption(source, sourceGames)
                        sortOptionName = (defaultSort.takeIf { options.contains(it) }?.name ?: options.first().name)
                        yearSortDescending = preferredDefaultYearSortDescending(source, sourceGames)
                    }
                }
                selectedBank = LibrarySourceStateStore.load(context).selectedBankBySource[sourceId]
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
            onShowRulesheet = { source ->
                val game = routeGame ?: return@LibraryRouteContent
                LibraryActivityLog.log(context, game.slug, game.name, LibraryActivityKind.OpenRulesheet, source?.sourceName)
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
            onShowExternalRulesheet = { url ->
                val game = routeGame ?: return@LibraryRouteContent
                route = LibraryRoute.ExternalRulesheet(game.slug, url)
            },
            onShowPlayfield = { imageUrl ->
                val game = routeGame ?: return@LibraryRouteContent
                LibraryActivityLog.log(context, game.slug, game.name, LibraryActivityKind.OpenPlayfield)
                route = LibraryRoute.Playfield(game.slug, imageUrl)
            },
            onBackToDetail = {
                val game = routeGame ?: return@LibraryRouteContent
                route = LibraryRoute.Detail(game.slug)
            },
        )
    }
}

private fun preferredDefaultSortOption(source: LibrarySource, games: List<PinballGame>): LibrarySortOption {
    return when (source.type) {
        LibrarySourceType.MANUFACTURER -> LibrarySortOption.YEAR
        LibrarySourceType.CATEGORY -> LibrarySortOption.ALPHABETICAL
        LibrarySourceType.VENUE -> {
            val hasArea = games.any {
                val area = it.area?.trim()
                !area.isNullOrEmpty() && !area.equals("null", ignoreCase = true)
            }
            if (hasArea) LibrarySortOption.AREA else LibrarySortOption.ALPHABETICAL
        }
    }
}

private fun preferredDefaultYearSortDescending(source: LibrarySource, games: List<PinballGame>): Boolean =
    source.type == LibrarySourceType.MANUFACTURER && preferredDefaultSortOption(source, games) == LibrarySortOption.YEAR
