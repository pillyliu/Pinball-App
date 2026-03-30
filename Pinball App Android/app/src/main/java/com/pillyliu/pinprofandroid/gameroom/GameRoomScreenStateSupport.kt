package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.runtime.MutableIntState
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable

internal enum class GameRoomRoute {
    Home,
    Settings,
    MachineView,
}

internal data class GameRoomNavigationState(
    val route: MutableState<GameRoomRoute>,
    val selectedSettingsSection: MutableState<GameRoomSettingsSection>,
    val selectedMachineID: MutableState<String?>,
    val collectionLayout: MutableState<GameRoomCollectionLayout>,
    val archiveFilter: MutableState<GameRoomArchiveFilter>,
    val machineSubview: MutableState<GameRoomMachineSubview>,
    val selectedLogEventID: MutableState<String?>,
)

@Composable
internal fun rememberGameRoomNavigationState(): GameRoomNavigationState {
    return GameRoomNavigationState(
        route = rememberSaveable { mutableStateOf(GameRoomRoute.Home) },
        selectedSettingsSection = rememberSaveable { mutableStateOf(GameRoomSettingsSection.Import) },
        selectedMachineID = rememberSaveable { mutableStateOf<String?>(null) },
        collectionLayout = rememberSaveable { mutableStateOf(GameRoomCollectionLayout.Tiles) },
        archiveFilter = rememberSaveable { mutableStateOf(GameRoomArchiveFilter.All) },
        machineSubview = rememberSaveable { mutableStateOf(GameRoomMachineSubview.Summary) },
        selectedLogEventID = rememberSaveable { mutableStateOf<String?>(null) },
    )
}

internal data class GameRoomPresentationDraftState(
    val editingEventID: MutableState<String?>,
    val editEventDateDraft: MutableState<String>,
    val editEventSummaryDraft: MutableState<String>,
    val editEventNotesDraft: MutableState<String>,
    val activeInputSheet: MutableState<GameRoomInputSheet?>,
    val inputNotesDraft: MutableState<String>,
    val inputConsumableDraft: MutableState<String>,
    val inputPitchValueDraft: MutableState<String>,
    val inputPitchPointDraft: MutableState<String>,
    val inputIssueSymptomDraft: MutableState<String>,
    val inputIssueSeverityDraft: MutableState<String>,
    val inputIssueSubsystemDraft: MutableState<String>,
    val inputIssueDiagnosisDraft: MutableState<String>,
    val inputDateDraft: MutableState<String>,
    val inputResolveIssueIDDraft: MutableState<String?>,
    val inputOwnershipTypeDraft: MutableState<String>,
    val inputSummaryDraft: MutableState<String>,
    val inputDetailsDraft: MutableState<String>,
    val inputPlayTotalDraft: MutableState<String>,
    val inputMediaKindDraft: MutableState<String>,
    val inputMediaURIDraft: MutableState<String>,
    val inputMediaCaptionDraft: MutableState<String>,
    val pendingMediaMachineID: MutableState<String?>,
    val pendingMediaOwnerType: MutableState<String>,
    val pendingMediaOwnerID: MutableState<String?>,
    val pendingMediaOccurredAtMs: MutableState<Long?>,
    val pendingMediaCaptionDraft: MutableState<String>,
    val pendingMediaNotesDraft: MutableState<String>,
    val issueDraftAttachments: MutableState<List<IssueInputAttachmentDraft>>,
    val mediaPreviewAttachmentID: MutableState<String?>,
    val editingAttachmentID: MutableState<String?>,
    val editAttachmentCaptionDraft: MutableState<String>,
    val editAttachmentNotesDraft: MutableState<String>,
)

