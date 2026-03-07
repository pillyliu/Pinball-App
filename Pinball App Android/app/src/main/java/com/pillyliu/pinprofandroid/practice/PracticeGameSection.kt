package com.pillyliu.pinprofandroid.practice

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.pillyliu.pinprofandroid.library.ConstrainedAsyncImagePreview
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.PlayableVideo
import com.pillyliu.pinprofandroid.library.gameInlinePlayfieldCandidates
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
    val playableVideos = game.videos.mapNotNull { video ->
        val id = youtubeId(video.url) ?: return@mapNotNull null
        PlayableVideo(id = id, label = video.label ?: "Video")
    }
    var editingDraft by remember { mutableStateOf<PracticeJournalEditDraft?>(null) }
    var pendingDeleteEntry by remember { mutableStateOf<JournalEntry?>(null) }
    var editValidation by remember { mutableStateOf<String?>(null) }
    var revealedLogRowId by rememberSaveable(gameKey) { mutableStateOf<String?>(null) }

    ConstrainedAsyncImagePreview(
        urls = game.gameInlinePlayfieldCandidates(),
        contentDescription = game.name,
        emptyMessage = "No image",
    )

    PracticeGameWorkspaceCard(
        store = store,
        game = game,
        gameSubview = gameSubview,
        onGameSubviewChange = onGameSubviewChange,
        revealedLogRowId = revealedLogRowId,
        onRevealedLogRowIdChange = { revealedLogRowId = it },
        onOpenQuickEntry = onOpenQuickEntry,
        onEditLogEntry = { entry ->
            revealedLogRowId = null
            editingDraft = store.journalEditDraft(entry)
            editValidation = null
        },
        onDeleteLogEntry = { entry ->
            revealedLogRowId = null
            pendingDeleteEntry = entry
        },
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
        pendingDeleteEntry = pendingDeleteEntry,
        onPendingDeleteEntryChange = { pendingDeleteEntry = it },
        editingDraft = editingDraft,
        onEditingDraftChange = { editingDraft = it },
        editValidation = editValidation,
        onEditValidationChange = { editValidation = it },
        onEntryDeleted = { revealedLogRowId = null },
        onEntryEdited = { revealedLogRowId = null },
    )
}
