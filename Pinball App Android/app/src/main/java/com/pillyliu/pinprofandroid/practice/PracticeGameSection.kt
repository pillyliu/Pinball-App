package com.pillyliu.pinprofandroid.practice

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.library.ConstrainedAsyncImagePreview
import com.pillyliu.pinprofandroid.library.detailArtworkCandidates
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.PlayableVideo
import com.pillyliu.pinprofandroid.library.practiceKey
import com.pillyliu.pinprofandroid.library.RulesheetRemoteSource
import com.pillyliu.pinprofandroid.library.youtubeId
import com.pillyliu.pinprofandroid.ui.AppSuccessBanner
import kotlinx.coroutines.delay

@Composable
internal fun PracticeGameSection(
    store: PracticeStore,
    game: PinballGame?,
    gameSubview: PracticeGameSubview,
    onGameSubviewChange: (PracticeGameSubview) -> Unit,
    gameSummaryDraft: String,
    onGameSummaryDraftChange: (String) -> Unit,
    activeGameVideoId: String?,
    onActiveGameVideoIdChange: (String?) -> Unit,
    onOpenQuickEntry: (QuickActivity, QuickEntryOrigin) -> Unit,
    onOpenRulesheet: (RulesheetRemoteSource?) -> Unit,
    onOpenExternalRulesheet: (String) -> Unit,
    onOpenPlayfield: (List<String>) -> Unit,
) {
    if (game == null) {
        Text("Select a game first.")
        return
    }
    val gameKey = game.practiceKey
    val uiState = rememberPracticeGameSectionState(gameKey)
    val playableVideos = game.videos.mapNotNull { video ->
        val id = youtubeId(video.url) ?: return@mapNotNull null
        PlayableVideo(id = id, label = video.label ?: "Video")
    }

    LaunchedEffect(uiState.saveBanner) {
        val current = uiState.saveBanner ?: return@LaunchedEffect
        delay(1_200)
        if (uiState.saveBanner == current) {
            uiState.saveBanner = null
        }
    }

    Box {
        Column {
            ConstrainedAsyncImagePreview(
                urls = game.detailArtworkCandidates(),
                contentDescription = game.name,
                emptyMessage = "No image",
            )

            PracticeGameWorkspaceCard(
                store = store,
                game = game,
                gameSubview = gameSubview,
                onGameSubviewChange = onGameSubviewChange,
                revealedLogRowId = uiState.revealedLogRowId,
                onRevealedLogRowIdChange = { uiState.revealedLogRowId = it },
                onOpenQuickEntry = onOpenQuickEntry,
                onEditLogEntry = { entry -> uiState.beginEditing(store, entry) },
                onDeleteLogEntry = { entry -> uiState.confirmDelete(entry) },
            )

            PracticeGameNoteCard(
                gameKey = gameKey,
                store = store,
                gameSummaryDraft = gameSummaryDraft,
                onGameSummaryDraftChange = onGameSummaryDraftChange,
            )

            PracticeGameResourcesCard(
                game = game,
                playableVideos = playableVideos,
                activeGameVideoId = activeGameVideoId,
                onActiveGameVideoIdChange = onActiveGameVideoIdChange,
                onOpenRulesheet = onOpenRulesheet,
                onOpenExternalRulesheet = onOpenExternalRulesheet,
                onOpenPlayfield = onOpenPlayfield,
            )
        }

        AnimatedVisibility(
            visible = uiState.saveBanner != null,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 4.dp),
            enter = slideInVertically(initialOffsetY = { -it / 2 }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { -it / 2 }) + fadeOut(),
        ) {
            uiState.saveBanner?.let { message ->
                AppSuccessBanner(text = message)
            }
        }
    }

    PracticeGameDialogs(
        store = store,
        pendingDeleteEntry = uiState.pendingDeleteEntry,
        onPendingDeleteEntryChange = { uiState.pendingDeleteEntry = it },
        editingDraft = uiState.editingDraft,
        onEditingDraftChange = { uiState.editingDraft = it },
        editValidation = uiState.editValidation,
        onEditValidationChange = { uiState.editValidation = it },
        onEntryDeleted = uiState::handleEntryDeleted,
        onEntryEdited = uiState::handleEntryEdited,
    )
}
