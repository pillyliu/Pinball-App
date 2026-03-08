package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPanelStatusCard
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.EmptyLabel

@Composable
internal fun LibraryRouteContent(
    contentPadding: PaddingValues,
    games: List<PinballGame>,
    isLoading: Boolean,
    errorMessage: String?,
    browseState: LibraryBrowseState,
    route: LibraryRoute,
    routeGame: PinballGame?,
    onSourceChange: (String) -> Unit,
    onQueryChange: (String) -> Unit,
    onSortOptionChange: (String) -> Unit,
    onBankChange: (Int?) -> Unit,
    onOpenGame: (PinballGame) -> Unit,
    onBackToList: () -> Unit,
    onShowRulesheet: (RulesheetRemoteSource?) -> Unit,
    onShowExternalRulesheet: (String) -> Unit,
    onShowPlayfield: (String) -> Unit,
    onBackToDetail: () -> Unit,
) {
    when (route) {
        LibraryRoute.List -> LibraryList(
            contentPadding = contentPadding,
            isLoading = isLoading,
            errorMessage = errorMessage,
            browseState = browseState,
            onSourceChange = onSourceChange,
            onQueryChange = onQueryChange,
            onSortOptionChange = onSortOptionChange,
            onBankChange = onBankChange,
            onOpenGame = onOpenGame,
        )

        is LibraryRoute.Detail -> {
            if (routeGame == null) {
                LibraryRouteMissingScreen(
                    contentPadding = contentPadding,
                    games = games,
                    message = "Game not found.",
                    onBack = onBackToList,
                )
            } else {
                LibraryDetailScreen(
                    contentPadding = contentPadding,
                    game = routeGame,
                    onBack = onBackToList,
                    onOpenRulesheet = onShowRulesheet,
                    onOpenExternalRulesheet = onShowExternalRulesheet,
                    onOpenPlayfield = onShowPlayfield,
                )
            }
        }

        is LibraryRoute.Rulesheet -> {
            if (routeGame == null) {
                LibraryRouteMissingScreen(
                    contentPadding = contentPadding,
                    games = games,
                    message = "Rulesheet game not found.",
                    onBack = onBackToList,
                )
            } else {
                RulesheetScreen(
                    contentPadding = contentPadding,
                    slug = routeGame.practiceKey,
                    title = routeGame.name,
                    remoteCandidates = routeGame.rulesheetPathCandidates.mapNotNull { candidate -> routeGame.resolve(candidate) }.distinct(),
                    externalSource = route.rulesheetSource(),
                    onBack = onBackToDetail,
                )
            }
        }

        is LibraryRoute.ExternalRulesheet -> {
            if (routeGame == null) {
                onBackToDetail()
            } else {
                ExternalRulesheetWebScreen(
                    contentPadding = contentPadding,
                    title = routeGame.name,
                    url = route.url,
                    onBack = onBackToDetail,
                )
            }
        }

        is LibraryRoute.Playfield -> {
            if (routeGame == null) {
                LibraryRouteMissingScreen(
                    contentPadding = contentPadding,
                    games = games,
                    message = "Playfield game not found.",
                    onBack = onBackToList,
                )
            } else {
                val imageCandidates = (listOfNotNull(route.imageUrl) + routeGame.fullscreenPlayfieldCandidates())
                    .filter { it.isNotBlank() }
                    .distinct()
                PlayfieldScreen(
                    contentPadding = contentPadding,
                    title = routeGame.name,
                    imageUrls = imageCandidates,
                    onBack = onBackToDetail,
                )
            }
        }
    }
}

@Composable
private fun LibraryRouteMissingScreen(
    contentPadding: PaddingValues,
    games: List<PinballGame>,
    message: String,
    onBack: () -> Unit,
) {
    if (games.isEmpty()) {
        AppScreen(contentPadding) {
            AppPanelEmptyCard(text = message)
        }
    } else {
        AppScreen(contentPadding) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                EmptyLabel(message)
                Button(onClick = onBack) {
                    Text("Back to Library")
                }
            }
        }
    }
}
