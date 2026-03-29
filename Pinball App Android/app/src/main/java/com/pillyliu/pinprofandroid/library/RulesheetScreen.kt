package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppFullscreenStatusOverlay
import com.pillyliu.pinprofandroid.ui.AppRouteScreen

@Composable
internal fun RulesheetScreen(
    contentPadding: PaddingValues,
    gameId: String,
    title: String? = null,
    pathCandidates: List<String>? = null,
    externalSource: RulesheetRemoteSource? = null,
    onBack: () -> Unit,
    practiceSavedRatio: Float? = null,
    onSavePracticeRatio: ((Float) -> Unit)? = null,
) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("rulesheet-progress-v1", android.content.Context.MODE_PRIVATE) }
    var status by rememberSaveable(gameId) { mutableStateOf("loading") }
    var content by rememberSaveable(gameId) { mutableStateOf<RulesheetRenderContent?>(null) }
    var chromeVisible by rememberSaveable(gameId) { mutableStateOf(false) }
    var progressRatio by rememberSaveable(gameId) { mutableFloatStateOf(0f) }
    var savedRatio by rememberSaveable(gameId) { mutableFloatStateOf(0f) }
    var showResumePrompt by rememberSaveable(gameId) { mutableStateOf(false) }
    var evaluatedResumePrompt by rememberSaveable(gameId) { mutableStateOf(false) }
    var resumeTargetRatio by rememberSaveable(gameId) { mutableStateOf<Float?>(null) }
    var resumeRequestId by rememberSaveable(gameId) { mutableIntStateOf(0) }

    androidx.compose.runtime.LaunchedEffect(gameId, practiceSavedRatio) {
        val key = "rulesheet-last-progress-$gameId"
        val stored = prefs.getFloat(key, 0f).coerceIn(0f, 1f)
        savedRatio = (practiceSavedRatio ?: stored).coerceIn(0f, 1f)
    }

    androidx.compose.runtime.LaunchedEffect(gameId, externalSource?.url) {
        if (status == "loaded" || status == "missing") return@LaunchedEffect
        val (loadedStatus, loadedContent) = loadRulesheetRenderContent(
            gameId = gameId,
            pathCandidates = pathCandidates,
            externalSource = externalSource,
        )
        content = loadedContent
        status = loadedStatus
    }

    AppRouteScreen(
        contentPadding = contentPadding,
        canGoBack = true,
        onBack = onBack,
        horizontalPadding = 8.dp,
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
        ) {
            when (status) {
                "loading" -> AppFullscreenStatusOverlay(text = "Loading rulesheet…", showsProgress = true)
                "missing" -> AppFullscreenStatusOverlay(text = "Rulesheet not available.")
                "error" -> AppFullscreenStatusOverlay(text = "Could not load rulesheet.")
                else -> content?.let {
                    RulesheetContentWebView(
                        content = it,
                        modifier = Modifier.fillMaxSize(),
                        stateKey = "rulesheet-$gameId-${externalSource?.url.orEmpty()}",
                        resumeRequestId = resumeRequestId,
                        resumeTargetRatio = resumeTargetRatio,
                        onTap = { chromeVisible = !chromeVisible },
                        onProgressChange = { progressRatio = it },
                    )
                }
            }
            if (status == "loaded" && !evaluatedResumePrompt) {
                evaluatedResumePrompt = true
                if (savedRatio > 0.001f) {
                    showResumePrompt = true
                }
            }
            if (status == "loaded") {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd),
                ) {
                    RulesheetProgressPill(
                        gameId = gameId,
                        progressRatio = progressRatio,
                        savedRatio = savedRatio,
                        prefs = prefs,
                        onSavePracticeRatio = onSavePracticeRatio,
                    )
                }
            }
            if (chromeVisible) {
                RulesheetChromeOverlay(
                    title = title,
                    gameId = gameId,
                    onBack = onBack,
                )
            }
        }
    }
    if (showResumePrompt) {
        RulesheetResumePrompt(
            savedRatio = savedRatio,
            onConfirm = {
                resumeTargetRatio = savedRatio
                resumeRequestId += 1
                showResumePrompt = false
            },
            onDismiss = { showResumePrompt = false },
        )
    }
}
