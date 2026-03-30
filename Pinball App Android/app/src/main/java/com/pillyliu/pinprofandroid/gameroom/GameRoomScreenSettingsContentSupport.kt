package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.runtime.Composable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

@Composable
internal fun GameRoomScreenImportSettingsRouteContent(
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    pinsideImportService: GameRoomPinsideImportService,
    scope: CoroutineScope,
    importSourceInput: String,
    onImportSourceInputChange: (String) -> Unit,
    importSourceURL: String,
    onImportSourceURLChange: (String) -> Unit,
    importIsLoading: Boolean,
    onImportIsLoadingChange: (Boolean) -> Unit,
    importErrorMessage: String?,
    onImportErrorMessageChange: (String?) -> Unit,
    importResultMessage: String?,
    onImportResultMessageChange: (String?) -> Unit,
    importRows: List<ImportDraftRow>,
    onImportRowsChange: (List<ImportDraftRow>) -> Unit,
    importReviewFilter: ImportReviewFilter,
    onImportReviewFilterChange: (ImportReviewFilter) -> Unit,
) {
    GameRoomImportSettingsSection(
        store = store,
        catalogLoader = catalogLoader,
        importSourceInput = importSourceInput,
        onImportSourceInputChange = onImportSourceInputChange,
        importIsLoading = importIsLoading,
        importErrorMessage = importErrorMessage,
        importResultMessage = importResultMessage,
        importRows = importRows,
        importReviewFilter = importReviewFilter,
        onImportReviewFilterChange = onImportReviewFilterChange,
        onFetchCollection = {
            val input = importSourceInput.trim()
            if (!importIsLoading && input.isNotBlank()) {
                scope.launch {
                    onImportErrorMessageChange(null)
                    onImportResultMessageChange(null)
                    onImportIsLoadingChange(true)
                    try {
                        val result = fetchGameRoomImportRows(input, pinsideImportService, catalogLoader)
                        onImportSourceURLChange(result.sourceURL)
                        onImportRowsChange(result.rows)
                        onImportReviewFilterChange(ImportReviewFilter.All)
                    } catch (error: GameRoomPinsideImportException) {
                        onImportSourceURLChange("")
                        onImportRowsChange(emptyList())
                        onImportErrorMessageChange(error.userMessage)
                    } catch (_: Throwable) {
                        onImportSourceURLChange("")
                        onImportRowsChange(emptyList())
                        onImportErrorMessageChange("Could not load Pinside collection right now.")
                    } finally {
                        onImportIsLoadingChange(false)
                    }
                }
            }
        },
        onUpdateImportPurchaseDate = { rowID, updatedRaw ->
            onImportRowsChange(updateImportPurchaseDateRows(importRows, rowID, updatedRaw))
        },
        onUpdateImportMatch = { rowID, selectedCatalogGameID ->
            onImportRowsChange(updateImportMatchRows(importRows, rowID, selectedCatalogGameID, catalogLoader))
        },
        onUpdateImportVariant = { rowID, selectedVariant ->
            onImportRowsChange(updateImportVariantRows(importRows, rowID, selectedVariant))
        },
        onPerformImport = {
            onImportResultMessageChange(
                performGameRoomImport(
                    rows = importRows,
                    store = store,
                    catalogLoader = catalogLoader,
                    importSourceURL = importSourceURL,
                    importSourceInput = importSourceInput,
                ),
            )
        },
    )
}

