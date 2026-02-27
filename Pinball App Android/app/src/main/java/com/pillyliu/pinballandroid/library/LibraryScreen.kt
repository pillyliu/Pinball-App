package com.pillyliu.pinballandroid.library

import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.core.content.edit
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.practice.KEY_LIBRARY_LAST_VIEWED_SLUG
import com.pillyliu.pinballandroid.practice.KEY_LIBRARY_LAST_VIEWED_TS
import com.pillyliu.pinballandroid.practice.KEY_PREFERRED_LIBRARY_SOURCE_ID
import com.pillyliu.pinballandroid.practice.practiceSharedPreferences
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.EmptyLabel
import com.pillyliu.pinballandroid.ui.LocalBottomBarVisible
import com.pillyliu.pinballandroid.ui.iosEdgeSwipeBack
import androidx.compose.ui.platform.LocalContext


@Composable
internal fun LibraryScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val prefs = remember { practiceSharedPreferences(context) }
    val bottomBarVisible = LocalBottomBarVisible.current
    var games by remember { mutableStateOf(emptyList<PinballGame>()) }
    var sources by remember { mutableStateOf(emptyList<LibrarySource>()) }
    var selectedSourceId by rememberSaveable { mutableStateOf("the-avenue") }
    var query by rememberSaveable { mutableStateOf("") }
    var sortOptionName by rememberSaveable { mutableStateOf(LibrarySortOption.AREA.name) }
    var selectedBank by rememberSaveable { mutableStateOf<Int?>(null) }
    var routeKind by rememberSaveable { mutableStateOf(LibraryRouteKind.LIST) }
    var routeSlug by rememberSaveable { mutableStateOf<String?>(null) }
    var routeImageUrl by rememberSaveable { mutableStateOf<String?>(null) }
    val avenueSourceCandidates = remember { listOf("venue--the-avenue-cafe", "the-avenue") }

    val goBack: () -> Unit = {
        when (routeKind) {
            LibraryRouteKind.DETAIL -> {
                routeKind = LibraryRouteKind.LIST
                routeSlug = null
                routeImageUrl = null
            }
            LibraryRouteKind.RULESHEET, LibraryRouteKind.PLAYFIELD -> routeKind = LibraryRouteKind.DETAIL
            else -> {
                routeKind = LibraryRouteKind.LIST
                routeSlug = null
                routeImageUrl = null
            }
        }
    }
    BackHandler(enabled = routeKind != LibraryRouteKind.LIST) {
        goBack()
    }

    LaunchedEffect(Unit) {
        try {
            val cached = PinballDataCache.passthroughOrCachedText(LIBRARY_URL)
            val parsed = parseLibraryPayload(cached.text.orEmpty())
            games = parsed.games
            sources = parsed.sources
            val savedSourceId = prefs.getString(KEY_PREFERRED_LIBRARY_SOURCE_ID, null)
            val preferredSourceId = listOfNotNull(savedSourceId, selectedSourceId)
                .plus(avenueSourceCandidates)
                .firstOrNull { candidate -> parsed.sources.any { it.id == candidate } }
            val chosenSource = parsed.sources.firstOrNull { it.id == preferredSourceId } ?: parsed.sources.firstOrNull()
            if (chosenSource != null) {
                selectedSourceId = chosenSource.id
                prefs.edit { putString(KEY_PREFERRED_LIBRARY_SOURCE_ID, chosenSource.id) }
                val sourceGames = parsed.games.filter { it.sourceId == chosenSource.id }
                val options = sortOptionsForSource(chosenSource, sourceGames)
                if (options.none { it.name == sortOptionName }) {
                    sortOptionName = (chosenSource.defaultSortOption.takeIf { options.contains(it) } ?: options.first()).name
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
    LaunchedEffect(routeKind) {
        if (routeKind != LibraryRouteKind.PLAYFIELD) {
            bottomBarVisible.value = true
        }
    }

    val routeGame = routeSlug?.let { slug -> games.firstOrNull { it.slug == slug } }

    androidx.compose.foundation.layout.Box(
        modifier = Modifier.iosEdgeSwipeBack(enabled = routeKind != LibraryRouteKind.LIST, onBack = goBack),
    ) {
        when (routeKind) {
        LibraryRouteKind.LIST -> LibraryList(
            contentPadding = contentPadding,
            games = games,
            sources = sources,
            selectedSourceId = selectedSourceId,
            query = query,
            sortOptionName = sortOptionName,
            selectedBank = selectedBank,
            onSourceChange = { sourceId ->
                selectedSourceId = sourceId
                prefs.edit { putString(KEY_PREFERRED_LIBRARY_SOURCE_ID, sourceId) }
                val source = sources.firstOrNull { it.id == sourceId }
                if (source != null) {
                    val sourceGames = games.filter { it.sourceId == source.id }
                    val options = sortOptionsForSource(source, sourceGames)
                    sortOptionName = (source.defaultSortOption.takeIf { options.contains(it) } ?: options.first()).name
                }
                selectedBank = null
            },
            onQueryChange = { query = it },
            onSortOptionChange = { sortOptionName = it },
            onBankChange = { selectedBank = it },
            onOpenGame = {
                routeSlug = it.slug
                routeKind = LibraryRouteKind.DETAIL
                LibraryActivityLog.log(context, it.slug, it.name, LibraryActivityKind.BrowseGame)
                prefs.edit {
                    putString(KEY_LIBRARY_LAST_VIEWED_SLUG, it.slug)
                    putLong(KEY_LIBRARY_LAST_VIEWED_TS, System.currentTimeMillis())
                }
            },
        )

        LibraryRouteKind.DETAIL -> {
            if (routeGame == null) {
                if (games.isEmpty()) {
                    AppScreen(contentPadding) { }
                } else {
                    AppScreen(contentPadding) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            EmptyLabel("Game not found.")
                            Button(onClick = {
                                routeKind = LibraryRouteKind.LIST
                                routeSlug = null
                                routeImageUrl = null
                            }) {
                                Text("Back to Library")
                            }
                        }
                    }
                }
            } else {
                LibraryDetailScreen(
                    contentPadding = contentPadding,
                    game = routeGame,
                    onBack = {
                        routeKind = LibraryRouteKind.LIST
                        routeSlug = null
                        routeImageUrl = null
                    },
                onOpenRulesheet = {
                    if (routeGame.rulesheetLocal.isNullOrBlank()) return@LibraryDetailScreen
                    LibraryActivityLog.log(context, routeGame.slug, routeGame.name, LibraryActivityKind.OpenRulesheet)
                    routeKind = LibraryRouteKind.RULESHEET
                },
                    onOpenPlayfield = { imageUrl ->
                        LibraryActivityLog.log(context, routeGame.slug, routeGame.name, LibraryActivityKind.OpenPlayfield)
                        routeImageUrl = imageUrl
                        routeKind = LibraryRouteKind.PLAYFIELD
                    },
                )
            }
        }

        LibraryRouteKind.RULESHEET -> {
            if (routeGame == null) {
                if (games.isEmpty()) {
                    AppScreen(contentPadding) { }
                } else {
                    AppScreen(contentPadding) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            EmptyLabel("Rulesheet game not found.")
                            Button(onClick = {
                                routeKind = LibraryRouteKind.LIST
                                routeSlug = null
                                routeImageUrl = null
                            }) {
                                Text("Back to Library")
                            }
                        }
                    }
                }
            } else {
                RulesheetScreen(
                    contentPadding = contentPadding,
                    slug = routeGame.slug,
                    remoteCandidates = listOfNotNull(
                        routeGame.rulesheetLocal?.let { "https://pillyliu.com$it" },
                        routeGame.practiceIdentity?.let { "https://pillyliu.com/pinball/rulesheets/${it}-rulesheet.md" },
                        "https://pillyliu.com/pinball/rulesheets/${routeGame.slug}.md",
                    ).distinct(),
                    onBack = { routeKind = LibraryRouteKind.DETAIL },
                )
            }
        }

        LibraryRouteKind.PLAYFIELD -> {
            if (routeGame == null) {
                if (games.isEmpty()) {
                    AppScreen(contentPadding) { }
                } else {
                    AppScreen(contentPadding) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            EmptyLabel("Playfield game not found.")
                            Button(onClick = {
                                routeKind = LibraryRouteKind.LIST
                                routeSlug = null
                                routeImageUrl = null
                            }) {
                                Text("Back to Library")
                            }
                        }
                    }
                }
            } else {
                val imageCandidates = (
                    listOfNotNull(routeImageUrl) +
                        routeGame.fullscreenPlayfieldCandidates()
                    ).filter { it.isNotBlank() }
                    .distinct()
                PlayfieldScreen(
                    contentPadding = contentPadding,
                    title = routeGame.name,
                    imageUrls = imageCandidates,
                    onBack = { routeKind = LibraryRouteKind.DETAIL },
                )
            }
        }

    }
    }
}
