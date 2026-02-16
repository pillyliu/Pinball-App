package com.pillyliu.pinballandroid.library

import android.content.Context
import androidx.activity.compose.BackHandler
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
import com.pillyliu.pinballandroid.practice.LibraryActivityKind
import com.pillyliu.pinballandroid.practice.LibraryActivityLog
import com.pillyliu.pinballandroid.practice.PRACTICE_PREFS
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.EmptyLabel
import com.pillyliu.pinballandroid.ui.LocalBottomBarVisible
import com.pillyliu.pinballandroid.ui.iosEdgeSwipeBack
import androidx.compose.ui.platform.LocalContext
import org.json.JSONArray

@Composable
internal fun LibraryScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences(PRACTICE_PREFS, Context.MODE_PRIVATE) }
    val bottomBarVisible = LocalBottomBarVisible.current
    var games by remember { mutableStateOf(emptyList<PinballGame>()) }
    var query by rememberSaveable { mutableStateOf("") }
    var sortOptionName by rememberSaveable { mutableStateOf(LibrarySortOption.LOCATION.name) }
    var selectedBank by rememberSaveable { mutableStateOf<Int?>(null) }
    var routeKind by rememberSaveable { mutableStateOf("list") }
    var routeSlug by rememberSaveable { mutableStateOf<String?>(null) }
    var routeImageUrl by rememberSaveable { mutableStateOf<String?>(null) }

    val goBack: () -> Unit = {
        when (routeKind) {
            "detail" -> {
                routeKind = "list"
                routeSlug = null
                routeImageUrl = null
            }
            "rulesheet", "playfield" -> routeKind = "detail"
            else -> {
                routeKind = "list"
                routeSlug = null
                routeImageUrl = null
            }
        }
    }
    BackHandler(enabled = routeKind != "list") {
        goBack()
    }

    LaunchedEffect(Unit) {
        try {
            val cached = PinballDataCache.passthroughOrCachedText(LIBRARY_URL)
            games = parseGames(JSONArray(cached.text.orEmpty()))
        } catch (t: Throwable) {
            games = emptyList()
        }
    }
    LaunchedEffect(routeKind) {
        if (routeKind != "playfield") {
            bottomBarVisible.value = true
        }
    }

    val routeGame = routeSlug?.let { slug -> games.firstOrNull { it.slug == slug } }

    androidx.compose.foundation.layout.Box(
        modifier = Modifier.iosEdgeSwipeBack(enabled = routeKind != "list", onBack = goBack),
    ) {
        when (routeKind) {
        "list" -> LibraryList(
            contentPadding = contentPadding,
            games = games,
            query = query,
            sortOptionName = sortOptionName,
            selectedBank = selectedBank,
            onQueryChange = { query = it },
            onSortOptionChange = { sortOptionName = it },
            onBankChange = { selectedBank = it },
            onOpenGame = {
                routeSlug = it.slug
                routeKind = "detail"
                LibraryActivityLog.log(context, it.slug, it.name, LibraryActivityKind.BrowseGame)
                prefs.edit()
                    .putString(KEY_LIBRARY_LAST_VIEWED_SLUG, it.slug)
                    .putLong(KEY_LIBRARY_LAST_VIEWED_TS, System.currentTimeMillis())
                    .apply()
            },
        )

        "detail" -> {
            if (routeGame == null) {
                if (games.isEmpty()) {
                    AppScreen(contentPadding) { }
                } else {
                    AppScreen(contentPadding) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            EmptyLabel("Game not found.")
                            Button(onClick = {
                                routeKind = "list"
                                routeSlug = null
                                routeImageUrl = null
                            }) {
                                Text("Back to Library")
                            }
                        }
                    }
                }
            } else {
                LibraryDetail(
                    contentPadding = contentPadding,
                    game = routeGame,
                    onBack = {
                        routeKind = "list"
                        routeSlug = null
                        routeImageUrl = null
                    },
                onOpenRulesheet = {
                    LibraryActivityLog.log(context, routeGame.slug, routeGame.name, LibraryActivityKind.OpenRulesheet)
                    routeKind = "rulesheet"
                },
                    onOpenPlayfield = { imageUrl ->
                        LibraryActivityLog.log(context, routeGame.slug, routeGame.name, LibraryActivityKind.OpenPlayfield)
                        routeImageUrl = imageUrl
                        routeKind = "playfield"
                    },
                )
            }
        }

        "rulesheet" -> {
            if (routeGame == null) {
                if (games.isEmpty()) {
                    AppScreen(contentPadding) { }
                } else {
                    AppScreen(contentPadding) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            EmptyLabel("Rulesheet game not found.")
                            Button(onClick = {
                                routeKind = "list"
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
                    onBack = { routeKind = "detail" },
                )
            }
        }

        "playfield" -> {
            if (routeGame == null) {
                if (games.isEmpty()) {
                    AppScreen(contentPadding) { }
                } else {
                    AppScreen(contentPadding) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            EmptyLabel("Playfield game not found.")
                            Button(onClick = {
                                routeKind = "list"
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
                    onBack = { routeKind = "detail" },
                )
            }
        }

        else -> {
            LibraryList(
                contentPadding = contentPadding,
                games = games,
                query = query,
                sortOptionName = sortOptionName,
                selectedBank = selectedBank,
                onQueryChange = { query = it },
                onSortOptionChange = { sortOptionName = it },
                onBankChange = { selectedBank = it },
                onOpenGame = {
                    routeSlug = it.slug
                    routeKind = "detail"
                    LibraryActivityLog.log(context, it.slug, it.name, LibraryActivityKind.BrowseGame)
                    prefs.edit()
                        .putString(KEY_LIBRARY_LAST_VIEWED_SLUG, it.slug)
                        .putLong(KEY_LIBRARY_LAST_VIEWED_TS, System.currentTimeMillis())
                        .apply()
                },
            )
        }
    }
    }
}
