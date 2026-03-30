package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.runtime.Composable

@Composable
internal fun GameRoomScreenHomeRouteHost(
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    selectedMachine: OwnedMachine?,
    selectedMachineID: String?,
    collectionLayout: GameRoomCollectionLayout,
    onCollectionLayoutChange: (GameRoomCollectionLayout) -> Unit,
    onSelectedMachineIDChange: (String?) -> Unit,
    onOpenMachineView: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    GameRoomHomeRoute(
        context = GameRoomHomeRouteContext(
            store = store,
            catalogLoader = catalogLoader,
            selectedMachine = selectedMachine,
            selectedMachineID = selectedMachineID,
            collectionLayout = collectionLayout,
            onCollectionLayoutChange = onCollectionLayoutChange,
            onSelectMachine = onSelectedMachineIDChange,
            onOpenMachineView = onOpenMachineView,
            onOpenSettings = onOpenSettings,
        ),
    )
}

@Composable
internal fun GameRoomScreenMachineRouteHost(
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    selectedMachine: OwnedMachine?,
    machineSubview: GameRoomMachineSubview,
    onMachineSubviewChange: (GameRoomMachineSubview) -> Unit,
    selectedLogEventID: String?,
    onSelectedLogEventIDChange: (String?) -> Unit,
    onBack: () -> Unit,
    onActiveInputSheetChange: (GameRoomInputSheet?) -> Unit,
    onInputResolveIssueIDDraftChange: (String?) -> Unit,
    onInputPlayTotalDraftChange: (String) -> Unit,
    onMediaPreviewAttachmentIDChange: (String?) -> Unit,
    onEditingEventIDChange: (String?) -> Unit,
    onEditEventDateDraftChange: (String) -> Unit,
    onEditEventSummaryDraftChange: (String) -> Unit,
    onEditEventNotesDraftChange: (String) -> Unit,
) {
    GameRoomMachineRoute(
        store = store,
        catalogLoader = catalogLoader,
        selectedMachine = selectedMachine,
        machineSubview = machineSubview,
        onMachineSubviewChange = onMachineSubviewChange,
        selectedLogEventID = selectedLogEventID,
        onSelectedLogEventIDChange = onSelectedLogEventIDChange,
        onBack = onBack,
        onOpenInputSheet = { onActiveInputSheetChange(it) },
        onResolveIssueRequest = {
            onInputResolveIssueIDDraftChange(it)
            onActiveInputSheetChange(GameRoomInputSheet.ResolveIssue)
        },
        onLogPlaysRequest = {
            onInputPlayTotalDraftChange(it)
            onActiveInputSheetChange(GameRoomInputSheet.LogPlays)
        },
        onPreviewAttachment = { onMediaPreviewAttachmentIDChange(it.id) },
        onEditEvent = { event ->
            onEditingEventIDChange(event.id)
            onEditEventDateDraftChange(isoDateFromMillis(event.occurredAtMs))
            onEditEventSummaryDraftChange(event.summary)
            onEditEventNotesDraftChange(event.notes.orEmpty())
        },
        onDeleteEvent = { event ->
            store.deleteEvent(event.id)
        },
    )
}
