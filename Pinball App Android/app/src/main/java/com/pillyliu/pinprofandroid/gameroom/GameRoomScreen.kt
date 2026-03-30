package com.pillyliu.pinprofandroid.gameroom

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.MenuAnchorType
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.library.rememberCachedImageModel
import com.pillyliu.pinprofandroid.practice.StyledPracticeJournalSummaryText
import com.pillyliu.pinprofandroid.practice.formatTimestamp
import com.pillyliu.pinprofandroid.ui.AppRouteScreen
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.format.ResolverStyle
import java.util.Locale
import kotlin.math.max
import kotlin.math.min
import coil.compose.AsyncImage
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.pillyliu.pinprofandroid.library.ConstrainedAsyncImagePreview

@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun GameRoomScreen(
    contentPadding: PaddingValues,
    externalStore: GameRoomStore? = null,
    externalCatalogLoader: GameRoomCatalogLoader? = null,
    externalPinsideImportService: GameRoomPinsideImportService? = null,
) {
    val context = LocalContext.current
    val store = externalStore ?: remember(context.applicationContext) { GameRoomStore(context.applicationContext) }
    val catalogLoader = externalCatalogLoader ?: remember { GameRoomCatalogLoader() }
    val pinsideImportService = externalPinsideImportService ?: remember(context.applicationContext) { GameRoomPinsideImportService(context.applicationContext) }
    val scope = rememberCoroutineScope()
    val navigationState = rememberGameRoomNavigationState()
    val presentationState = rememberGameRoomPresentationDraftState()
    val settingsState = rememberGameRoomSettingsDraftState()
    var route by navigationState.route
    var selectedSettingsSection by navigationState.selectedSettingsSection
    var selectedMachineID by navigationState.selectedMachineID
    var collectionLayout by navigationState.collectionLayout
    var archiveFilter by navigationState.archiveFilter
    var machineSubview by navigationState.machineSubview
    var selectedLogEventID by navigationState.selectedLogEventID
    var editingEventID by presentationState.editingEventID
    var editEventDateDraft by presentationState.editEventDateDraft
    var editEventSummaryDraft by presentationState.editEventSummaryDraft
    var editEventNotesDraft by presentationState.editEventNotesDraft
    var activeInputSheet by presentationState.activeInputSheet
    var inputNotesDraft by presentationState.inputNotesDraft
    var inputConsumableDraft by presentationState.inputConsumableDraft
    var inputPitchValueDraft by presentationState.inputPitchValueDraft
    var inputPitchPointDraft by presentationState.inputPitchPointDraft
    var inputIssueSymptomDraft by presentationState.inputIssueSymptomDraft
    var inputIssueSeverityDraft by presentationState.inputIssueSeverityDraft
    var inputIssueSubsystemDraft by presentationState.inputIssueSubsystemDraft
    var inputIssueDiagnosisDraft by presentationState.inputIssueDiagnosisDraft
    var inputDateDraft by presentationState.inputDateDraft
    var inputResolveIssueIDDraft by presentationState.inputResolveIssueIDDraft
    var inputOwnershipTypeDraft by presentationState.inputOwnershipTypeDraft
    var inputSummaryDraft by presentationState.inputSummaryDraft
    var inputDetailsDraft by presentationState.inputDetailsDraft
    var inputPlayTotalDraft by presentationState.inputPlayTotalDraft
    var inputMediaKindDraft by presentationState.inputMediaKindDraft
    var inputMediaURIDraft by presentationState.inputMediaURIDraft
    var inputMediaCaptionDraft by presentationState.inputMediaCaptionDraft
    var pendingMediaMachineID by presentationState.pendingMediaMachineID
    var pendingMediaOwnerType by presentationState.pendingMediaOwnerType
    var pendingMediaOwnerID by presentationState.pendingMediaOwnerID
    var pendingMediaOccurredAtMs by presentationState.pendingMediaOccurredAtMs
    var pendingMediaCaptionDraft by presentationState.pendingMediaCaptionDraft
    var pendingMediaNotesDraft by presentationState.pendingMediaNotesDraft
    var issueDraftAttachments by presentationState.issueDraftAttachments
    var mediaPreviewAttachmentID by presentationState.mediaPreviewAttachmentID
    var editingAttachmentID by presentationState.editingAttachmentID
    var editAttachmentCaptionDraft by presentationState.editAttachmentCaptionDraft
    var editAttachmentNotesDraft by presentationState.editAttachmentNotesDraft
    var addMachineExpanded by settingsState.addMachineExpanded
    var nameExpanded by settingsState.nameExpanded
    var areasExpanded by settingsState.areasExpanded
    var editMachinesExpanded by settingsState.editMachinesExpanded
    var areaNameDraft by settingsState.areaNameDraft
    var areaOrderDraft by settingsState.areaOrderDraft
    var selectedAreaID by settingsState.selectedAreaID
    var selectedEditMachineID by settingsState.selectedEditMachineID
    var draftAreaID by settingsState.draftAreaID
    var draftGroup by settingsState.draftGroup
    var draftPosition by settingsState.draftPosition
    var draftStatus by settingsState.draftStatus
    var draftVariant by settingsState.draftVariant
    var draftPurchaseSource by settingsState.draftPurchaseSource
    var draftSerialNumber by settingsState.draftSerialNumber
    var draftOwnershipNotes by settingsState.draftOwnershipNotes
    var venueNameDraft by settingsState.venueNameDraft
    var importSourceInput by settingsState.importSourceInput
    var importSourceURL by settingsState.importSourceURL
    var importRows by settingsState.importRows
    var importIsLoading by settingsState.importIsLoading
    var importErrorMessage by settingsState.importErrorMessage
    var importResultMessage by settingsState.importResultMessage
    var importReviewFilter by settingsState.importReviewFilter
    var settingsSaveFeedbackMessage by settingsState.settingsSaveFeedbackMessage
    var settingsSaveFeedbackTick by settingsState.settingsSaveFeedbackTick
    val selections = rememberGameRoomScreenSelections(
        store = store,
        catalogLoader = catalogLoader,
        selectedMachineID = selectedMachineID,
        onSelectedMachineIDChange = { selectedMachineID = it },
        selectedEditMachineID = selectedEditMachineID,
        onSelectedEditMachineIDChange = { selectedEditMachineID = it },
        draftAreaID = draftAreaID,
        onDraftAreaIDChange = { draftAreaID = it },
        onDraftGroupChange = { draftGroup = it },
        onDraftPositionChange = { draftPosition = it },
        onDraftStatusChange = { draftStatus = it },
        onDraftVariantChange = { draftVariant = it },
        onDraftPurchaseSourceChange = { draftPurchaseSource = it },
        onDraftSerialNumberChange = { draftSerialNumber = it },
        onDraftOwnershipNotesChange = { draftOwnershipNotes = it },
        venueNameDraft = venueNameDraft,
        onVenueNameDraftChange = { venueNameDraft = it },
        activeInputSheet = activeInputSheet,
        onInputDateDraftChange = { inputDateDraft = it },
        onIssueDraftAttachmentsChange = { issueDraftAttachments = it },
    )
    val activeMachines = selections.activeMachines
    val selectedMachineFromAll = selections.selectedMachineFromAll
    val selectedMachine = selections.selectedMachine
    val allMachines = selections.allMachines
    val selectedEditMachine = selections.selectedEditMachine

    val mediaLaunchers = rememberGameRoomMediaLaunchers(
        context = context,
        store = store,
        pendingMediaDraft = GameRoomPendingMediaDraft(
            machineID = pendingMediaMachineID,
            ownerTypeName = pendingMediaOwnerType,
            ownerID = pendingMediaOwnerID,
            occurredAtMs = pendingMediaOccurredAtMs,
            captionDraft = pendingMediaCaptionDraft,
            notesDraft = pendingMediaNotesDraft,
        ),
        onSelectedLogEventIDChange = { selectedLogEventID = it },
        onMachineSubviewChange = { machineSubview = it },
        onClearPendingMediaDraft = {
            pendingMediaMachineID = null
            pendingMediaOwnerID = null
            pendingMediaOwnerType = MachineAttachmentOwnerType.event.name
            pendingMediaOccurredAtMs = null
            pendingMediaCaptionDraft = ""
            pendingMediaNotesDraft = ""
        },
        issueDraftAttachments = issueDraftAttachments,
        onIssueDraftAttachmentsChange = { issueDraftAttachments = it },
    )

    BackHandler(enabled = route != GameRoomRoute.Home) {
        route = GameRoomRoute.Home
    }

    AppRouteScreen(
        contentPadding = contentPadding,
        canGoBack = route != GameRoomRoute.Home,
        onBack = { route = GameRoomRoute.Home },
    ) {
        when (route) {
            GameRoomRoute.Home -> {
                GameRoomScreenHomeRouteHost(
                    store = store,
                    catalogLoader = catalogLoader,
                    selectedMachine = selectedMachine,
                    selectedMachineID = selectedMachineID,
                    collectionLayout = collectionLayout,
                    onCollectionLayoutChange = { collectionLayout = it },
                    onSelectedMachineIDChange = { selectedMachineID = it },
                    onOpenMachineView = { route = GameRoomRoute.MachineView },
                    onOpenSettings = { route = GameRoomRoute.Settings },
                )
            }

            GameRoomRoute.Settings -> {
                GameRoomScreenSettingsRouteHost(
                    store = store,
                    catalogLoader = catalogLoader,
                    pinsideImportService = pinsideImportService,
                    scope = scope,
                    selectedSettingsSection = selectedSettingsSection,
                    onSelectedSettingsSectionChange = { selectedSettingsSection = it },
                    onBack = { route = GameRoomRoute.Home },
                    settingsSaveFeedbackMessage = settingsSaveFeedbackMessage,
                    settingsSaveFeedbackTick = settingsSaveFeedbackTick,
                    importSourceInput = importSourceInput,
                    onImportSourceInputChange = { importSourceInput = it },
                    importSourceURL = importSourceURL,
                    onImportSourceURLChange = { importSourceURL = it },
                    importIsLoading = importIsLoading,
                    onImportIsLoadingChange = { importIsLoading = it },
                    importErrorMessage = importErrorMessage,
                    onImportErrorMessageChange = { importErrorMessage = it },
                    importResultMessage = importResultMessage,
                    onImportResultMessageChange = { importResultMessage = it },
                    importRows = importRows,
                    onImportRowsChange = { importRows = it },
                    importReviewFilter = importReviewFilter,
                    onImportReviewFilterChange = { importReviewFilter = it },
                    nameExpanded = nameExpanded,
                    onNameExpandedChange = { nameExpanded = it },
                    venueNameDraft = venueNameDraft,
                    onVenueNameDraftChange = { venueNameDraft = it },
                    onSettingsSaveFeedback = { message ->
                        settingsSaveFeedbackMessage = message
                        settingsSaveFeedbackTick += 1
                    },
                    addMachineExpanded = addMachineExpanded,
                    onAddMachineExpandedChange = { addMachineExpanded = it },
                    areasExpanded = areasExpanded,
                    onAreasExpandedChange = { areasExpanded = it },
                    areaNameDraft = areaNameDraft,
                    onAreaNameDraftChange = { areaNameDraft = it },
                    areaOrderDraft = areaOrderDraft,
                    onAreaOrderDraftChange = { areaOrderDraft = it.filter { ch -> ch.isDigit() } },
                    selectedAreaID = selectedAreaID,
                    onSelectedAreaIDChange = { selectedAreaID = it },
                    editMachinesExpanded = editMachinesExpanded,
                    onEditMachinesExpandedChange = { editMachinesExpanded = it },
                    allMachines = allMachines,
                    selectedEditMachine = selectedEditMachine,
                    onSelectedEditMachineChange = { selectedEditMachineID = it },
                    draftVariant = draftVariant,
                    onDraftVariantChange = { draftVariant = it },
                    draftAreaID = draftAreaID,
                    onDraftAreaIDChange = { draftAreaID = it },
                    draftStatus = draftStatus,
                    onDraftStatusChange = { draftStatus = it },
                    draftGroup = draftGroup,
                    onDraftGroupChange = { draftGroup = it.filter { ch -> ch.isDigit() } },
                    draftPosition = draftPosition,
                    onDraftPositionChange = { draftPosition = it.filter { ch -> ch.isDigit() } },
                    draftPurchaseSource = draftPurchaseSource,
                    onDraftPurchaseSourceChange = { draftPurchaseSource = it },
                    draftSerialNumber = draftSerialNumber,
                    onDraftSerialNumberChange = { draftSerialNumber = it },
                    draftOwnershipNotes = draftOwnershipNotes,
                    onDraftOwnershipNotesChange = { draftOwnershipNotes = it },
                    archiveFilter = archiveFilter,
                    onArchiveFilterChange = { archiveFilter = it },
                    onOpenArchivedMachineView = { machineID ->
                        selectedMachineID = machineID
                        route = GameRoomRoute.MachineView
                    },
                )
            }

            GameRoomRoute.MachineView -> {
                GameRoomScreenMachineRouteHost(
                    store = store,
                    catalogLoader = catalogLoader,
                    selectedMachine = selectedMachineFromAll,
                    machineSubview = machineSubview,
                    onMachineSubviewChange = { machineSubview = it },
                    selectedLogEventID = selectedLogEventID,
                    onSelectedLogEventIDChange = { selectedLogEventID = it },
                    onBack = { route = GameRoomRoute.Home },
                    onActiveInputSheetChange = { activeInputSheet = it },
                    onInputResolveIssueIDDraftChange = { inputResolveIssueIDDraft = it },
                    onInputPlayTotalDraftChange = { inputPlayTotalDraft = it },
                    onMediaPreviewAttachmentIDChange = { mediaPreviewAttachmentID = it },
                    onEditingEventIDChange = { editingEventID = it },
                    onEditEventDateDraftChange = { editEventDateDraft = it },
                    onEditEventSummaryDraftChange = { editEventSummaryDraft = it },
                    onEditEventNotesDraftChange = { editEventNotesDraft = it },
                )
            }
        }
    }

    GameRoomPresentationHost(
        inputSheetContext = buildGameRoomInputSheetContext(
            store = store,
            selectedMachine = selectedMachineFromAll,
            selectedSheet = activeInputSheet,
            inputDateDraft = inputDateDraft,
            onInputDateDraftChange = { inputDateDraft = it },
            inputNotesDraft = inputNotesDraft,
            onInputNotesDraftChange = { inputNotesDraft = it },
            inputConsumableDraft = inputConsumableDraft,
            onInputConsumableDraftChange = { inputConsumableDraft = it },
            inputPitchValueDraft = inputPitchValueDraft,
            onInputPitchValueDraftChange = { inputPitchValueDraft = it },
            inputPitchPointDraft = inputPitchPointDraft,
            onInputPitchPointDraftChange = { inputPitchPointDraft = it },
            inputIssueSymptomDraft = inputIssueSymptomDraft,
            onInputIssueSymptomDraftChange = { inputIssueSymptomDraft = it },
            inputIssueSeverityDraft = inputIssueSeverityDraft,
            onInputIssueSeverityDraftChange = { inputIssueSeverityDraft = it },
            inputIssueSubsystemDraft = inputIssueSubsystemDraft,
            onInputIssueSubsystemDraftChange = { inputIssueSubsystemDraft = it },
            inputIssueDiagnosisDraft = inputIssueDiagnosisDraft,
            onInputIssueDiagnosisDraftChange = { inputIssueDiagnosisDraft = it },
            inputResolveIssueIDDraft = inputResolveIssueIDDraft,
            onInputResolveIssueIDDraftChange = { inputResolveIssueIDDraft = it },
            inputOwnershipTypeDraft = inputOwnershipTypeDraft,
            onInputOwnershipTypeDraftChange = {
                inputOwnershipTypeDraft = it
                if (inputSummaryDraft.isBlank()) {
                    inputSummaryDraft = it.replaceFirstChar { ch -> ch.uppercase() }
                }
            },
            inputSummaryDraft = inputSummaryDraft,
            onInputSummaryDraftChange = { inputSummaryDraft = it },
            inputDetailsDraft = inputDetailsDraft,
            onInputDetailsDraftChange = { inputDetailsDraft = it },
            inputPlayTotalDraft = inputPlayTotalDraft,
            onInputPlayTotalDraftChange = { inputPlayTotalDraft = it.filter { ch -> ch.isDigit() } },
            inputMediaKindDraft = inputMediaKindDraft,
            onInputMediaKindDraftChange = { inputMediaKindDraft = it },
            inputMediaURIDraft = inputMediaURIDraft,
            onInputMediaURIDraftChange = { inputMediaURIDraft = it },
            inputMediaCaptionDraft = inputMediaCaptionDraft,
            onInputMediaCaptionDraftChange = { inputMediaCaptionDraft = it },
            issueDraftAttachments = issueDraftAttachments,
            onIssueDraftAttachmentsChange = { issueDraftAttachments = it },
            mediaLaunchers = mediaLaunchers,
            onPendingMediaMachineIDChange = { pendingMediaMachineID = it },
            onPendingMediaOwnerTypeChange = { pendingMediaOwnerType = it },
            onPendingMediaOwnerIDChange = { pendingMediaOwnerID = it },
            onPendingMediaOccurredAtMsChange = { pendingMediaOccurredAtMs = it },
            onPendingMediaCaptionDraftChange = { pendingMediaCaptionDraft = it },
            onPendingMediaNotesDraftChange = { pendingMediaNotesDraft = it },
            onSelectedLogEventIDChange = { selectedLogEventID = it },
            onMachineSubviewChange = { machineSubview = it },
            onActiveInputSheetChange = { activeInputSheet = it },
        ),
        editEventContext = buildGameRoomEditEventContext(
            store = store,
            editingEventID = editingEventID,
            editEventDateDraft = editEventDateDraft,
            onEditEventDateDraftChange = { editEventDateDraft = it },
            editEventSummaryDraft = editEventSummaryDraft,
            onEditEventSummaryDraftChange = { editEventSummaryDraft = it },
            editEventNotesDraft = editEventNotesDraft,
            onEditEventNotesDraftChange = { editEventNotesDraft = it },
            onEditingEventIDChange = { editingEventID = it },
        ),
        attachmentContext = buildGameRoomAttachmentPresentationContext(
            store = store,
            mediaPreviewAttachmentID = mediaPreviewAttachmentID,
            editingAttachmentID = editingAttachmentID,
            editAttachmentCaptionDraft = editAttachmentCaptionDraft,
            onEditAttachmentCaptionDraftChange = { editAttachmentCaptionDraft = it },
            editAttachmentNotesDraft = editAttachmentNotesDraft,
            onEditAttachmentNotesDraftChange = { editAttachmentNotesDraft = it },
            onMediaPreviewAttachmentIDChange = { mediaPreviewAttachmentID = it },
            onEditingAttachmentIDChange = { editingAttachmentID = it },
        ),
    )
}
