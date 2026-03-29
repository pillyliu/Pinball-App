package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.data.downloadTextAllowMissing
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.AppRouteScreen

@Composable
internal fun LibraryDetailScreen(
    contentPadding: PaddingValues,
    game: PinballGame,
    onBack: () -> Unit,
    onOpenRulesheet: (RulesheetRemoteSource?, String?) -> Unit,
    onOpenExternalRulesheet: (String, String?) -> Unit,
    onOpenPlayfield: (List<String>) -> Unit,
) {
    val routeId = game.libraryRouteId
    val detailScroll = rememberSaveable(routeId, saver = androidx.compose.foundation.ScrollState.Saver) {
        androidx.compose.foundation.ScrollState(0)
    }
    var markdown by rememberSaveable(routeId) { mutableStateOf<String?>(null) }
    var infoStatus by rememberSaveable(routeId) { mutableStateOf("loading") }
    var activeVideoId by rememberSaveable(routeId) {
        mutableStateOf<String?>(null)
    }
    LaunchedEffect(routeId) {
        if (infoStatus == "loaded" || infoStatus == "missing") return@LaunchedEffect
        val candidates = game.gameinfoPathCandidates.mapNotNull { candidate -> game.resolve(candidate) }.distinct()
        var loaded = false
        var sawError = false
        for (candidate in candidates) {
            val (code, text) = downloadTextAllowMissing(candidate)
            when {
                code in 200..299 && !text.isNullOrBlank() -> {
                    markdown = text
                    infoStatus = "loaded"
                    loaded = true
                    break
                }
                code == 404 -> Unit
                else -> sawError = true
            }
        }
        if (!loaded) infoStatus = if (sawError) "error" else "missing"
    }

    AppRouteScreen(
        contentPadding = contentPadding,
        canGoBack = true,
        onBack = onBack,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(detailScroll),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
            ) {
                AppScreenHeader(
                    title = game.name,
                    onBack = onBack,
                    modifier = Modifier.align(Alignment.Center),
                    titleColor = MaterialTheme.colorScheme.onSurface,
                )
            }

            LibraryDetailScreenshotSection(game = game)

            LibraryDetailSummaryCard(
                game = game,
                onOpenRulesheet = onOpenRulesheet,
                onOpenExternalRulesheet = onOpenExternalRulesheet,
                onOpenPlayfield = onOpenPlayfield,
            )

            LibraryDetailVideosCard(
                game = game,
                activeVideoId = activeVideoId,
                onActiveVideoIdChange = { activeVideoId = it },
            )

            LibraryDetailGameInfoCard(
                infoStatus = infoStatus,
                markdown = markdown,
            )
            Spacer(Modifier.height(LIBRARY_CONTENT_BOTTOM_FILLER))
        }
    }
}