@Composable
internal fun rememberGameRoomPresentationDraftState(): GameRoomPresentationDraftState {
    return GameRoomPresentationDraftState(
        editingEventID = rememberSaveable { mutableStateOf<String?>(null) },
        editEventDateDraft = rememberSaveable { mutableStateOf(todayIsoDate()) },
        editEventSummaryDraft = rememberSaveable { mutableStateOf("") },
        editEventNotesDraft = rememberSaveable { mutableStateOf("") },
        activeInputSheet = rememberSaveable { mutableStateOf<GameRoomInputSheet?>(null) },
        inputNotesDraft = rememberSaveable { mutableStateOf("") },
        inputConsumableDraft = rememberSaveable { mutableStateOf("") },
        inputPitchValueDraft = rememberSaveable { mutableStateOf("") },
        inputPitchPointDraft = rememberSaveable { mutableStateOf("") },
        inputIssueSymptomDraft = rememberSaveable { mutableStateOf("") },
        inputIssueSeverityDraft = rememberSaveable { mutableStateOf(MachineIssueSeverity.medium.name) },
        inputIssueSubsystemDraft = rememberSaveable { mutableStateOf(MachineIssueSubsystem.other.name) },
        inputIssueDiagnosisDraft = rememberSaveable { mutableStateOf("") },
        inputDateDraft = rememberSaveable { mutableStateOf(todayIsoDate()) },
        inputResolveIssueIDDraft = rememberSaveable { mutableStateOf<String?>(null) },
        inputOwnershipTypeDraft = rememberSaveable { mutableStateOf(MachineEventType.moved.name) },
        inputSummaryDraft = rememberSaveable { mutableStateOf("") },
        inputDetailsDraft = rememberSaveable { mutableStateOf("") },
        inputPlayTotalDraft = rememberSaveable { mutableStateOf("") },
        inputMediaKindDraft = rememberSaveable { mutableStateOf(MachineAttachmentKind.photo.name) },
        inputMediaURIDraft = rememberSaveable { mutableStateOf("") },
        inputMediaCaptionDraft = rememberSaveable { mutableStateOf("") },
        pendingMediaMachineID = rememberSaveable { mutableStateOf<String?>(null) },
        pendingMediaOwnerType = rememberSaveable { mutableStateOf(MachineAttachmentOwnerType.event.name) },
        pendingMediaOwnerID = rememberSaveable { mutableStateOf<String?>(null) },
        pendingMediaOccurredAtMs = rememberSaveable { mutableStateOf<Long?>(null) },
        pendingMediaCaptionDraft = rememberSaveable { mutableStateOf("") },
        pendingMediaNotesDraft = rememberSaveable { mutableStateOf("") },
        issueDraftAttachments = remember { mutableStateOf<List<IssueInputAttachmentDraft>>(emptyList()) },
        mediaPreviewAttachmentID = rememberSaveable { mutableStateOf<String?>(null) },
        editingAttachmentID = rememberSaveable { mutableStateOf<String?>(null) },
        editAttachmentCaptionDraft = rememberSaveable { mutableStateOf("") },
        editAttachmentNotesDraft = rememberSaveable { mutableStateOf("") },
    )
}

internal data class GameRoomSettingsDraftState(
    val addMachineExpanded: MutableState<Boolean>,
    val nameExpanded: MutableState<Boolean>,
    val areasExpanded: MutableState<Boolean>,
    val editMachinesExpanded: MutableState<Boolean>,
    val areaNameDraft: MutableState<String>,
    val areaOrderDraft: MutableState<String>,
    val selectedAreaID: MutableState<String?>,
    val selectedEditMachineID: MutableState<String?>,
    val draftAreaID: MutableState<String?>,
    val draftGroup: MutableState<String>,
    val draftPosition: MutableState<String>,
    val draftStatus: MutableState<String>,
    val draftVariant: MutableState<String>,
    val draftPurchaseSource: MutableState<String>,
    val draftSerialNumber: MutableState<String>,
    val draftOwnershipNotes: MutableState<String>,
    val venueNameDraft: MutableState<String>,
    val importSourceInput: MutableState<String>,
    val importSourceURL: MutableState<String>,
    val importRows: MutableState<List<ImportDraftRow>>,
    val importIsLoading: MutableState<Boolean>,
    val importErrorMessage: MutableState<String?>,
    val importResultMessage: MutableState<String?>,
    val importReviewFilter: MutableState<ImportReviewFilter>,
    val settingsSaveFeedbackMessage: MutableState<String?>,
    val settingsSaveFeedbackTick: MutableIntState,
)

@Composable
internal fun rememberGameRoomSettingsDraftState(): GameRoomSettingsDraftState {
    return GameRoomSettingsDraftState(
        addMachineExpanded = rememberSaveable { mutableStateOf(false) },
        nameExpanded = rememberSaveable { mutableStateOf(false) },
        areasExpanded = rememberSaveable { mutableStateOf(false) },
        editMachinesExpanded = rememberSaveable { mutableStateOf(false) },
        areaNameDraft = rememberSaveable { mutableStateOf("") },
        areaOrderDraft = rememberSaveable { mutableStateOf("1") },
        selectedAreaID = rememberSaveable { mutableStateOf<String?>(null) },
        selectedEditMachineID = rememberSaveable { mutableStateOf<String?>(null) },
        draftAreaID = rememberSaveable { mutableStateOf<String?>(null) },
        draftGroup = rememberSaveable { mutableStateOf("") },
        draftPosition = rememberSaveable { mutableStateOf("") },
        draftStatus = rememberSaveable { mutableStateOf(OwnedMachineStatus.active.name) },
        draftVariant = rememberSaveable { mutableStateOf("None") },
        draftPurchaseSource = rememberSaveable { mutableStateOf("") },
        draftSerialNumber = rememberSaveable { mutableStateOf("") },
        draftOwnershipNotes = rememberSaveable { mutableStateOf("") },
        venueNameDraft = rememberSaveable { mutableStateOf("") },
        importSourceInput = rememberSaveable { mutableStateOf("") },
        importSourceURL = rememberSaveable { mutableStateOf("") },
        importRows = remember { mutableStateOf<List<ImportDraftRow>>(emptyList()) },
        importIsLoading = rememberSaveable { mutableStateOf(false) },
        importErrorMessage = rememberSaveable { mutableStateOf<String?>(null) },
        importResultMessage = rememberSaveable { mutableStateOf<String?>(null) },
        importReviewFilter = rememberSaveable { mutableStateOf(ImportReviewFilter.All) },
        settingsSaveFeedbackMessage = rememberSaveable { mutableStateOf<String?>(null) },
        settingsSaveFeedbackTick = rememberSaveable { mutableIntStateOf(0) },
    )
}
