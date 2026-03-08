package com.pillyliu.pinprofandroid.practice

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.pillyliu.pinprofandroid.library.ConstrainedAsyncImagePreview
import com.pillyliu.pinprofandroid.library.detailArtworkCandidates
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.PlayableVideo
import com.pillyliu.pinprofandroid.library.practiceKey
import com.pillyliu.pinprofandroid.library.RulesheetRemoteSource
import com.pillyliu.pinprofandroid.library.youtubeId

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
