package com.pillyliu.pinprofandroid.practice

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue

internal class PracticeGameSectionState {
    var editingDraft by mutableStateOf<PracticeJournalEditDraft?>(null)
    var pendingDeleteEntry by mutableStateOf<JournalEntry?>(null)
    var editValidation by mutableStateOf<String?>(null)
    var revealedLogRowId by mutableStateOf<String?>(null)

    fun beginEditing(store: PracticeStore, entry: JournalEntry) {
        revealedLogRowId = null
        editingDraft = store.journalEditDraft(entry)
        editValidation = null
    }

    fun confirmDelete(entry: JournalEntry) {
        revealedLogRowId = null
        pendingDeleteEntry = entry
    }

    fun handleEntryDeleted() {
        revealedLogRowId = null
    }

    fun handleEntryEdited() {
        revealedLogRowId = null
    }
}

@Composable
internal fun rememberPracticeGameSectionState(gameKey: String): PracticeGameSectionState {
    return remember(gameKey) { PracticeGameSectionState() }
}
