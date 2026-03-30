package com.pillyliu.pinprofandroid.gameroom

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit
import com.pillyliu.pinprofandroid.library.LibrarySourceEvents

internal class GameRoomStore(private val context: Context) {
    companion object {
        const val STORAGE_KEY = "gameroom-state-json"
        const val LEGACY_STORAGE_KEY = "gameroom-state-v1"
        const val PREFS_NAME = "practice-upgrade-state-v2"
    }

    var state by mutableStateOf(GameRoomPersistedState.empty)
        private set

    var snapshots by mutableStateOf<Map<String, OwnedMachineSnapshot>>(emptyMap())
        private set

    var lastErrorMessage by mutableStateOf<String?>(null)
        private set

    private var didLoad = false
    private val prefs by lazy { context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE) }

    fun loadIfNeeded() {
        if (didLoad) return
        didLoad = true
        loadState()
    }

    fun loadState() {
        when (val result = GameRoomStateCodec.loadFromPreferences(
            prefs = prefs,
            storageKey = STORAGE_KEY,
            legacyStorageKey = LEGACY_STORAGE_KEY,
        )) {
            GameRoomStateCodec.LoadResult.Missing -> {
                lastErrorMessage = null
                state = GameRoomPersistedState.empty
                recomputeSnapshots()
            }

            is GameRoomStateCodec.LoadResult.Loaded -> {
                state = result.state.copy(schemaVersion = GameRoomPersistedState.CURRENT_SCHEMA_VERSION)
                recomputeSnapshots()
                if (result.needsResave) {
                    saveState()
                }
                lastErrorMessage = result.noticeMessage
            }

            is GameRoomStateCodec.LoadResult.Failed -> {
                state = GameRoomPersistedState.empty
                recomputeSnapshots()
                lastErrorMessage = result.message
            }
        }
    }

    fun saveState() {
        runCatching {
            val encoded = GameRoomStateCodec.encode(
                state.copy(schemaVersion = GameRoomPersistedState.CURRENT_SCHEMA_VERSION),
            )
            prefs.edit {
                putString(STORAGE_KEY, encoded)
                remove(LEGACY_STORAGE_KEY)
            }
            LibrarySourceEvents.notifyChanged()
            lastErrorMessage = null
        }.onFailure { error ->
            lastErrorMessage = "Failed to save GameRoom data: ${error.localizedMessage}"
        }
    }

    val venueName: String
        get() = state.venueName.trim().ifBlank { GameRoomPersistedState.DEFAULT_VENUE_NAME }

    val activeMachines: List<OwnedMachine>
        get() = activeGameRoomMachines(state)

    val archivedMachines: List<OwnedMachine>
        get() = archivedGameRoomMachines(state)

    fun area(id: String?): GameRoomArea? {
        if (id.isNullOrBlank()) return null
        return state.areas.firstOrNull { it.id == id }
    }

    fun snapshot(machineID: String): OwnedMachineSnapshot {
        return snapshots[machineID] ?: defaultOwnedMachineSnapshot(machineID)
    }

    fun addOwnedMachine(
        catalogGameID: String,
        opdbID: String?,
        canonicalPracticeIdentity: String,
        displayTitle: String,
        displayVariant: String?,
        manufacturer: String?,
        year: Int?,
    ): String {
        val result = gameRoomStateWithAddedOwnedMachine(
            state = state,
            catalogGameID = catalogGameID,
            opdbID = opdbID,
            canonicalPracticeIdentity = canonicalPracticeIdentity,
            displayTitle = displayTitle,
            displayVariant = displayVariant,
            manufacturer = manufacturer,
            year = year,
            now = System.currentTimeMillis(),
        )
        state = result.state
        saveAndRecompute()
        return result.machineId
    }

    fun updateMachine(
        id: String,
        areaID: String?,
        groupNumber: Int?,
        position: Int?,
        status: OwnedMachineStatus,
        opdbID: String?,
        canonicalPracticeIdentity: String? = null,
        displayTitle: String? = null,
        displayVariant: String?,
        manufacturer: String? = null,
        year: Int? = null,
        purchaseSource: String? = null,
        serialNumber: String? = null,
        ownershipNotes: String? = null,
    ) {
        state = gameRoomStateWithUpdatedMachine(
            state = state,
            id = id,
            areaID = areaID,
            groupNumber = groupNumber,
            position = position,
            status = status,
            opdbID = opdbID,
            canonicalPracticeIdentity = canonicalPracticeIdentity,
            displayTitle = displayTitle,
            displayVariant = displayVariant,
            manufacturer = manufacturer,
            year = year,
            purchaseSource = purchaseSource,
            serialNumber = serialNumber,
            ownershipNotes = ownershipNotes,
            now = System.currentTimeMillis(),
        )
        saveAndRecompute()
    }

    fun deleteMachine(id: String) {
        state = gameRoomStateWithDeletedMachine(state, id)
        saveAndRecompute()
    }

    fun hasImportFingerprint(fingerprint: String): Boolean {
        return gameRoomStateHasImportFingerprint(state, fingerprint)
    }

    fun hasOwnedMachine(catalogGameID: String, displayVariant: String?): Boolean {
        return existingOwnedMachine(catalogGameID = catalogGameID, displayVariant = displayVariant) != null
    }

    fun existingOwnedMachine(catalogGameID: String, displayVariant: String?): OwnedMachine? {
        return gameRoomStateExistingOwnedMachine(state, catalogGameID, displayVariant)
    }

    fun importOwnedMachine(
        game: GameRoomCatalogGame,
        sourceUserOrURL: String,
        sourceItemKey: String?,
        rawTitle: String,
        rawVariant: String?,
        rawPurchaseDateText: String?,
        normalizedPurchaseDateMs: Long?,
        matchConfidence: MachineImportMatchConfidence,
        fingerprint: String?,
    ): String {
        val result = gameRoomStateWithImportedMachine(
            state = state,
            game = game,
            sourceUserOrURL = sourceUserOrURL,
            sourceItemKey = sourceItemKey,
            rawTitle = rawTitle,
            rawVariant = rawVariant,
            rawPurchaseDateText = rawPurchaseDateText,
            normalizedPurchaseDateMs = normalizedPurchaseDateMs,
            matchConfidence = matchConfidence,
            fingerprint = fingerprint,
            now = System.currentTimeMillis(),
        )
        state = result.state
        saveAndRecompute()
        return result.machineId
    }

    fun migrateOwnedMachineOpdbIds(catalogLoader: GameRoomCatalogLoader) {
        val migratedMachines = migratedGameRoomOwnedMachines(
            state = state,
            catalogLoader = catalogLoader,
            now = System.currentTimeMillis(),
        )
        if (migratedMachines != null) {
            state = state.copy(ownedMachines = migratedMachines)
            saveAndRecompute()
        }
    }

    fun upsertArea(id: String? = null, name: String, areaOrder: Int) {
        state = gameRoomStateWithUpsertedArea(
            state = state,
            id = id,
            name = name,
            areaOrder = areaOrder,
            now = System.currentTimeMillis(),
        )
        saveAndRecompute()
    }

    fun deleteArea(id: String) {
        state = gameRoomStateWithDeletedArea(state, id, System.currentTimeMillis())
        saveAndRecompute()
    }

    fun updateVenueName(rawName: String) {
        state = state.copy(
            venueName = normalizedGameRoomVenueName(rawName),
        )
        saveAndRecompute()
    }

    fun addEvent(
        machineID: String,
        type: MachineEventType,
        category: MachineEventCategory,
        summary: String,
        occurredAtMs: Long? = null,
        notes: String? = null,
        partsUsed: String? = null,
        consumablesUsed: String? = null,
        pitchValue: Double? = null,
        pitchMeasurementPoint: String? = null,
        playCountAtEvent: Int? = null,
        linkedIssueID: String? = null,
    ): String {
        val (nextState, eventID) = gameRoomStateWithAddedEvent(
            state = state,
            machineID = machineID,
            type = type,
            category = category,
            summary = summary,
            occurredAtMs = occurredAtMs,
            notes = notes,
            partsUsed = partsUsed,
            consumablesUsed = consumablesUsed,
            pitchValue = pitchValue,
            pitchMeasurementPoint = pitchMeasurementPoint,
            playCountAtEvent = playCountAtEvent,
            linkedIssueID = linkedIssueID,
            now = System.currentTimeMillis(),
        )
        state = nextState
        saveAndRecompute()
        return eventID
    }

    fun updateEvent(id: String, occurredAtMs: Long, summary: String, notes: String?) {
        state = gameRoomStateWithUpdatedEvent(state, id, occurredAtMs, summary, notes, System.currentTimeMillis())
        saveAndRecompute()
    }

    fun deleteEvent(id: String) {
        state = gameRoomStateWithDeletedEvent(state, id)
        saveAndRecompute()
    }

    fun attachmentsForMachine(machineID: String): List<MachineAttachment> {
        return gameRoomAttachmentsForMachine(state, machineID)
    }

    fun attachmentsForEvent(eventID: String): List<MachineAttachment> {
        return gameRoomAttachmentsForEvent(state, eventID)
    }

    fun attachmentsForIssue(issueID: String): List<MachineAttachment> {
        return gameRoomAttachmentsForIssue(state, issueID)
    }

    fun addAttachment(
        machineID: String,
        ownerType: MachineAttachmentOwnerType,
        ownerID: String,
        kind: MachineAttachmentKind,
        uri: String,
        thumbnailURI: String? = null,
        caption: String? = null,
    ): String {
        val result = gameRoomStateWithAddedAttachment(
            state = state,
            machineID = machineID,
            ownerType = ownerType,
            ownerID = ownerID,
            kind = kind,
            uri = uri,
            thumbnailURI = thumbnailURI,
            caption = caption,
        ) ?: return ""
        state = result.first
        saveAndRecompute()
        return result.second
    }

    fun deleteAttachment(id: String) {
        state = gameRoomStateWithDeletedAttachment(state, id)
        saveAndRecompute()
    }

    fun updateAttachment(
        id: String,
        caption: String?,
        notes: String?,
    ) {
        state = gameRoomStateWithUpdatedAttachment(
            state = state,
            id = id,
            caption = caption,
            notes = notes,
            now = System.currentTimeMillis(),
        ) ?: return
        saveAndRecompute()
    }

    fun deleteAttachmentAndLinkedEvent(id: String) {
        state = gameRoomStateWithDeletedAttachmentAndLinkedEvent(state, id) ?: return
        saveAndRecompute()
    }

    fun openIssue(
        machineID: String,
        symptom: String,
        severity: MachineIssueSeverity = MachineIssueSeverity.medium,
        subsystem: MachineIssueSubsystem = MachineIssueSubsystem.other,
        openedAtMs: Long? = null,
        diagnosis: String? = null,
    ): String {
        val result = gameRoomStateWithOpenedIssue(
            state = state,
            machineID = machineID,
            symptom = symptom,
            severity = severity,
            subsystem = subsystem,
            openedAtMs = openedAtMs,
            diagnosis = diagnosis,
            now = System.currentTimeMillis(),
        )
        state = result.state
        saveAndRecompute()
        return result.issueId
    }

    fun resolveIssue(issueID: String, resolution: String?, resolvedAtMs: Long? = null) {
        state = gameRoomStateWithResolvedIssue(
            state = state,
            issueID = issueID,
            resolution = resolution,
            resolvedAtMs = resolvedAtMs,
            now = System.currentTimeMillis(),
        ) ?: return
        saveAndRecompute()
    }

    private fun recomputeSnapshots() {
        snapshots = computeOwnedMachineSnapshots(
            state = state,
            nowMs = System.currentTimeMillis(),
        )
    }

    private fun saveAndRecompute() {
        recomputeSnapshots()
        saveState()
    }
}
