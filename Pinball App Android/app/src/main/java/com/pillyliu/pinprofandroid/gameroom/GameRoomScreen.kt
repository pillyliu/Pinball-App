package com.pillyliu.pinprofandroid.gameroom

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
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
import com.pillyliu.pinprofandroid.ui.AppBackButton
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.iosEdgeSwipeBack
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

private enum class GameRoomRoute {
    Home,
    Settings,
    MachineView,
}

internal enum class GameRoomSettingsSection(val label: String) {
    Import("Import"),
    Edit("Edit"),
    Archive("Archive"),
}

internal enum class GameRoomArchiveFilter(val label: String) {
    All("All"),
    Sold("Sold"),
    Traded("Traded"),
    Archived("Archived"),
}

private enum class GameRoomCollectionLayout(val label: String) {
    Tiles("Cards"),
    List("List"),
}

internal enum class GameRoomMachineSubview(val label: String) {
    Summary("Summary"),
    Input("Input"),
    Log("Log"),
}

internal enum class GameRoomInputSheet(val title: String) {
    CleanGlass("Clean Glass"),
    CleanPlayfield("Clean Playfield"),
    SwapBalls("Swap Balls"),
    CheckPitch("Check Pitch"),
    LevelMachine("Level Machine"),
    GeneralInspection("General Inspection"),
    LogIssue("Log Issue"),
    ResolveIssue("Resolve Issue"),
    OwnershipUpdate("Ownership Update"),
    InstallMod("Install Mod"),
    ReplacePart("Replace Part"),
    LogPlays("Log Plays"),
    AddMedia("Add Photo/Video"),
}

internal enum class ImportReviewFilter(val label: String) {
    All("All"),
    NeedsReview("Needs Review"),
}

internal data class ImportDraftRow(
    val id: String,
    val sourceItemKey: String,
    val rawTitle: String,
    val rawVariant: String?,
    val matchConfidence: MachineImportMatchConfidence,
    val suggestions: List<String>,
    val fingerprint: String,
    val selectedCatalogGameID: String?,
    val selectedVariant: String?,
    val rawPurchaseDateText: String?,
    val normalizedPurchaseDateMs: Long?,
)