@Composable
internal fun GameRoomScreenEditSettingsRouteContent(
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    nameExpanded: Boolean,
    onNameExpandedChange: (Boolean) -> Unit,
    venueNameDraft: String,
    onVenueNameDraftChange: (String) -> Unit,
    onSettingsSaveFeedback: (String) -> Unit,
    addMachineExpanded: Boolean,
    onAddMachineExpandedChange: (Boolean) -> Unit,
    areasExpanded: Boolean,
    onAreasExpandedChange: (Boolean) -> Unit,
    areaNameDraft: String,
    onAreaNameDraftChange: (String) -> Unit,
    areaOrderDraft: String,
    onAreaOrderDraftChange: (String) -> Unit,
    selectedAreaID: String?,
    onSelectedAreaIDChange: (String?) -> Unit,
    editMachinesExpanded: Boolean,
    onEditMachinesExpandedChange: (Boolean) -> Unit,
    allMachines: List<OwnedMachine>,
    selectedEditMachine: OwnedMachine?,
    onSelectedEditMachineChange: (String?) -> Unit,
    draftVariant: String,
    onDraftVariantChange: (String) -> Unit,
    draftAreaID: String?,
    onDraftAreaIDChange: (String?) -> Unit,
    draftStatus: String,
    onDraftStatusChange: (String) -> Unit,
    draftGroup: String,
    onDraftGroupChange: (String) -> Unit,
    draftPosition: String,
    onDraftPositionChange: (String) -> Unit,
    draftPurchaseSource: String,
    onDraftPurchaseSourceChange: (String) -> Unit,
    draftSerialNumber: String,
    onDraftSerialNumberChange: (String) -> Unit,
    draftOwnershipNotes: String,
    onDraftOwnershipNotesChange: (String) -> Unit,
) {
    GameRoomEditSettingsSection(
        context = GameRoomEditSettingsContext(
            store = store,
            catalogLoader = catalogLoader,
            nameExpanded = nameExpanded,
            onNameExpandedChange = onNameExpandedChange,
            venueNameDraft = venueNameDraft,
            onVenueNameDraftChange = onVenueNameDraftChange,
            onSaveVenueName = {
                store.updateVenueName(venueNameDraft)
                onVenueNameDraftChange(store.venueName)
            },
            onShowSaveFeedback = onSettingsSaveFeedback,
            addMachineExpanded = addMachineExpanded,
            onAddMachineExpandedChange = onAddMachineExpandedChange,
            catalogIsLoading = catalogLoader.isLoading,
            catalogErrorMessage = catalogLoader.errorMessage,
            areasExpanded = areasExpanded,
            onAreasExpandedChange = onAreasExpandedChange,
            areaNameDraft = areaNameDraft,
            onAreaNameDraftChange = onAreaNameDraftChange,
            areaOrderDraft = areaOrderDraft,
            onAreaOrderDraftChange = onAreaOrderDraftChange,
            onSaveArea = {
                store.upsertArea(
                    id = selectedAreaID,
                    name = areaNameDraft,
                    areaOrder = areaOrderDraft.toIntOrNull() ?: 1,
                )
                onSelectedAreaIDChange(null)
                onAreaNameDraftChange("")
                onAreaOrderDraftChange("1")
            },
            onResetAreaDraft = {
                onSelectedAreaIDChange(null)
                onAreaNameDraftChange("")
                onAreaOrderDraftChange("1")
            },
            onEditArea = { area ->
                onSelectedAreaIDChange(area.id)
                onAreaNameDraftChange(area.name)
                onAreaOrderDraftChange(area.areaOrder.toString())
            },
            onDeleteArea = { areaID -> store.deleteArea(areaID) },
            editMachinesExpanded = editMachinesExpanded,
            onEditMachinesExpandedChange = onEditMachinesExpandedChange,
            allMachines = allMachines,
            selectedEditMachine = selectedEditMachine,
            onSelectedEditMachineChange = { onSelectedEditMachineChange(it) },
            variantOptions = buildList {
                add("None")
                selectedEditMachine?.let { addAll(catalogLoader.variantOptions(it.catalogGameID)) }
            }.distinct(),
            draftVariant = draftVariant,
            onDraftVariantChange = onDraftVariantChange,
            draftAreaID = draftAreaID,
            onDraftAreaIDChange = onDraftAreaIDChange,
            draftStatus = draftStatus,
            onDraftStatusChange = onDraftStatusChange,
            draftGroup = draftGroup,
            onDraftGroupChange = onDraftGroupChange,
            draftPosition = draftPosition,
            onDraftPositionChange = onDraftPositionChange,
            draftPurchaseSource = draftPurchaseSource,
            onDraftPurchaseSourceChange = onDraftPurchaseSourceChange,
            draftSerialNumber = draftSerialNumber,
            onDraftSerialNumberChange = onDraftSerialNumberChange,
            draftOwnershipNotes = draftOwnershipNotes,
            onDraftOwnershipNotesChange = onDraftOwnershipNotesChange,
            onSaveMachine = {
                selectedEditMachine?.let { machine ->
                    saveEditedGameRoomMachine(
                        store = store,
                        catalogLoader = catalogLoader,
                        machine = machine,
                        draftAreaID = draftAreaID,
                        draftGroup = draftGroup,
                        draftPosition = draftPosition,
                        draftStatus = draftStatus,
                        draftVariant = draftVariant,
                        draftPurchaseSource = draftPurchaseSource,
                        draftSerialNumber = draftSerialNumber,
                        draftOwnershipNotes = draftOwnershipNotes,
                    )
                }
            },
            onDeleteMachine = {
                selectedEditMachine?.let { store.deleteMachine(it.id) }
            },
            onArchiveMachine = selectedEditMachine
                ?.takeIf { it.status != OwnedMachineStatus.archived }
                ?.let {
                    {
                        saveEditedGameRoomMachine(
                            store = store,
                            catalogLoader = catalogLoader,
                            machine = it,
                            draftAreaID = draftAreaID,
                            draftGroup = draftGroup,
                            draftPosition = draftPosition,
                            draftStatus = draftStatus,
                            draftVariant = draftVariant,
                            draftPurchaseSource = draftPurchaseSource,
                            draftSerialNumber = draftSerialNumber,
                            draftOwnershipNotes = draftOwnershipNotes,
                            forceStatus = OwnedMachineStatus.archived,
                        )
                    }
                },
        ),
    )
}