private data class IssueInputAttachmentDraft(
    val id: String,
    val kind: MachineAttachmentKind,
    val uri: String,
    val caption: String?,
)

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun GameRoomScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val store = remember { GameRoomStore(context) }
    val catalogLoader = remember { GameRoomCatalogLoader(context) }
    val pinsideImportService = remember { GameRoomPinsideImportService(context) }
    val scope = rememberCoroutineScope()
    var route by rememberSaveable { mutableStateOf(GameRoomRoute.Home) }
    var selectedSettingsSection by rememberSaveable { mutableStateOf(GameRoomSettingsSection.Import) }
    var selectedMachineID by rememberSaveable { mutableStateOf<String?>(null) }
    var collectionLayout by rememberSaveable { mutableStateOf(GameRoomCollectionLayout.Tiles) }
    var archiveFilter by rememberSaveable { mutableStateOf(GameRoomArchiveFilter.All) }
    var machineSubview by rememberSaveable { mutableStateOf(GameRoomMachineSubview.Summary) }
    var selectedLogEventID by rememberSaveable { mutableStateOf<String?>(null) }
    var revealedMachineLogRowID by rememberSaveable { mutableStateOf<String?>(null) }
    var editingEventID by rememberSaveable { mutableStateOf<String?>(null) }
    var editEventDateDraft by rememberSaveable { mutableStateOf(todayIsoDate()) }
    var editEventSummaryDraft by rememberSaveable { mutableStateOf("") }
    var editEventNotesDraft by rememberSaveable { mutableStateOf("") }
    var activeInputSheet by rememberSaveable { mutableStateOf<GameRoomInputSheet?>(null) }
    var inputNotesDraft by rememberSaveable { mutableStateOf("") }
    var inputConsumableDraft by rememberSaveable { mutableStateOf("") }
    var inputPitchValueDraft by rememberSaveable { mutableStateOf("") }
    var inputPitchPointDraft by rememberSaveable { mutableStateOf("") }
    var inputIssueSymptomDraft by rememberSaveable { mutableStateOf("") }
    var inputIssueSeverityDraft by rememberSaveable { mutableStateOf(MachineIssueSeverity.medium.name) }
    var inputIssueSubsystemDraft by rememberSaveable { mutableStateOf(MachineIssueSubsystem.other.name) }
    var inputIssueDiagnosisDraft by rememberSaveable { mutableStateOf("") }
    var inputDateDraft by rememberSaveable { mutableStateOf(todayIsoDate()) }
    var inputResolveIssueIDDraft by rememberSaveable { mutableStateOf<String?>(null) }
    var inputOwnershipTypeDraft by rememberSaveable { mutableStateOf(MachineEventType.moved.name) }
    var inputSummaryDraft by rememberSaveable { mutableStateOf("") }
    var inputDetailsDraft by rememberSaveable { mutableStateOf("") }
    var inputPlayTotalDraft by rememberSaveable { mutableStateOf("") }
    var inputMediaKindDraft by rememberSaveable { mutableStateOf(MachineAttachmentKind.photo.name) }
    var inputMediaURIDraft by rememberSaveable { mutableStateOf("") }
    var inputMediaCaptionDraft by rememberSaveable { mutableStateOf("") }
    var pendingMediaMachineID by rememberSaveable { mutableStateOf<String?>(null) }
    var pendingMediaOwnerType by rememberSaveable { mutableStateOf(MachineAttachmentOwnerType.event.name) }
    var pendingMediaOwnerID by rememberSaveable { mutableStateOf<String?>(null) }
    var pendingMediaOccurredAtMs by rememberSaveable { mutableStateOf<Long?>(null) }
    var pendingMediaCaptionDraft by rememberSaveable { mutableStateOf("") }
    var pendingMediaNotesDraft by rememberSaveable { mutableStateOf("") }
    var issueDraftAttachments by remember { mutableStateOf<List<IssueInputAttachmentDraft>>(emptyList()) }
    var mediaPreviewAttachmentID by rememberSaveable { mutableStateOf<String?>(null) }
    var editingAttachmentID by rememberSaveable { mutableStateOf<String?>(null) }
    var editAttachmentCaptionDraft by rememberSaveable { mutableStateOf("") }
    var editAttachmentNotesDraft by rememberSaveable { mutableStateOf("") }
    var addMachineExpanded by rememberSaveable { mutableStateOf(false) }
    var nameExpanded by rememberSaveable { mutableStateOf(false) }
    var areasExpanded by rememberSaveable { mutableStateOf(false) }
    var editMachinesExpanded by rememberSaveable { mutableStateOf(false) }
    var addQuery by rememberSaveable { mutableStateOf("") }
    var addManufacturerFilter by rememberSaveable { mutableStateOf<String?>(null) }
    var resultWindowStart by rememberSaveable { mutableStateOf(0) }
    var resultWindowEnd by rememberSaveable { mutableStateOf(25) }
    var pendingResultRestoreGameID by rememberSaveable { mutableStateOf<String?>(null) }
    var pendingResultRestoreTick by rememberSaveable { mutableIntStateOf(0) }
    var areaNameDraft by rememberSaveable { mutableStateOf("") }
    var areaOrderDraft by rememberSaveable { mutableStateOf("0") }
    var selectedAreaID by rememberSaveable { mutableStateOf<String?>(null) }
    var selectedEditMachineID by rememberSaveable { mutableStateOf<String?>(null) }
    var draftAreaID by rememberSaveable { mutableStateOf<String?>(null) }
    var draftGroup by rememberSaveable { mutableStateOf("") }
    var draftPosition by rememberSaveable { mutableStateOf("") }
    var draftStatus by rememberSaveable { mutableStateOf(OwnedMachineStatus.active.name) }
    var draftVariant by rememberSaveable { mutableStateOf("None") }
    var draftPurchaseSource by rememberSaveable { mutableStateOf("") }
    var draftSerialNumber by rememberSaveable { mutableStateOf("") }
    var draftOwnershipNotes by rememberSaveable { mutableStateOf("") }
    var venueNameDraft by rememberSaveable { mutableStateOf("") }
    var importSourceInput by rememberSaveable { mutableStateOf("") }
    var importSourceURL by rememberSaveable { mutableStateOf("") }
    var importRows by remember { mutableStateOf<List<ImportDraftRow>>(emptyList()) }
    var importIsLoading by rememberSaveable { mutableStateOf(false) }
    var importErrorMessage by rememberSaveable { mutableStateOf<String?>(null) }
    var importResultMessage by rememberSaveable { mutableStateOf<String?>(null) }
    var importReviewFilter by rememberSaveable { mutableStateOf(ImportReviewFilter.All) }
    val activeMachines = store.activeMachines
    val selectedMachineFromAll = store.state.ownedMachines.firstOrNull { it.id == selectedMachineID }
    val selectedMachine = activeMachines.firstOrNull { it.id == selectedMachineID } ?: activeMachines.firstOrNull()
    val allMachines = store.activeMachines + store.archivedMachines
    val selectedEditMachine = allMachines.firstOrNull { it.id == selectedEditMachineID }
    val resultPageSize = 25
    val maxRenderedResults = 75

    LaunchedEffect(Unit) {
        store.loadIfNeeded()
        catalogLoader.loadIfNeeded()
    }

    LaunchedEffect(activeMachines.map { it.id }) {
        if (selectedMachineID == null || activeMachines.none { it.id == selectedMachineID }) {
            selectedMachineID = activeMachines.firstOrNull()?.id
        }
    }

    LaunchedEffect(route, machineSubview, selectedMachineID) {
        if (route != GameRoomRoute.MachineView || machineSubview != GameRoomMachineSubview.Log) {
            revealedMachineLogRowID = null
        }
    }

    LaunchedEffect(allMachines.map { it.id }) {
        if (selectedEditMachineID == null || allMachines.none { it.id == selectedEditMachineID }) {
            selectedEditMachineID = allMachines.firstOrNull()?.id
        }
    }

    LaunchedEffect(selectedEditMachineID) {
        val machine = selectedEditMachine ?: return@LaunchedEffect
        draftAreaID = machine.gameRoomAreaID
        draftGroup = machine.groupNumber?.toString().orEmpty()
        draftPosition = machine.position?.toString().orEmpty()
        draftStatus = machine.status.name
        draftVariant = machine.displayVariant ?: "None"
        draftPurchaseSource = machine.purchaseSource.orEmpty()
        draftSerialNumber = machine.serialNumber.orEmpty()
        draftOwnershipNotes = machine.ownershipNotes.orEmpty()
    }

    LaunchedEffect(store.venueName) {
        if (venueNameDraft.isBlank()) {
            venueNameDraft = store.venueName
        }
    }

    LaunchedEffect(activeInputSheet) {
        if (activeInputSheet != null) {
            inputDateDraft = todayIsoDate()
            if (activeInputSheet == GameRoomInputSheet.LogIssue) {
                issueDraftAttachments = emptyList()
            }
        }
    }

    val selectedManufacturerOption = addManufacturerFilter?.let { selectedID ->
        catalogLoader.manufacturerOptions.firstOrNull { option -> option.id == selectedID }
    }
    val modernManufacturers = catalogLoader.manufacturerOptions.filter { it.isModern }
    val classicPopularManufacturers = catalogLoader.manufacturerOptions.filter { !it.isModern && it.featuredRank != null }
    val otherManufacturers = catalogLoader.manufacturerOptions.filter { !it.isModern && it.featuredRank == null }

    val filteredCatalogGames = catalogLoader.games.filter { game ->
        val manufacturerMatches = addManufacturerFilter == null || game.manufacturerID == addManufacturerFilter
        val queryMatches = addQuery.isBlank() ||
            game.displayTitle.contains(addQuery, ignoreCase = true) ||
            (game.manufacturer?.contains(addQuery, ignoreCase = true) == true)
        manufacturerMatches && queryMatches
    }
    val safeResultWindowStart = resultWindowStart.coerceIn(0, filteredCatalogGames.size)
    val safeResultWindowEnd = resultWindowEnd.coerceIn(safeResultWindowStart, filteredCatalogGames.size)
    val displayedCatalogGames = filteredCatalogGames
        .drop(safeResultWindowStart)
        .take(safeResultWindowEnd - safeResultWindowStart)
    val hasNextFilteredResults = safeResultWindowEnd < filteredCatalogGames.size
    val hasPreviousFilteredResults = safeResultWindowStart > 0
    val resultWindowLabel = if (filteredCatalogGames.isEmpty()) {
        "Showing 0 of 0"
    } else {
        "Showing ${safeResultWindowStart + 1}-${safeResultWindowEnd} of ${filteredCatalogGames.size}"
    }
    val allAttachments = store.state.attachments
    val mediaPreviewAttachment = mediaPreviewAttachmentID?.let { id -> allAttachments.firstOrNull { it.id == id } }
    val editingAttachment = editingAttachmentID?.let { id -> allAttachments.firstOrNull { it.id == id } }

    LaunchedEffect(addQuery, addManufacturerFilter, filteredCatalogGames.size) {
        resultWindowStart = 0
        resultWindowEnd = min(resultPageSize, filteredCatalogGames.size)
    }

    val addPhotoLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        val machineID = pendingMediaMachineID
        if (uri != null && machineID != null) {
            runCatching {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
            val caption = pendingMediaCaptionDraft.ifBlank {
                uri.lastPathSegment?.substringAfterLast('/')?.takeIf { it.isNotBlank() }.orEmpty()
            }.ifBlank { null }
            val notes = pendingMediaNotesDraft.ifBlank { null }
            val occurredAtMs = pendingMediaOccurredAtMs
            val ownerType = runCatching { MachineAttachmentOwnerType.valueOf(pendingMediaOwnerType) }.getOrDefault(MachineAttachmentOwnerType.event)
            val ownerID = pendingMediaOwnerID
            var timelineEventID: String? = null
            val resolvedOwnerID = if (ownerType == MachineAttachmentOwnerType.issue && !ownerID.isNullOrBlank()) {
                ownerID
            } else {
                store.addEvent(
                    machineID = machineID,
                    type = MachineEventType.photoAdded,
                    category = MachineEventCategory.media,
                    summary = "Photo added",
                    occurredAtMs = occurredAtMs,
                    notes = notes,
                ).also { timelineEventID = it }
            }
            if (ownerType == MachineAttachmentOwnerType.issue && !ownerID.isNullOrBlank()) {
                timelineEventID = store.addEvent(
                    machineID = machineID,
                    type = MachineEventType.photoAdded,
                    category = MachineEventCategory.media,
                    summary = "Issue photo added",
                    occurredAtMs = occurredAtMs,
                    notes = notes,
                    linkedIssueID = ownerID,
                )
            }
            store.addAttachment(
                machineID = machineID,
                ownerType = ownerType,
                ownerID = resolvedOwnerID,
                kind = MachineAttachmentKind.photo,
                uri = uri.toString(),
                caption = caption,
            )
            selectedLogEventID = timelineEventID
            machineSubview = GameRoomMachineSubview.Log
        }
        pendingMediaMachineID = null
        pendingMediaOwnerID = null
        pendingMediaOwnerType = MachineAttachmentOwnerType.event.name
        pendingMediaOccurredAtMs = null
        pendingMediaCaptionDraft = ""
        pendingMediaNotesDraft = ""
    }

    val addVideoLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        val machineID = pendingMediaMachineID
        if (uri != null && machineID != null) {
            runCatching {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
            val caption = pendingMediaCaptionDraft.ifBlank {
                uri.lastPathSegment?.substringAfterLast('/')?.takeIf { it.isNotBlank() }.orEmpty()
            }.ifBlank { null }
            val notes = pendingMediaNotesDraft.ifBlank { null }
            val occurredAtMs = pendingMediaOccurredAtMs
            val ownerType = runCatching { MachineAttachmentOwnerType.valueOf(pendingMediaOwnerType) }.getOrDefault(MachineAttachmentOwnerType.event)
            val ownerID = pendingMediaOwnerID
            var timelineEventID: String? = null
            val resolvedOwnerID = if (ownerType == MachineAttachmentOwnerType.issue && !ownerID.isNullOrBlank()) {
                ownerID
            } else {
                store.addEvent(
                    machineID = machineID,
                    type = MachineEventType.videoAdded,
                    category = MachineEventCategory.media,
                    summary = "Video added",
                    occurredAtMs = occurredAtMs,
                    notes = notes,
                ).also { timelineEventID = it }
            }
            if (ownerType == MachineAttachmentOwnerType.issue && !ownerID.isNullOrBlank()) {
                timelineEventID = store.addEvent(
                    machineID = machineID,
                    type = MachineEventType.videoAdded,
                    category = MachineEventCategory.media,
                    summary = "Issue video added",
                    occurredAtMs = occurredAtMs,
                    notes = notes,
                    linkedIssueID = ownerID,
                )
            }
            store.addAttachment(
                machineID = machineID,
                ownerType = ownerType,
                ownerID = resolvedOwnerID,
                kind = MachineAttachmentKind.video,
                uri = uri.toString(),
                caption = caption,
            )
            selectedLogEventID = timelineEventID
            machineSubview = GameRoomMachineSubview.Log
        }
        pendingMediaMachineID = null
        pendingMediaOwnerID = null
        pendingMediaOwnerType = MachineAttachmentOwnerType.event.name
        pendingMediaOccurredAtMs = null
        pendingMediaCaptionDraft = ""
        pendingMediaNotesDraft = ""
    }

    val issuePhotoDraftLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri != null) {
            runCatching {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
            val caption = uri.lastPathSegment?.substringAfterLast('/')?.takeIf { it.isNotBlank() }
            issueDraftAttachments = issueDraftAttachments + IssueInputAttachmentDraft(
                id = java.util.UUID.randomUUID().toString(),
                kind = MachineAttachmentKind.photo,
                uri = uri.toString(),
                caption = caption,
            )
        }
    }

    val issueVideoDraftLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri != null) {
            runCatching {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
            val caption = uri.lastPathSegment?.substringAfterLast('/')?.takeIf { it.isNotBlank() }
            issueDraftAttachments = issueDraftAttachments + IssueInputAttachmentDraft(
                id = java.util.UUID.randomUUID().toString(),
                kind = MachineAttachmentKind.video,
                uri = uri.toString(),
                caption = caption,
            )
        }
    }

    BackHandler(enabled = route != GameRoomRoute.Home) {
        route = GameRoomRoute.Home
    }

    AppScreen(
        contentPadding = contentPadding,
        modifier = Modifier.iosEdgeSwipeBack(
            enabled = route != GameRoomRoute.Home,
            onBack = { route = GameRoomRoute.Home },
        ),
    ) {
        when (route) {
            GameRoomRoute.Home -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = store.venueName,
                            color = MaterialTheme.colorScheme.onSurface,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 20.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier
                                .weight(1f)
                                .padding(start = 8.dp),
                        )
                        IconButton(onClick = { route = GameRoomRoute.Settings }) {
                            Icon(
                                imageVector = Icons.Outlined.Settings,
                                contentDescription = "GameRoom Settings",
                                tint = MaterialTheme.colorScheme.onSurface,
                            )
                        }
                    }

                    CardContainer {
                        Text(
                            text = "Selected Machine",
                            color = MaterialTheme.colorScheme.onSurface,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                        if (selectedMachine == null) {
                            Text(
                                text = "Select a machine from the collection below.",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        } else {
                            val snapshot = store.snapshot(selectedMachine.id)
                            val areaName = store.area(selectedMachine.gameRoomAreaID)?.name ?: "No area"
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    text = selectedMachine.displayTitle,
                                    color = MaterialTheme.colorScheme.onSurface,
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.SemiBold,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.weight(1f),
                                )
                                val variantLabel = gameRoomVariantBadgeLabel(selectedMachine.displayVariant, selectedMachine.displayTitle)
                                if (variantLabel != null) {
                                    GameRoomVariantPill(label = variantLabel, style = VariantPillStyle.Standard)
                                }
                            }
                            Text(
                                text = "Location: $areaName • Group ${selectedMachine.groupNumber ?: "—"} • Position ${selectedMachine.position ?: "—"}",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                            Text(
                                text = "Current Snapshot",
                                color = MaterialTheme.colorScheme.onSurface,
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(top = 2.dp),
                            )
                            SnapshotMetricGrid(
                                metrics = listOf(
                                    "Open Issues" to snapshot.openIssueCount.toString(),
                                    "Current Plays" to snapshot.currentPlayCount.toString(),
                                    "Due Tasks" to snapshot.dueTaskCount.toString(),
                                    "Last Service" to formatDate(snapshot.lastServiceAtMs, "None"),
                                    "Pitch" to (snapshot.currentPitchValue?.let { String.format("%.1f", it) } ?: "—"),
                                    "Last Level" to formatDate(snapshot.lastLeveledAtMs, "None"),
                                    "Last Inspection" to formatDate(snapshot.lastGeneralInspectionAtMs, "None"),
                                    "Purchase Date" to formatDate(selectedMachine.purchaseDateMs, "—"),
                                ),
                            )
                            selectedMachine.purchaseDateRawText?.takeIf { it.isNotBlank() }?.let { raw ->
                                Text(
                                    text = "Purchase (raw): $raw",
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    style = MaterialTheme.typography.bodySmall,
                                )
                            }
                        }
                    }

                    CardContainer {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = "Collection",
                                color = MaterialTheme.colorScheme.onSurface,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.weight(1f),
                            )
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                GameRoomCollectionLayout.entries.forEach { mode ->
                                    val selected = mode == collectionLayout
                                    Box(
                                        modifier = Modifier
                                            .background(
                                                if (selected) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceContainerHigh,
                                                RoundedCornerShape(999.dp),
                                            )
                                            .border(
                                                1.dp,
                                                if (selected) MaterialTheme.colorScheme.outline else MaterialTheme.colorScheme.outlineVariant,
                                                RoundedCornerShape(999.dp),
                                            )
                                            .clickable { collectionLayout = mode }
                                            .padding(horizontal = 10.dp, vertical = 6.dp),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        Text(
                                            text = mode.label,
                                            color = MaterialTheme.colorScheme.onSurface,
                                            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                                        )
                                    }
                                }
                            }
                        }
                        Text(
                            text = "Tracked active machines: ${activeMachines.size}",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        if (activeMachines.isEmpty()) {
                            Text(
                                text = "No active machines yet. Add one in GameRoom Settings > Edit.",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        } else {
                            if (collectionLayout == GameRoomCollectionLayout.Tiles) {
                                val leftColumn = activeMachines.filterIndexed { index, _ -> index % 2 == 0 }
                                val rightColumn = activeMachines.filterIndexed { index, _ -> index % 2 == 1 }
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                ) {
                                    Column(
                                        modifier = Modifier.weight(1f),
                                        verticalArrangement = Arrangement.spacedBy(8.dp),
                                    ) {
                                        leftColumn.forEach { machine ->
                                            val snapshot = store.snapshot(machine.id)
                                            val art = catalogLoader.resolvedArt(machine.catalogGameID, machine.displayVariant)
                                            MiniMachineCard(
                                                machine = machine,
                                                imageUrl = art?.primaryImageLargeUrl ?: art?.primaryImageUrl,
                                                attentionState = snapshot.attentionState,
                                                selected = selectedMachineID == machine.id,
                                                onClick = {
                                                    if (selectedMachineID == machine.id) {
                                                        route = GameRoomRoute.MachineView
                                                    } else {
                                                        selectedMachineID = machine.id
                                                    }
                                                },
                                            )
                                        }
                                    }
                                    Column(
                                        modifier = Modifier.weight(1f),
                                        verticalArrangement = Arrangement.spacedBy(8.dp),
                                    ) {
                                        rightColumn.forEach { machine ->
                                            val snapshot = store.snapshot(machine.id)
                                            val art = catalogLoader.resolvedArt(machine.catalogGameID, machine.displayVariant)
                                            MiniMachineCard(
                                                machine = machine,
                                                imageUrl = art?.primaryImageLargeUrl ?: art?.primaryImageUrl,
                                                attentionState = snapshot.attentionState,
                                                selected = selectedMachineID == machine.id,
                                                onClick = {
                                                    if (selectedMachineID == machine.id) {
                                                        route = GameRoomRoute.MachineView
                                                    } else {
                                                        selectedMachineID = machine.id
                                                    }
                                                },
                                            )
                                        }
                                    }
                                }
                            } else {
                                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    activeMachines.forEach { machine ->
                                        val snapshot = store.snapshot(machine.id)
                                        val art = catalogLoader.resolvedArt(machine.catalogGameID, machine.displayVariant)
                                        MachineListRow(
                                            machine = machine,
                                            imageUrl = art?.primaryImageLargeUrl ?: art?.primaryImageUrl,
                                            areaName = store.area(machine.gameRoomAreaID)?.name ?: "No area",
                                            attentionState = snapshot.attentionState,
                                            selected = selectedMachineID == machine.id,
                                            onClick = {
                                                if (selectedMachineID == machine.id) {
                                                    route = GameRoomRoute.MachineView
                                                } else {
                                                    selectedMachineID = machine.id
                                                }
                                            },
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            GameRoomRoute.Settings -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        AppBackButton(onClick = { route = GameRoomRoute.Home })
                        Text(
                            text = "GameRoom Settings",
                            color = MaterialTheme.colorScheme.onSurface,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }

                    CardContainer {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            GameRoomSettingsSection.entries.forEach { section ->
                                val selected = section == selectedSettingsSection
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .background(
                                            if (selected) {
                                                MaterialTheme.colorScheme.secondaryContainer
                                            } else {
                                                MaterialTheme.colorScheme.surfaceContainerHigh
                                            },
                                            RoundedCornerShape(999.dp),
                                        )
                                        .border(
                                            width = 1.dp,
                                            color = if (selected) {
                                                MaterialTheme.colorScheme.outline
                                            } else {
                                                MaterialTheme.colorScheme.outlineVariant
                                            },
                                            shape = RoundedCornerShape(999.dp),
                                        )
                                        .clickable { selectedSettingsSection = section }
                                        .padding(vertical = 8.dp),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Text(
                                        text = section.label,
                                        color = MaterialTheme.colorScheme.onSurface,
                                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                                    )
                                }
                            }
                        }
                    }

                    CardContainer {
                        Text(
                            text = when (selectedSettingsSection) {
                                GameRoomSettingsSection.Import -> "Import from Pinside"
                                GameRoomSettingsSection.Edit -> "Edit GameRoom"
                                GameRoomSettingsSection.Archive -> "Machine Archive"
                            },
                            color = MaterialTheme.colorScheme.onSurface,
                            fontWeight = FontWeight.SemiBold,
                        )
                        if (selectedSettingsSection == GameRoomSettingsSection.Import) {
                            GameRoomImportSettingsSection(
                                store = store,
                                catalogLoader = catalogLoader,
                                importSourceInput = importSourceInput,
                                onImportSourceInputChange = { importSourceInput = it },
                                importIsLoading = importIsLoading,
                                importErrorMessage = importErrorMessage,
                                importResultMessage = importResultMessage,
                                importRows = importRows,
                                importReviewFilter = importReviewFilter,
                                onImportReviewFilterChange = { importReviewFilter = it },
                                onFetchCollection = {
                                    val input = importSourceInput.trim()
                                    if (!importIsLoading && input.isNotBlank()) {
                                        scope.launch {
                                            importErrorMessage = null
                                            importResultMessage = null
                                            importIsLoading = true
                                            try {
                                                val result = pinsideImportService.fetchCollectionMachines(input)
                                                importSourceURL = result.sourceURL
                                                importRows = result.machines.map { machine ->
                                                    makeImportDraftRow(machine, catalogLoader)
                                                }
                                                importReviewFilter = ImportReviewFilter.All
                                            } catch (error: GameRoomPinsideImportException) {
                                                importSourceURL = ""
                                                importRows = emptyList()
                                                importErrorMessage = error.userMessage
                                            } catch (_: Throwable) {
                                                importSourceURL = ""
                                                importRows = emptyList()
                                                importErrorMessage = "Could not load Pinside collection right now."
                                            } finally {
                                                importIsLoading = false
                                            }
                                        }
                                    }
                                },
                                onUpdateImportPurchaseDate = { rowID, updatedRaw ->
                                    importRows = importRows.map { current ->
                                        if (current.id != rowID) {
                                            current
                                        } else {
                                            current.copy(
                                                rawPurchaseDateText = updatedRaw.ifBlank { null },
                                                normalizedPurchaseDateMs = normalizeFirstOfMonthMs(updatedRaw),
                                            )
                                        }
                                    }
                                },
                                onUpdateImportMatch = { rowID, selectedCatalogGameID ->
                                    importRows = importRows.map { current ->
                                        if (current.id != rowID) {
                                            current
                                        } else {
                                            val availableVariants = selectedCatalogGameID?.let { catalogLoader.variantOptions(it) }.orEmpty()
                                            val keepVariant = current.selectedVariant?.takeIf { variant ->
                                                availableVariants.any { it.equals(variant, ignoreCase = true) }
                                            }
                                            current.copy(
                                                selectedCatalogGameID = selectedCatalogGameID,
                                                selectedVariant = keepVariant,
                                            )
                                        }
                                    }
                                },
                                onUpdateImportVariant = { rowID, selectedVariant ->
                                    importRows = importRows.map { current ->
                                        if (current.id != rowID) {
                                            current
                                        } else {
                                            current.copy(selectedVariant = selectedVariant)
                                        }
                                    }
                                },
                                onPerformImport = {
                                    var importedCount = 0
                                    var skippedDuplicates = 0
                                    var skippedUnmatched = 0
                                    importRows.forEach { row ->
                                        val selectedCatalogID = row.selectedCatalogGameID
                                        val game = selectedCatalogID?.let { catalogLoader.game(it) }
                                        if (game == null) {
                                            skippedUnmatched += 1
                                            return@forEach
                                        }
                                        val resolvedVariant = row.selectedVariant ?: row.rawVariant
                                        if (store.hasImportFingerprint(row.fingerprint) || store.hasOwnedMachine(game.catalogGameID, resolvedVariant)) {
                                            skippedDuplicates += 1
                                            return@forEach
                                        }
                                        store.importOwnedMachine(
                                            game = game,
                                            sourceUserOrURL = importSourceURL.ifBlank { importSourceInput.trim() },
                                            sourceItemKey = row.sourceItemKey,
                                            rawTitle = row.rawTitle,
                                            rawVariant = resolvedVariant,
                                            rawPurchaseDateText = row.rawPurchaseDateText,
                                            normalizedPurchaseDateMs = row.normalizedPurchaseDateMs,
                                            matchConfidence = row.matchConfidence,
                                            fingerprint = row.fingerprint,
                                        )
                                        importedCount += 1
                                    }
                                    importResultMessage = "Imported $importedCount. Skipped $skippedDuplicates duplicates, $skippedUnmatched unmatched."
                                },
                            )
                        }
                    }

                    if (selectedSettingsSection == GameRoomSettingsSection.Edit) {
                        CardContainer {
                            SectionHeader(
                                title = "Name",
                                expanded = nameExpanded,
                                onToggle = { nameExpanded = !nameExpanded },
                            )
                            if (nameExpanded) {
                                OutlinedTextField(
                                    value = venueNameDraft,
                                    onValueChange = { venueNameDraft = it },
                                    modifier = Modifier.fillMaxWidth(),
                                    singleLine = true,
                                    label = { Text("GameRoom Name") },
                                )
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Button(onClick = {
                                        store.updateVenueName(venueNameDraft)
                                        venueNameDraft = store.venueName
                                    }) {
                                        Text("Save")
                                    }
                                }
                            }
                        }

                        CardContainer {
                            SectionHeader(
                                title = "Add Machine",
                                expanded = addMachineExpanded,
                                onToggle = { addMachineExpanded = !addMachineExpanded },
                            )
                            if (addMachineExpanded) {
                                OutlinedTextField(
                                    value = addQuery,
                                    onValueChange = { addQuery = it },
                                    modifier = Modifier.fillMaxWidth(),
                                    singleLine = true,
                                    label = { Text("Search by title") },
                                )
                                ManufacturerFilterDropdown(
                                    selectedText = selectedManufacturerOption?.name ?: "All Manufacturers",
                                    modernOptions = modernManufacturers,
                                    classicPopularOptions = classicPopularManufacturers,
                                    otherOptions = otherManufacturers,
                                    onSelect = {
                                        addManufacturerFilter = it
                                    },
                                )
                                Text(
                                    text = resultWindowLabel,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .heightIn(max = 260.dp)
                                        .background(MaterialTheme.colorScheme.surfaceContainerLow, RoundedCornerShape(10.dp))
                                        .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(10.dp)),
                                ) {
                                    val resultsListState = rememberLazyListState()

                                    LaunchedEffect(
                                        pendingResultRestoreTick,
                                        pendingResultRestoreGameID,
                                        displayedCatalogGames.map { it.catalogGameID },
                                        hasPreviousFilteredResults,
                                    ) {
                                        val targetGameID = pendingResultRestoreGameID ?: return@LaunchedEffect
                                        val gameIndex = displayedCatalogGames.indexOfFirst { it.catalogGameID == targetGameID }
                                        if (gameIndex >= 0) {
                                            val targetIndex = gameIndex + if (hasPreviousFilteredResults) 1 else 0
                                            resultsListState.scrollToItem(targetIndex)
                                        }
                                        pendingResultRestoreGameID = null
                                    }

                                    val resolveTopVisibleGameID: () -> String? = {
                                        if (displayedCatalogGames.isEmpty()) {
                                            null
                                        } else {
                                            val firstVisibleIndex = resultsListState.firstVisibleItemIndex
                                            val gameStartIndex = if (hasPreviousFilteredResults) 1 else 0
                                            val relativeGameIndex = firstVisibleIndex - gameStartIndex
                                            when {
                                                relativeGameIndex < 0 -> displayedCatalogGames.first().catalogGameID
                                                relativeGameIndex >= displayedCatalogGames.size -> displayedCatalogGames.last().catalogGameID
                                                else -> displayedCatalogGames[relativeGameIndex].catalogGameID
                                            }
                                        }
                                    }

                                    LazyColumn(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(8.dp),
                                        state = resultsListState,
                                        verticalArrangement = Arrangement.spacedBy(6.dp),
                                    ) {
                                        if (hasPreviousFilteredResults) {
                                            item(key = "show_previous_25") {
                                                TextButton(
                                                    onClick = {
                                                        val topVisibleGameID = resolveTopVisibleGameID()
                                                        val previousStart = (safeResultWindowStart - resultPageSize).coerceAtLeast(0)
                                                        resultWindowStart = previousStart
                                                        if (topVisibleGameID != null) {
                                                            pendingResultRestoreGameID = topVisibleGameID
                                                            pendingResultRestoreTick += 1
                                                        }
                                                    },
                                                    modifier = Modifier.fillMaxWidth(),
                                                ) {
                                                    Text("Show Previous 25")
                                                }
                                            }
                                        }

                                        items(
                                            items = displayedCatalogGames,
                                            key = { it.catalogGameID },
                                        ) { game ->
                                            Row(
                                                modifier = Modifier
                                                    .fillMaxWidth()
                                                    .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(8.dp))
                                                    .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(8.dp))
                                                    .padding(horizontal = 10.dp, vertical = 8.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                            ) {
                                                Column(modifier = Modifier.weight(1f)) {
                                                    Text(
                                                        text = game.displayTitle,
                                                        color = MaterialTheme.colorScheme.onSurface,
                                                        fontWeight = FontWeight.Medium,
                                                        maxLines = 1,
                                                        overflow = TextOverflow.Ellipsis,
                                                    )
                                                    Text(
                                                        text = listOfNotNull(game.displayVariant, game.manufacturer, game.year?.toString()).joinToString(" • "),
                                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                                        maxLines = 1,
                                                        overflow = TextOverflow.Ellipsis,
                                                    )
                                                }
                                                Button(
                                                    onClick = {
                                                        val machineID = store.addOwnedMachine(
                                                            catalogGameID = game.catalogGameID,
                                                            canonicalPracticeIdentity = game.canonicalPracticeIdentity,
                                                            displayTitle = game.displayTitle,
                                                            displayVariant = null,
                                                            manufacturer = game.manufacturer,
                                                            year = game.year,
                                                        )
                                                        selectedEditMachineID = machineID
                                                    },
                                                ) {
                                                    Icon(
                                                        imageVector = Icons.Outlined.Add,
                                                        contentDescription = "Add machine",
                                                    )
                                                }
                                            }
                                        }

                                        if (hasNextFilteredResults) {
                                            item(key = "show_next_25") {
                                                TextButton(
                                                    onClick = {
                                                        val topVisibleGameID = resolveTopVisibleGameID()
                                                        val nextEnd = min(safeResultWindowEnd + resultPageSize, filteredCatalogGames.size)
                                                        var nextStart = safeResultWindowStart
                                                        if (nextEnd - nextStart > maxRenderedResults) {
                                                            nextStart = min(
                                                                nextStart + resultPageSize,
                                                                max(0, nextEnd - maxRenderedResults),
                                                            )
                                                        }
                                                        resultWindowStart = nextStart
                                                        resultWindowEnd = nextEnd
                                                        if (topVisibleGameID != null) {
                                                            pendingResultRestoreGameID = topVisibleGameID
                                                            pendingResultRestoreTick += 1
                                                        }
                                                    },
                                                    modifier = Modifier.fillMaxWidth(),
                                                ) {
                                                    Text("Show Next 25")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        CardContainer {
                            SectionHeader(
                                title = "Areas",
                                expanded = areasExpanded,
                                onToggle = { areasExpanded = !areasExpanded },
                            )
                            if (areasExpanded) {
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    OutlinedTextField(
                                        value = areaNameDraft,
                                        onValueChange = { areaNameDraft = it },
                                        modifier = Modifier.weight(1f),
                                        singleLine = true,
                                        label = { Text("Area Name") },
                                    )
                                    OutlinedTextField(
                                        value = areaOrderDraft,
                                        onValueChange = { areaOrderDraft = it.filter { ch -> ch.isDigit() } },
                                        modifier = Modifier.width(120.dp),
                                        singleLine = true,
                                        label = { Text("Area Order") },
                                    )
                                }
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Button(onClick = {
                                        store.upsertArea(
                                            id = selectedAreaID,
                                            name = areaNameDraft,
                                            areaOrder = areaOrderDraft.toIntOrNull() ?: 0,
                                        )
                                        selectedAreaID = null
                                        areaNameDraft = ""
                                        areaOrderDraft = "0"
                                    }) { Text("Save") }
                                    Button(
                                        onClick = {
                                            selectedAreaID = null
                                            areaNameDraft = ""
                                            areaOrderDraft = "0"
                                        },
                                    ) { Text("Edit") }
                                }
                                store.state.areas.forEach { area ->
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable {
                                                selectedAreaID = area.id
                                                areaNameDraft = area.name
                                                areaOrderDraft = area.areaOrder.toString()
                                            }
                                            .padding(vertical = 4.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        Text(
                                            text = "${area.name} (${area.areaOrder})",
                                            color = MaterialTheme.colorScheme.onSurface,
                                            modifier = Modifier.weight(1f),
                                        )
                                        IconButton(
                                            onClick = { store.deleteArea(area.id) },
                                            modifier = Modifier
                                                .size(32.dp)
                                                .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(8.dp))
                                                .clip(RoundedCornerShape(8.dp)),
                                        ) {
                                            Icon(
                                                imageVector = Icons.Outlined.Delete,
                                                contentDescription = "Delete area",
                                                tint = MaterialTheme.colorScheme.error,
                                                modifier = Modifier.size(18.dp),
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        CardContainer {
                            SectionHeader(
                                title = "Edit Machines (${store.activeMachines.size})",
                                expanded = editMachinesExpanded,
                                onToggle = { editMachinesExpanded = !editMachinesExpanded },
                            )
                            if (editMachinesExpanded) {
                                if (selectedEditMachine == null) {
                                    AnchoredDropdownFilter(
                                        selectedText = "Select Machine",
                                        options = allMachines.map { DropdownOption(value = it.id, label = it.displayTitle) },
                                        onSelect = { selectedEditMachineID = it },
                                    )
                                }
                                if (selectedEditMachine != null) {
                                    val variantOptions = buildList {
                                        add("None")
                                        addAll(catalogLoader.variantOptions(selectedEditMachine.catalogGameID))
                                    }.distinct()
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        AnchoredDropdownFilter(
                                            selectedText = selectedEditMachine.displayTitle,
                                            options = allMachines.map { DropdownOption(value = it.id, label = it.displayTitle) },
                                            onSelect = { selectedEditMachineID = it },
                                            modifier = Modifier.weight(1f),
                                        )
                                        VariantPillDropdown(
                                            selectedLabel = draftVariant,
                                            options = variantOptions,
                                            onSelect = { draftVariant = it },
                                            modifier = Modifier.weight(0.52f),
                                        )
                                    }
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        AnchoredDropdownFilter(
                                            selectedText = store.area(draftAreaID)?.name ?: "No area",
                                            options = buildList {
                                                add(DropdownOption(value = "", label = "No area"))
                                                addAll(store.state.areas.map { DropdownOption(it.id, it.name) })
                                            },
                                            onSelect = { draftAreaID = it.ifBlank { null } },
                                            modifier = Modifier.weight(1f),
                                        )
                                        AnchoredDropdownFilter(
                                            selectedText = draftStatus.replaceFirstChar { it.uppercase() },
                                            options = OwnedMachineStatus.entries.map {
                                                DropdownOption(it.name, it.name.replaceFirstChar { ch -> ch.uppercase() })
                                            },
                                            onSelect = { draftStatus = it },
                                            modifier = Modifier.weight(1f),
                                        )
                                    }
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        OutlinedTextField(
                                            value = draftGroup,
                                            onValueChange = { draftGroup = it.filter { ch -> ch.isDigit() } },
                                            label = { Text("Group") },
                                            modifier = Modifier.weight(1f),
                                            singleLine = true,
                                        )
                                        OutlinedTextField(
                                            value = draftPosition,
                                            onValueChange = { draftPosition = it.filter { ch -> ch.isDigit() } },
                                            label = { Text("Position") },
                                            modifier = Modifier.weight(1f),
                                            singleLine = true,
                                        )
                                    }
                                    OutlinedTextField(
                                        value = draftPurchaseSource,
                                        onValueChange = { draftPurchaseSource = it },
                                        label = { Text("Purchase Source") },
                                        modifier = Modifier.fillMaxWidth(),
                                        singleLine = true,
                                    )
                                    OutlinedTextField(
                                        value = draftSerialNumber,
                                        onValueChange = { draftSerialNumber = it },
                                        label = { Text("Serial Number") },
                                        modifier = Modifier.fillMaxWidth(),
                                        singleLine = true,
                                    )
                                    OutlinedTextField(
                                        value = draftOwnershipNotes,
                                        onValueChange = { draftOwnershipNotes = it },
                                        label = { Text("Ownership Notes") },
                                        modifier = Modifier.fillMaxWidth(),
                                    )
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Button(onClick = {
                                            store.updateMachine(
                                                id = selectedEditMachine.id,
                                                areaID = draftAreaID,
                                                groupNumber = draftGroup.toIntOrNull(),
                                                position = draftPosition.toIntOrNull(),
                                                status = runCatching { OwnedMachineStatus.valueOf(draftStatus) }.getOrDefault(OwnedMachineStatus.active),
                                                displayVariant = draftVariant.takeUnless { it == "None" },
                                                purchaseSource = draftPurchaseSource,
                                                serialNumber = draftSerialNumber,
                                                ownershipNotes = draftOwnershipNotes,
                                            )
                                        }) { Text("Save") }
                                        Button(onClick = { store.deleteMachine(selectedEditMachine.id) }) { Text("Delete") }
                                        if (selectedEditMachine.status != OwnedMachineStatus.archived) {
                                            Button(onClick = {
                                                store.updateMachine(
                                                    id = selectedEditMachine.id,
                                                    areaID = draftAreaID,
                                                    groupNumber = draftGroup.toIntOrNull(),
                                                    position = draftPosition.toIntOrNull(),
                                                    status = OwnedMachineStatus.archived,
                                                    displayVariant = draftVariant.takeUnless { it == "None" },
                                                    purchaseSource = draftPurchaseSource,
                                                    serialNumber = draftSerialNumber,
                                                    ownershipNotes = draftOwnershipNotes,
                                                )
                                            }) { Text("Archive") }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    GameRoomArchiveSettingsSection(
                        store = store,
                        archiveFilter = archiveFilter,
                        onArchiveFilterChange = { archiveFilter = it },
                        onOpenMachineView = { machineID ->
                            selectedMachineID = machineID
                            route = GameRoomRoute.MachineView
                        },
                    )
                }
            }

            GameRoomRoute.MachineView -> {
                GameRoomMachineRoute(
                    store = store,
                    catalogLoader = catalogLoader,
                    selectedMachine = selectedMachineFromAll,
                    machineSubview = machineSubview,
                    onMachineSubviewChange = { machineSubview = it },
                    selectedLogEventID = selectedLogEventID,
                    onSelectedLogEventIDChange = { selectedLogEventID = it },
                    revealedLogRowID = revealedMachineLogRowID,
                    onRevealedLogRowIDChange = { revealedMachineLogRowID = it },
                    onBack = { route = GameRoomRoute.Home },
                    onOpenInputSheet = { activeInputSheet = it },
                    onResolveIssueRequest = {
                        inputResolveIssueIDDraft = it
                        activeInputSheet = GameRoomInputSheet.ResolveIssue
                    },
                    onLogPlaysRequest = {
                        inputPlayTotalDraft = it
                        activeInputSheet = GameRoomInputSheet.LogPlays
                    },
                    onPreviewAttachment = { mediaPreviewAttachmentID = it.id },
                    onEditEvent = { event ->
                        editingEventID = event.id
                        editEventDateDraft = isoDateFromMillis(event.occurredAtMs)
                        editEventSummaryDraft = event.summary
                        editEventNotesDraft = event.notes.orEmpty()
                    },
                    onDeleteEvent = { event ->
                        store.deleteEvent(event.id)
                    },
                )
            }
        }
    }

    if (activeInputSheet != null && selectedMachineFromAll != null) {
        val selectedSheet = activeInputSheet ?: GameRoomInputSheet.CleanGlass
        val openIssues = store.state.issues
            .filter { it.ownedMachineID == selectedMachineFromAll.id && it.status != MachineIssueStatus.resolved }
            .sortedByDescending { it.openedAtMs }

        ModalBottomSheet(
            onDismissRequest = { activeInputSheet = null },
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = selectedSheet.title,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.SemiBold,
                )
                OutlinedTextField(
                    value = inputDateDraft,
                    onValueChange = { inputDateDraft = it },
                    label = { Text("Date (YYYY-MM-DD)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )

                when (selectedSheet) {
                    GameRoomInputSheet.CleanGlass,
                    GameRoomInputSheet.CleanPlayfield,
                    GameRoomInputSheet.SwapBalls,
                    GameRoomInputSheet.LevelMachine,
                    GameRoomInputSheet.GeneralInspection -> {
                        if (selectedSheet == GameRoomInputSheet.CleanGlass || selectedSheet == GameRoomInputSheet.CleanPlayfield) {
                            OutlinedTextField(
                                value = inputConsumableDraft,
                                onValueChange = { inputConsumableDraft = it },
                                label = { Text("Cleaner / Consumable") },
                                modifier = Modifier.fillMaxWidth(),
                                singleLine = true,
                            )
                        }
                        OutlinedTextField(
                            value = inputNotesDraft,
                            onValueChange = { inputNotesDraft = it },
                            label = { Text("Notes") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }

                    GameRoomInputSheet.CheckPitch -> {
                        OutlinedTextField(
                            value = inputPitchValueDraft,
                            onValueChange = { inputPitchValueDraft = it },
                            label = { Text("Pitch Value") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                        )
                        OutlinedTextField(
                            value = inputPitchPointDraft,
                            onValueChange = { inputPitchPointDraft = it },
                            label = { Text("Measurement Point") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                        )
                        OutlinedTextField(
                            value = inputNotesDraft,
                            onValueChange = { inputNotesDraft = it },
                            label = { Text("Notes") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }

                    GameRoomInputSheet.LogIssue -> {
                        OutlinedTextField(
                            value = inputIssueSymptomDraft,
                            onValueChange = { inputIssueSymptomDraft = it },
                            label = { Text("Symptom") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                        AnchoredDropdownFilter(
                            selectedText = inputIssueSeverityDraft.replaceFirstChar { it.uppercase() },
                            options = MachineIssueSeverity.entries.map {
                                DropdownOption(it.name, it.name.replaceFirstChar { ch -> ch.uppercase() })
                            },
                            onSelect = { inputIssueSeverityDraft = it },
                        )
                        AnchoredDropdownFilter(
                            selectedText = inputIssueSubsystemDraft.replaceFirstChar { it.uppercase() },
                            options = MachineIssueSubsystem.entries.map {
                                DropdownOption(it.name, it.name.replaceFirstChar { ch -> ch.uppercase() })
                            },
                            onSelect = { inputIssueSubsystemDraft = it },
                        )
                        OutlinedTextField(
                            value = inputIssueDiagnosisDraft,
                            onValueChange = { inputIssueDiagnosisDraft = it },
                            label = { Text("Diagnosis / Notes") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Button(
                                onClick = { issuePhotoDraftLauncher.launch(arrayOf("image/*")) },
                                modifier = Modifier.weight(1f),
                            ) {
                                Text("Add Photo")
                            }
                            Button(
                                onClick = { issueVideoDraftLauncher.launch(arrayOf("video/*")) },
                                modifier = Modifier.weight(1f),
                            ) {
                                Text("Add Video")
                            }
                        }
                        if (issueDraftAttachments.isEmpty()) {
                            Text(
                                text = "No media selected.",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        } else {
                            issueDraftAttachments.forEach { attachment ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                ) {
                                    Text(
                                        text = attachment.caption ?: attachment.uri,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                        modifier = Modifier.weight(1f),
                                    )
                                    TextButton(
                                        onClick = {
                                            issueDraftAttachments = issueDraftAttachments.filterNot { it.id == attachment.id }
                                        },
                                    ) { Text("Remove") }
                                }
                            }
                        }
                    }

                    GameRoomInputSheet.ResolveIssue -> {
                        AnchoredDropdownFilter(
                            selectedText = openIssues.firstOrNull { it.id == inputResolveIssueIDDraft }?.symptom ?: "Select Issue",
                            options = openIssues.map { DropdownOption(it.id, it.symptom) },
                            onSelect = { inputResolveIssueIDDraft = it },
                        )
                        OutlinedTextField(
                            value = inputNotesDraft,
                            onValueChange = { inputNotesDraft = it },
                            label = { Text("Resolution Notes") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }

                    GameRoomInputSheet.OwnershipUpdate -> {
                        AnchoredDropdownFilter(
                            selectedText = inputOwnershipTypeDraft.replaceFirstChar { it.uppercase() },
                            options = listOf(
                                MachineEventType.purchased,
                                MachineEventType.moved,
                                MachineEventType.loanedOut,
                                MachineEventType.returned,
                                MachineEventType.listedForSale,
                                MachineEventType.sold,
                                MachineEventType.traded,
                                MachineEventType.reacquired,
                            ).map { DropdownOption(it.name, it.name.replaceFirstChar { ch -> ch.uppercase() }) },
                            onSelect = {
                                inputOwnershipTypeDraft = it
                                if (inputSummaryDraft.isBlank()) inputSummaryDraft = it.replaceFirstChar { ch -> ch.uppercase() }
                            },
                        )
                        OutlinedTextField(
                            value = inputSummaryDraft,
                            onValueChange = { inputSummaryDraft = it },
                            label = { Text("Summary") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                        OutlinedTextField(
                            value = inputNotesDraft,
                            onValueChange = { inputNotesDraft = it },
                            label = { Text("Notes") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }

                    GameRoomInputSheet.InstallMod,
                    GameRoomInputSheet.ReplacePart -> {
                        OutlinedTextField(
                            value = inputSummaryDraft,
                            onValueChange = { inputSummaryDraft = it },
                            label = { Text("Summary") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                        OutlinedTextField(
                            value = inputDetailsDraft,
                            onValueChange = { inputDetailsDraft = it },
                            label = { Text(if (selectedSheet == GameRoomInputSheet.InstallMod) "Mod / Details" else "Part Replaced") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                        OutlinedTextField(
                            value = inputNotesDraft,
                            onValueChange = { inputNotesDraft = it },
                            label = { Text("Notes") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }

                    GameRoomInputSheet.LogPlays -> {
                        OutlinedTextField(
                            value = inputPlayTotalDraft,
                            onValueChange = { inputPlayTotalDraft = it.filter { ch -> ch.isDigit() } },
                            label = { Text("Total Plays") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                        )
                        OutlinedTextField(
                            value = inputNotesDraft,
                            onValueChange = { inputNotesDraft = it },
                            label = { Text("Notes") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }

                    GameRoomInputSheet.AddMedia -> {
                        AnchoredDropdownFilter(
                            selectedText = inputMediaKindDraft.replaceFirstChar { it.uppercase() },
                            options = MachineAttachmentKind.entries.map {
                                DropdownOption(it.name, it.name.replaceFirstChar { ch -> ch.uppercase() })
                            },
                            onSelect = { inputMediaKindDraft = it },
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Button(
                                onClick = {
                                    val occurredAtMs = parseIsoDateMillis(inputDateDraft) ?: System.currentTimeMillis()
                                    inputMediaKindDraft = MachineAttachmentKind.photo.name
                                    pendingMediaMachineID = selectedMachineFromAll.id
                                    pendingMediaOwnerType = MachineAttachmentOwnerType.event.name
                                    pendingMediaOwnerID = null
                                    pendingMediaOccurredAtMs = occurredAtMs
                                    pendingMediaCaptionDraft = inputMediaCaptionDraft
                                    pendingMediaNotesDraft = inputNotesDraft
                                    activeInputSheet = null
                                    addPhotoLauncher.launch(arrayOf("image/*"))
                                },
                                modifier = Modifier.weight(1f),
                            ) {
                                Text("Add Photo")
                            }
                            Button(
                                onClick = {
                                    val occurredAtMs = parseIsoDateMillis(inputDateDraft) ?: System.currentTimeMillis()
                                    inputMediaKindDraft = MachineAttachmentKind.video.name
                                    pendingMediaMachineID = selectedMachineFromAll.id
                                    pendingMediaOwnerType = MachineAttachmentOwnerType.event.name
                                    pendingMediaOwnerID = null
                                    pendingMediaOccurredAtMs = occurredAtMs
                                    pendingMediaCaptionDraft = inputMediaCaptionDraft
                                    pendingMediaNotesDraft = inputNotesDraft
                                    activeInputSheet = null
                                    addVideoLauncher.launch(arrayOf("video/*"))
                                },
                                modifier = Modifier.weight(1f),
                            ) {
                                Text("Add Video")
                            }
                        }
                        OutlinedTextField(
                            value = inputMediaURIDraft,
                            onValueChange = { inputMediaURIDraft = it },
                            label = { Text("Media URI (optional)") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                        )
                        OutlinedTextField(
                            value = inputMediaCaptionDraft,
                            onValueChange = { inputMediaCaptionDraft = it },
                            label = { Text("Caption") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                        OutlinedTextField(
                            value = inputNotesDraft,
                            onValueChange = { inputNotesDraft = it },
                            label = { Text("Notes") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(
                        onClick = {
                            issueDraftAttachments = emptyList()
                            activeInputSheet = null
                        },
                    ) { Text("Cancel") }
                    Button(
                        onClick = {
                            val occurredAtMs = parseIsoDateMillis(inputDateDraft) ?: System.currentTimeMillis()
                            when (selectedSheet) {
                                GameRoomInputSheet.CleanGlass -> store.addEvent(
                                    machineID = selectedMachineFromAll.id,
                                    type = MachineEventType.glassCleaned,
                                    category = MachineEventCategory.service,
                                    summary = "Clean Glass",
                                    occurredAtMs = occurredAtMs,
                                    notes = inputNotesDraft.ifBlank { null },
                                    consumablesUsed = inputConsumableDraft.ifBlank { null },
                                )
                                GameRoomInputSheet.CleanPlayfield -> store.addEvent(
                                    machineID = selectedMachineFromAll.id,
                                    type = MachineEventType.playfieldCleaned,
                                    category = MachineEventCategory.service,
                                    summary = "Clean Playfield",
                                    occurredAtMs = occurredAtMs,
                                    notes = inputNotesDraft.ifBlank { null },
                                    consumablesUsed = inputConsumableDraft.ifBlank { null },
                                )
                                GameRoomInputSheet.SwapBalls -> store.addEvent(
                                    machineID = selectedMachineFromAll.id,
                                    type = MachineEventType.ballsReplaced,
                                    category = MachineEventCategory.service,
                                    summary = "Swap Balls",
                                    occurredAtMs = occurredAtMs,
                                    notes = inputNotesDraft.ifBlank { null },
                                )
                                GameRoomInputSheet.CheckPitch -> store.addEvent(
                                    machineID = selectedMachineFromAll.id,
                                    type = MachineEventType.pitchChecked,
                                    category = MachineEventCategory.service,
                                    summary = "Check Pitch",
                                    occurredAtMs = occurredAtMs,
                                    notes = inputNotesDraft.ifBlank { null },
                                    pitchValue = inputPitchValueDraft.toDoubleOrNull(),
                                    pitchMeasurementPoint = inputPitchPointDraft.ifBlank { null },
                                )
                                GameRoomInputSheet.LevelMachine -> store.addEvent(
                                    machineID = selectedMachineFromAll.id,
                                    type = MachineEventType.machineLeveled,
                                    category = MachineEventCategory.service,
                                    summary = "Level Machine",
                                    occurredAtMs = occurredAtMs,
                                    notes = inputNotesDraft.ifBlank { null },
                                )
                                GameRoomInputSheet.GeneralInspection -> store.addEvent(
                                    machineID = selectedMachineFromAll.id,
                                    type = MachineEventType.generalInspection,
                                    category = MachineEventCategory.service,
                                    summary = "General Inspection",
                                    occurredAtMs = occurredAtMs,
                                    notes = inputNotesDraft.ifBlank { null },
                                )
                                GameRoomInputSheet.LogIssue -> {
                                    val issueID = store.openIssue(
                                        machineID = selectedMachineFromAll.id,
                                        symptom = inputIssueSymptomDraft,
                                        severity = runCatching { MachineIssueSeverity.valueOf(inputIssueSeverityDraft) }.getOrDefault(MachineIssueSeverity.medium),
                                        subsystem = runCatching { MachineIssueSubsystem.valueOf(inputIssueSubsystemDraft) }.getOrDefault(MachineIssueSubsystem.other),
                                        openedAtMs = occurredAtMs,
                                        diagnosis = inputIssueDiagnosisDraft.ifBlank { null },
                                    )
                                    var lastAttachmentEventID: String? = null
                                    issueDraftAttachments.forEach { attachment ->
                                        lastAttachmentEventID = store.addEvent(
                                            machineID = selectedMachineFromAll.id,
                                            type = if (attachment.kind == MachineAttachmentKind.photo) MachineEventType.photoAdded else MachineEventType.videoAdded,
                                            category = MachineEventCategory.media,
                                            summary = if (attachment.kind == MachineAttachmentKind.photo) "Issue photo added" else "Issue video added",
                                            occurredAtMs = occurredAtMs,
                                            linkedIssueID = issueID,
                                        )
                                        store.addAttachment(
                                            machineID = selectedMachineFromAll.id,
                                            ownerType = MachineAttachmentOwnerType.issue,
                                            ownerID = issueID,
                                            kind = attachment.kind,
                                            uri = attachment.uri,
                                            caption = attachment.caption,
                                        )
                                    }
                                    if (lastAttachmentEventID != null) {
                                        selectedLogEventID = lastAttachmentEventID
                                        machineSubview = GameRoomMachineSubview.Log
                                    }
                                }
                                GameRoomInputSheet.ResolveIssue -> {
                                    val issueID = inputResolveIssueIDDraft
                                    if (!issueID.isNullOrBlank()) {
                                        store.resolveIssue(issueID, inputNotesDraft.ifBlank { null }, resolvedAtMs = occurredAtMs)
                                    }
                                }
                                GameRoomInputSheet.OwnershipUpdate -> {
                                    val type = runCatching { MachineEventType.valueOf(inputOwnershipTypeDraft) }.getOrDefault(MachineEventType.moved)
                                    store.addEvent(
                                        machineID = selectedMachineFromAll.id,
                                        type = type,
                                        category = MachineEventCategory.ownership,
                                        summary = inputSummaryDraft.ifBlank { type.name.replaceFirstChar { it.uppercase() } },
                                        occurredAtMs = occurredAtMs,
                                        notes = inputNotesDraft.ifBlank { null },
                                    )
                                }
                                GameRoomInputSheet.InstallMod -> store.addEvent(
                                    machineID = selectedMachineFromAll.id,
                                    type = MachineEventType.modInstalled,
                                    category = MachineEventCategory.mod,
                                    summary = inputSummaryDraft.ifBlank { "Install Mod" },
                                    occurredAtMs = occurredAtMs,
                                    notes = inputNotesDraft.ifBlank { null },
                                    partsUsed = inputDetailsDraft.ifBlank { null },
                                )
                                GameRoomInputSheet.ReplacePart -> store.addEvent(
                                    machineID = selectedMachineFromAll.id,
                                    type = MachineEventType.partReplaced,
                                    category = MachineEventCategory.service,
                                    summary = inputSummaryDraft.ifBlank { "Replace Part" },
                                    occurredAtMs = occurredAtMs,
                                    notes = inputNotesDraft.ifBlank { null },
                                    partsUsed = inputDetailsDraft.ifBlank { null },
                                )
                                GameRoomInputSheet.LogPlays -> store.addEvent(
                                    machineID = selectedMachineFromAll.id,
                                    type = MachineEventType.custom,
                                    category = MachineEventCategory.custom,
                                    summary = "Log Plays (Total ${inputPlayTotalDraft.toIntOrNull() ?: 0})",
                                    occurredAtMs = occurredAtMs,
                                    notes = inputNotesDraft.ifBlank { null },
                                    playCountAtEvent = inputPlayTotalDraft.toIntOrNull(),
                                )
                                GameRoomInputSheet.AddMedia -> {
                                    val kind = runCatching { MachineAttachmentKind.valueOf(inputMediaKindDraft) }.getOrDefault(MachineAttachmentKind.photo)
                                    val manualURI = inputMediaURIDraft.trim()
                                    if (manualURI.isNotBlank()) {
                                        val summary = if (kind == MachineAttachmentKind.photo) "Photo added" else "Video added"
                                        val eventID = store.addEvent(
                                            machineID = selectedMachineFromAll.id,
                                            type = if (kind == MachineAttachmentKind.photo) MachineEventType.photoAdded else MachineEventType.videoAdded,
                                            category = MachineEventCategory.media,
                                            summary = summary,
                                            occurredAtMs = occurredAtMs,
                                            notes = inputNotesDraft.ifBlank { null },
                                        )
                                        store.addAttachment(
                                            machineID = selectedMachineFromAll.id,
                                            ownerType = MachineAttachmentOwnerType.event,
                                            ownerID = eventID,
                                            kind = kind,
                                            uri = manualURI,
                                            caption = inputMediaCaptionDraft.ifBlank { null },
                                        )
                                    } else {
                                        pendingMediaMachineID = selectedMachineFromAll.id
                                        pendingMediaOwnerType = MachineAttachmentOwnerType.event.name
                                        pendingMediaOwnerID = null
                                        pendingMediaOccurredAtMs = occurredAtMs
                                        pendingMediaCaptionDraft = inputMediaCaptionDraft
                                        pendingMediaNotesDraft = inputNotesDraft
                                        if (kind == MachineAttachmentKind.photo) {
                                            addPhotoLauncher.launch(arrayOf("image/*"))
                                        } else {
                                            addVideoLauncher.launch(arrayOf("video/*"))
                                        }
                                    }
                                }
                            }

                            inputNotesDraft = ""
                            inputConsumableDraft = ""
                            inputPitchValueDraft = ""
                            inputPitchPointDraft = ""
                            inputIssueSymptomDraft = ""
                            inputIssueDiagnosisDraft = ""
                            inputSummaryDraft = ""
                            inputDetailsDraft = ""
                            inputMediaCaptionDraft = ""
                            inputMediaKindDraft = MachineAttachmentKind.photo.name
                            inputMediaURIDraft = ""
                            issueDraftAttachments = emptyList()
                            activeInputSheet = null
                        },
                        enabled = when (selectedSheet) {
                            GameRoomInputSheet.LogIssue -> inputIssueSymptomDraft.isNotBlank()
                            GameRoomInputSheet.ResolveIssue -> !inputResolveIssueIDDraft.isNullOrBlank()
                            GameRoomInputSheet.LogPlays -> inputPlayTotalDraft.isNotBlank()
                            else -> true
                        },
                    ) {
                        Text("Save")
                    }
                }
            }
        }
    }

    if (editingEventID != null) {
        ModalBottomSheet(
            onDismissRequest = { editingEventID = null },
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "Edit Log Entry",
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.SemiBold,
                )
                OutlinedTextField(
                    value = editEventDateDraft,
                    onValueChange = { editEventDateDraft = it },
                    label = { Text("Date (YYYY-MM-DD)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = editEventSummaryDraft,
                    onValueChange = { editEventSummaryDraft = it },
                    label = { Text("Summary") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = editEventNotesDraft,
                    onValueChange = { editEventNotesDraft = it },
                    label = { Text("Notes") },
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = { editingEventID = null }) { Text("Cancel") }
                    Button(
                        onClick = {
                            val id = editingEventID ?: return@Button
                            val occurredAtMs = parseIsoDateMillis(editEventDateDraft) ?: System.currentTimeMillis()
                            store.updateEvent(id, occurredAtMs, editEventSummaryDraft, editEventNotesDraft)
                            editingEventID = null
                        },
                        enabled = editEventSummaryDraft.isNotBlank(),
                    ) {
                        Text("Save")
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
    }

    if (mediaPreviewAttachment != null) {
        MediaPreviewDialog(
            attachment = mediaPreviewAttachment,
            onClose = { mediaPreviewAttachmentID = null },
            onEdit = {
                editingAttachmentID = mediaPreviewAttachment.id
                editAttachmentCaptionDraft = mediaPreviewAttachment.caption.orEmpty()
                val linkedNotes = if (mediaPreviewAttachment.ownerType == MachineAttachmentOwnerType.event) {
                    store.state.events.firstOrNull { it.id == mediaPreviewAttachment.ownerID }?.notes.orEmpty()
                } else {
                    ""
                }
                editAttachmentNotesDraft = linkedNotes
            },
            onDelete = {
                store.deleteAttachmentAndLinkedEvent(mediaPreviewAttachment.id)
                mediaPreviewAttachmentID = null
            },
        )
    }

    if (editingAttachment != null) {
        ModalBottomSheet(
            onDismissRequest = { editingAttachmentID = null },
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "Edit Media",
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.SemiBold,
                )
                OutlinedTextField(
                    value = editAttachmentCaptionDraft,
                    onValueChange = { editAttachmentCaptionDraft = it },
                    label = { Text("Caption") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = editAttachmentNotesDraft,
                    onValueChange = { editAttachmentNotesDraft = it },
                    label = { Text("Notes") },
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = { editingAttachmentID = null }) { Text("Cancel") }
                    Button(onClick = {
                        val attachment = editingAttachment ?: return@Button
                        store.updateAttachment(
                            id = attachment.id,
                            caption = editAttachmentCaptionDraft,
                            notes = editAttachmentNotesDraft,
                        )
                        editingAttachmentID = null
                    }) {
                        Text("Save")
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
    }
}

internal fun makeImportDraftRow(
    machine: PinsideImportedMachine,
    catalogLoader: GameRoomCatalogLoader,
): ImportDraftRow {
    val scored = scoredCatalogSuggestions(machine, catalogLoader)
    val suggestions = scored.map { it.first.catalogGameID }
    val top = scored.firstOrNull()
    return ImportDraftRow(
        id = machine.id,
        sourceItemKey = machine.slug,
        rawTitle = machine.rawTitle,
        rawVariant = machine.rawVariant,
        matchConfidence = importMatchConfidence(top?.second ?: 0),
        suggestions = suggestions,
        fingerprint = machine.fingerprint,
        selectedCatalogGameID = top?.first?.catalogGameID,
        selectedVariant = machine.rawVariant,
        rawPurchaseDateText = machine.rawPurchaseDateText,
        normalizedPurchaseDateMs = machine.normalizedPurchaseDateMs,
    )
}

private fun scoredCatalogSuggestions(
    machine: PinsideImportedMachine,
    catalogLoader: GameRoomCatalogLoader,
): List<Pair<GameRoomCatalogGame, Int>> {
    val normalizedRawTitle = normalizeImportText(machine.rawTitle)
    val normalizedVariant = normalizeImportText(machine.rawVariant.orEmpty())
    return catalogLoader.games.map { game ->
        val normalizedGameTitle = normalizeImportText(game.displayTitle)
        var score = 0

        if (normalizedRawTitle.isNotBlank()) {
            if (normalizedRawTitle == normalizedGameTitle) {
                score += 120
            } else if (
                normalizedGameTitle.contains(normalizedRawTitle) ||
                normalizedRawTitle.contains(normalizedGameTitle)
            ) {
                score += 80
            } else {
                score += tokenOverlapScore(normalizedRawTitle, normalizedGameTitle)
            }
        }
        if (normalizedVariant.isNotBlank()) {
            val variants = catalogLoader.variantOptions(game.catalogGameID).map(::normalizeImportText)
            if (variants.contains(normalizedVariant)) score += 20
        }
        game to score
    }.filter { (_, score) -> score > 0 }
        .sortedWith(
            compareByDescending<Pair<GameRoomCatalogGame, Int>> { it.second }
                .thenBy { it.first.displayTitle.lowercase() },
        )
        .take(3)
}

private fun importMatchConfidence(score: Int): MachineImportMatchConfidence {
    return when {
        score >= 120 -> MachineImportMatchConfidence.high
        score >= 80 -> MachineImportMatchConfidence.medium
        score > 0 -> MachineImportMatchConfidence.low
        else -> MachineImportMatchConfidence.manual
    }
}

private fun tokenOverlapScore(lhs: String, rhs: String): Int {
    val lhsSet = lhs.split(" ").filter { it.isNotBlank() }.toSet()
    val rhsSet = rhs.split(" ").filter { it.isNotBlank() }.toSet()
    if (lhsSet.isEmpty() || rhsSet.isEmpty()) return 0
    val intersection = lhsSet.intersect(rhsSet).size
    if (intersection == 0) return 0
    return ((intersection.toDouble() / maxOf(lhsSet.size, rhsSet.size)) * 70.0).toInt()
}

private fun normalizeImportText(value: String): String {
    return value
        .lowercase(Locale.US)
        .replace(Regex("[^a-z0-9 ]"), " ")
        .replace(Regex("\\s+"), " ")
        .trim()
}

private fun normalizeFirstOfMonthMs(rawValue: String?): Long? {
    val raw = rawValue?.trim().orEmpty()
    if (raw.isBlank()) return null

    val monthYearFormatters = listOf(
        formatter("MMMM uuuu"),
        formatter("MMM uuuu"),
        formatter("M/uuuu"),
        formatter("MM/uuuu"),
        formatter("M-uuuu"),
        formatter("MM-uuuu"),
        formatter("uuuu-MM"),
        formatter("uuuu/M"),
    )
    monthYearFormatters.forEach { formatter ->
        val parsed = runCatching { YearMonth.parse(raw, formatter) }.getOrNull() ?: return@forEach
        return parsed.atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    }

    val fullDateFormatters = listOf(
        formatter("uuuu-MM-dd"),
        formatter("M/d/uuuu"),
        formatter("MM/dd/uuuu"),
        formatter("MMM d, uuuu"),
        formatter("MMMM d, uuuu"),
    )
    fullDateFormatters.forEach { formatter ->
        val parsed = runCatching { LocalDate.parse(raw, formatter) }.getOrNull() ?: return@forEach
        val month = YearMonth.from(parsed)
        return month.atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    }

    return null
}

private fun formatter(pattern: String): DateTimeFormatter {
    return DateTimeFormatterBuilder()
        .parseCaseInsensitive()
        .appendPattern(pattern)
        .toFormatter(Locale.US)
        .withResolverStyle(ResolverStyle.SMART)
}

internal fun duplicateWarningMessage(
    row: ImportDraftRow,
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
): String? {
    if (store.hasImportFingerprint(row.fingerprint)) {
        return "Already imported previously."
    }
    val selectedCatalogID = row.selectedCatalogGameID ?: return null
    val selectedGame = catalogLoader.game(selectedCatalogID) ?: return null
    val selectedVariant = row.selectedVariant ?: row.rawVariant
    val existing = store.existingOwnedMachine(selectedGame.catalogGameID, selectedVariant) ?: return null
    return if (!existing.displayVariant.isNullOrBlank()) {
        "Duplicate of existing machine: ${existing.displayTitle} (${existing.displayVariant})."
    } else {
        "Duplicate of existing machine: ${existing.displayTitle}."
    }
}

internal fun needsImportReview(
    row: ImportDraftRow,
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
): Boolean {
    return row.matchConfidence != MachineImportMatchConfidence.high ||
        row.selectedCatalogGameID.isNullOrBlank() ||
        duplicateWarningMessage(row, store, catalogLoader) != null
}

@Composable
internal fun MatchConfidenceBadge(confidence: MachineImportMatchConfidence) {
    val badgeColor = when (confidence) {
        MachineImportMatchConfidence.high -> Color(0xFF53A653)
        MachineImportMatchConfidence.medium -> Color(0xFFF2C14E)
        MachineImportMatchConfidence.low,
        MachineImportMatchConfidence.manual -> Color(0xFFE0524D)
    }
    Text(
        text = confidence.name.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() },
        color = Color.White,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
            .background(badgeColor, RoundedCornerShape(999.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

@Composable
internal fun GameRoomLogRow(
    event: MachineEvent,
    mediaCount: Int,
    selected: Boolean,
    revealedRowID: String?,
    onRevealedRowIDChange: (String?) -> Unit,
    onSelect: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    val actionWidth = 132.dp
    val actionWidthPx = with(LocalDensity.current) { actionWidth.toPx() }
    var rowHeightPx by rememberSaveable(event.id) { mutableIntStateOf(0) }
    val rowHeightDp = with(LocalDensity.current) {
        if (rowHeightPx > 0) rowHeightPx.toDp() else 40.dp
    }
    var offsetX by rememberSaveable(event.id) { mutableFloatStateOf(0f) }
    val revealProgress = (kotlin.math.abs(offsetX) / actionWidthPx).coerceIn(0f, 1f)
    val dragState = rememberDraggableState { delta ->
        offsetX = (offsetX + delta).coerceIn(-actionWidthPx, 0f)
    }

    LaunchedEffect(revealedRowID) {
        if (revealedRowID != event.id && offsetX != 0f) {
            offsetX = 0f
        }
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 6.dp, vertical = 4.dp)
            .defaultMinSize(minHeight = 40.dp)
            .clip(RoundedCornerShape(8.dp)),
    ) {
        Row(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .width(actionWidth)
                .height(rowHeightDp)
                .alpha(if (revealProgress > 0f) 1f else 0f),
        ) {
            GameRoomSwipeRevealActionButton(
                modifier = Modifier.weight(1f),
                tint = Color(0xFF0A84FF),
                icon = Icons.Outlined.Edit,
                contentDescription = "Edit entry",
                onClick = onEdit,
            )
            GameRoomSwipeRevealActionButton(
                modifier = Modifier.weight(1f),
                tint = Color(0xFFFF3B30),
                icon = Icons.Outlined.Delete,
                contentDescription = "Delete entry",
                onClick = onDelete,
            )
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight()
                .clip(RoundedCornerShape(8.dp))
                .background(
                    MaterialTheme.colorScheme.surfaceContainerLow.copy(alpha = 1f - revealProgress),
                )
                .border(
                    width = 1.dp,
                    color = MaterialTheme.colorScheme.outline.copy(alpha = 0.72f - (0.22f * revealProgress)),
                    shape = RoundedCornerShape(8.dp),
                )
                .offset { IntOffset(offsetX.toInt(), 0) }
                .onSizeChanged { rowHeightPx = it.height }
                .draggable(
                    state = dragState,
                    orientation = Orientation.Horizontal,
                    onDragStopped = {
                        val reveal = offsetX <= (-actionWidthPx * 0.2f)
                        offsetX = if (reveal) -actionWidthPx else 0f
                        onRevealedRowIDChange(if (reveal) event.id else null)
                    },
                ),
        ) {
            Row(
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        if (selected) {
                            MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.35f)
                        } else {
                            Color.Transparent
                        },
                        RoundedCornerShape(8.dp),
                    )
                    .clickable {
                        if (revealedRowID != null) {
                            onRevealedRowIDChange(null)
                            return@clickable
                        }
                        onSelect()
                    }
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    StyledPracticeJournalSummaryText(
                        summary = event.summary,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Text(
                        text = "${displayMachineEventCategory(event.category)} • ${formatTimestamp(event.occurredAtMs)} • $mediaCount media",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@Composable
private fun RowScope.GameRoomSwipeRevealActionButton(
    modifier: Modifier,
    tint: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .padding(horizontal = 1.dp)
            .fillMaxHeight()
            .background(tint, shape = RoundedCornerShape(6.dp))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = contentDescription, tint = Color.White)
    }
}

@Composable
internal fun MediaAttachmentGrid(
    attachments: List<MachineAttachment>,
    onOpen: (MachineAttachment) -> Unit,
) {
    val rows = attachments.chunked(2)
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        rows.forEach { rowItems ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                rowItems.forEach { attachment ->
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(10.dp))
                            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(10.dp))
                            .clickable { onOpen(attachment) },
                    ) {
                        AsyncImage(
                            model = attachment.uri,
                            contentDescription = attachment.caption ?: "Media attachment",
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .fillMaxSize()
                                .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(10.dp)),
                        )
                        Text(
                            text = if (attachment.kind == MachineAttachmentKind.video) "Video" else "Photo",
                            color = Color.White,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier
                                .padding(6.dp)
                                .background(Color.Black.copy(alpha = 0.45f), RoundedCornerShape(999.dp))
                                .padding(horizontal = 8.dp, vertical = 2.dp),
                        )
                    }
                }
                if (rowItems.size == 1) {
                    Box(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun MediaPreviewDialog(
    attachment: MachineAttachment,
    onClose: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    var controlsVisible by remember { mutableStateOf(true) }
    var scale by remember { mutableFloatStateOf(1f) }
    var offsetX by remember { mutableFloatStateOf(0f) }
    var offsetY by remember { mutableFloatStateOf(0f) }

    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .iosEdgeSwipeBack(enabled = true, onBack = onClose)
                .clipToBounds()
                .pointerInput(attachment.id) {
                    detectTapGestures(
                        onDoubleTap = {
                            if (scale > 1.05f) {
                                scale = 1f
                                offsetX = 0f
                                offsetY = 0f
                            } else {
                                scale = 2f
                            }
                        },
                        onTap = { controlsVisible = !controlsVisible },
                    )
                }
                .pointerInput(attachment.id) {
                    detectTransformGestures { _, pan, zoom, _ ->
                        val nextScale = (scale * zoom).coerceIn(1f, 4f)
                        scale = nextScale
                        if (nextScale <= 1.01f) {
                            offsetX = 0f
                            offsetY = 0f
                        } else {
                            offsetX += pan.x
                            offsetY += pan.y
                        }
                    }
                },
        ) {
            AsyncImage(
                model = attachment.uri,
                contentDescription = attachment.caption ?: "Media preview",
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer(
                        scaleX = scale,
                        scaleY = scale,
                        translationX = offsetX,
                        translationY = offsetY,
                    ),
            )

            if (controlsVisible) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    TextButton(onClick = onClose) { Text("Back", color = Color.White) }
                    TextButton(onClick = onEdit) { Text("Edit", color = Color.White) }
                    TextButton(onClick = onDelete) { Text("Delete", color = Color.White) }
                }
                if (!attachment.caption.isNullOrBlank()) {
                    Text(
                        text = attachment.caption,
                        color = Color.White,
                        modifier = Modifier
                            .align(Alignment.BottomStart)
                            .padding(14.dp)
                            .background(Color.Black.copy(alpha = 0.45f), RoundedCornerShape(10.dp))
                            .padding(horizontal = 10.dp, vertical = 6.dp),
                    )
                }
            }
        }
    }
}
