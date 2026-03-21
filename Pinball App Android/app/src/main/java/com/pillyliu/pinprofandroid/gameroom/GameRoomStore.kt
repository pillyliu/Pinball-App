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
        val raw = prefs.getString(STORAGE_KEY, null) ?: prefs.getString(LEGACY_STORAGE_KEY, null)
        val loaded = raw?.let { GameRoomStateCodec.decode(it) } ?: GameRoomPersistedState.empty
        state = loaded.copy(schemaVersion = GameRoomPersistedState.CURRENT_SCHEMA_VERSION)
        recomputeSnapshots()
        if (prefs.getString(STORAGE_KEY, null) == null || prefs.contains(LEGACY_STORAGE_KEY)) {
            saveState()
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
        }.onFailure { error ->
            lastErrorMessage = "Failed to save GameRoom data: ${error.localizedMessage}"
        }
    }

    val venueName: String
        get() = state.venueName.trim().ifBlank { GameRoomPersistedState.DEFAULT_VENUE_NAME }

    val activeMachines: List<OwnedMachine>
        get() = state.ownedMachines
            .filter { it.status == OwnedMachineStatus.active || it.status == OwnedMachineStatus.loaned }
            .sortedWith(::compareMachines)

    val archivedMachines: List<OwnedMachine>
        get() = state.ownedMachines
            .filter { it.status != OwnedMachineStatus.active && it.status != OwnedMachineStatus.loaned }
            .sortedWith(::compareMachines)

    fun area(id: String?): GameRoomArea? {
        if (id.isNullOrBlank()) return null
        return state.areas.firstOrNull { it.id == id }
    }

    fun snapshot(machineID: String): OwnedMachineSnapshot {
        return snapshots[machineID] ?: OwnedMachineSnapshot(
            ownedMachineID = machineID,
            currentPlayCount = 0,
            lastGlassCleanedAtMs = null,
            lastPlayfieldCleanedAtMs = null,
            lastPlayfieldCleanerUsed = null,
            lastBallsServicedAtMs = null,
            lastBallsReplacedAtMs = null,
            currentBallSetNotes = null,
            lastPitchCheckedAtMs = null,
            currentPitchValue = null,
            currentPitchMeasurementPoint = null,
            lastLeveledAtMs = null,
            lastRubberServiceAtMs = null,
            lastFlipperServiceAtMs = null,
            lastGeneralInspectionAtMs = null,
            lastServiceAtMs = null,
            openIssueCount = 0,
            dueTaskCount = 0,
            attentionState = GameRoomAttentionState.gray,
        )
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
        val now = System.currentTimeMillis()
        val machine = OwnedMachine(
            catalogGameID = catalogGameID.trim(),
            opdbID = opdbID?.trim()?.ifBlank { null },
            canonicalPracticeIdentity = canonicalPracticeIdentity.trim(),
            displayTitle = displayTitle.trim().ifBlank { "Machine" },
            displayVariant = displayVariant?.trim()?.ifBlank { null },
            manufacturer = manufacturer?.trim()?.ifBlank { null },
            year = year,
            createdAtMs = now,
            updatedAtMs = now,
        )
        state = state.copy(ownedMachines = state.ownedMachines + machine)
        saveAndRecompute()
        return machine.id
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
        val now = System.currentTimeMillis()
        state = state.copy(
            ownedMachines = state.ownedMachines.map { machine ->
                if (machine.id != id) return@map machine
                machine.copy(
                    gameRoomAreaID = areaID?.trim()?.ifBlank { null },
                    groupNumber = groupNumber,
                    position = position,
                    status = status,
                    opdbID = normalizeOptionalString(opdbID),
                    canonicalPracticeIdentity = normalizeOptionalString(canonicalPracticeIdentity) ?: machine.canonicalPracticeIdentity,
                    displayTitle = normalizeOptionalString(displayTitle) ?: machine.displayTitle,
                    displayVariant = displayVariant?.trim()?.ifBlank { null },
                    manufacturer = normalizeOptionalString(manufacturer) ?: machine.manufacturer,
                    year = year ?: machine.year,
                    purchaseSource = normalizeOptionalString(purchaseSource),
                    serialNumber = normalizeOptionalString(serialNumber),
                    ownershipNotes = normalizeOptionalString(ownershipNotes),
                    updatedAtMs = now,
                )
            },
        )
        saveAndRecompute()
    }

    fun deleteMachine(id: String) {
        state = state.copy(
            ownedMachines = state.ownedMachines.filterNot { it.id == id },
            events = state.events.filterNot { it.ownedMachineID == id },
            issues = state.issues.filterNot { it.ownedMachineID == id },
            attachments = state.attachments.filterNot { it.ownedMachineID == id },
            reminderConfigs = state.reminderConfigs.filterNot { it.ownedMachineID == id },
            importRecords = state.importRecords.filterNot { it.createdOwnedMachineID == id },
        )
        saveAndRecompute()
    }

    fun hasImportFingerprint(fingerprint: String): Boolean {
        val normalizedFingerprint = fingerprint.trim().lowercase()
        if (normalizedFingerprint.isBlank()) return false
        return state.importRecords.any { record ->
            record.fingerprint?.trim()?.lowercase() == normalizedFingerprint
        }
    }

    fun hasOwnedMachine(catalogGameID: String, displayVariant: String?): Boolean {
        return existingOwnedMachine(catalogGameID = catalogGameID, displayVariant = displayVariant) != null
    }

    fun existingOwnedMachine(catalogGameID: String, displayVariant: String?): OwnedMachine? {
        val normalizedCatalogID = catalogGameID.trim().lowercase()
        if (normalizedCatalogID.isBlank()) return null
        val normalizedVariant = normalizeVariantKey(displayVariant)
        return state.ownedMachines.firstOrNull { machine ->
            machine.catalogGameID.trim().lowercase() == normalizedCatalogID &&
                normalizeVariantKey(machine.displayVariant) == normalizedVariant
        }
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
        val now = System.currentTimeMillis()
        val machine = OwnedMachine(
            catalogGameID = game.catalogGameID,
            opdbID = game.opdbID,
            canonicalPracticeIdentity = game.canonicalPracticeIdentity,
            displayTitle = game.displayTitle,
            displayVariant = rawVariant?.trim()?.ifBlank { null },
            importedSourceTitle = rawTitle.trim().ifBlank { null },
            manufacturer = game.manufacturer,
            year = game.year,
            purchaseDateMs = normalizedPurchaseDateMs,
            purchaseDateRawText = rawPurchaseDateText?.trim()?.ifBlank { null },
            status = OwnedMachineStatus.active,
            createdAtMs = now,
            updatedAtMs = now,
        )
        val importRecord = MachineImportRecord(
            source = MachineImportSource.pinside,
            sourceUserOrURL = sourceUserOrURL.trim().ifBlank { "pinside" },
            sourceItemKey = sourceItemKey?.trim()?.ifBlank { null },
            rawTitle = rawTitle.trim().ifBlank { game.displayTitle },
            rawVariant = rawVariant?.trim()?.ifBlank { null },
            rawPurchaseDateText = rawPurchaseDateText?.trim()?.ifBlank { null },
            normalizedPurchaseDateMs = normalizedPurchaseDateMs,
            matchedCatalogGameID = game.catalogGameID,
            matchConfidence = matchConfidence,
            createdOwnedMachineID = machine.id,
            importedAtMs = now,
            fingerprint = fingerprint?.trim()?.ifBlank { null },
        )
        state = state.copy(
            ownedMachines = state.ownedMachines + machine,
            importRecords = state.importRecords + importRecord,
        )
        saveAndRecompute()
        return machine.id
    }

    fun migrateOwnedMachineOpdbIds(catalogLoader: GameRoomCatalogLoader) {
        var didChange = false
        val migratedMachines = state.ownedMachines.map { machine ->
            val normalizedGame = catalogLoader.normalizedCatalogGame(machine)
            if (normalizedGame == null) {
                machine
            } else {
                val normalizedOPDBID = normalizedGame.opdbID.trim().ifBlank { null }
                val normalizedTitle = normalizedGame.displayTitle.trim().ifBlank { "Machine" }
                val normalizedVariant = normalizedGame.displayVariant?.trim()?.ifBlank { null }
                val currentOPDBID = machine.opdbID?.trim()?.ifBlank { null }
                val currentTitle = machine.displayTitle.trim()
                val currentVariant = machine.displayVariant?.trim()?.ifBlank { null }
                if (normalizedOPDBID == currentOPDBID &&
                    normalizedTitle == currentTitle &&
                    normalizedVariant == currentVariant) {
                    machine
                } else {
                    didChange = true
                    machine.copy(
                        opdbID = normalizedOPDBID,
                        displayTitle = normalizedTitle,
                        displayVariant = normalizedVariant,
                        updatedAtMs = System.currentTimeMillis(),
                    )
                }
            }
        }
        if (didChange) {
            state = state.copy(ownedMachines = migratedMachines)
            saveAndRecompute()
        }
    }

    fun upsertArea(id: String? = null, name: String, areaOrder: Int) {
        val normalizedName = name.trim().ifBlank { "Area" }
        val now = System.currentTimeMillis()
        val normalizedOrder = areaOrder.coerceAtLeast(0)
        val existing = state.areas.toMutableList()
        val explicitIndex = id?.let { explicitID ->
            existing.indexOfFirst { it.id == explicitID }
        } ?: -1
        when {
            explicitIndex >= 0 -> {
                existing[explicitIndex] = existing[explicitIndex].copy(
                    name = normalizedName,
                    areaOrder = normalizedOrder,
                    updatedAtMs = now,
                )
            }
            else -> {
                val sameNameIndex = existing.indexOfFirst { it.name.equals(normalizedName, ignoreCase = true) }
                if (sameNameIndex >= 0) {
                    existing[sameNameIndex] = existing[sameNameIndex].copy(
                        name = normalizedName,
                        areaOrder = normalizedOrder,
                        updatedAtMs = now,
                    )
                } else {
                    existing += GameRoomArea(
                        name = normalizedName,
                        areaOrder = normalizedOrder,
                        createdAtMs = now,
                        updatedAtMs = now,
                    )
                }
            }
        }
        state = state.copy(
            areas = existing.sortedWith(compareBy<GameRoomArea> { it.areaOrder }.thenBy { it.name.lowercase() }),
        )
        saveAndRecompute()
    }

    fun deleteArea(id: String) {
        val now = System.currentTimeMillis()
        val nextMachines = state.ownedMachines.map { machine ->
            if (machine.gameRoomAreaID != id) return@map machine
            machine.copy(gameRoomAreaID = null, updatedAtMs = now)
        }
        state = state.copy(
            areas = state.areas.filterNot { it.id == id },
            ownedMachines = nextMachines,
        )
        saveAndRecompute()
    }

    fun updateVenueName(rawName: String) {
        val trimmed = rawName.trim()
        state = state.copy(
            venueName = if (trimmed.isBlank()) GameRoomPersistedState.DEFAULT_VENUE_NAME else trimmed,
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
        val now = System.currentTimeMillis()
        val occurredAt = occurredAtMs ?: now
        val event = MachineEvent(
            ownedMachineID = machineID,
            type = type,
            category = category,
            occurredAtMs = occurredAt,
            playCountAtEvent = playCountAtEvent,
            summary = summary.trim().ifBlank { "Event" },
            notes = notes?.trim()?.ifBlank { null },
            partsUsed = partsUsed?.trim()?.ifBlank { null },
            consumablesUsed = consumablesUsed?.trim()?.ifBlank { null },
            pitchValue = pitchValue,
            pitchMeasurementPoint = pitchMeasurementPoint?.trim()?.ifBlank { null },
            linkedIssueID = linkedIssueID?.trim()?.ifBlank { null },
            createdAtMs = now,
            updatedAtMs = now,
        )
        state = state.copy(events = state.events + event)
        saveAndRecompute()
        return event.id
    }

    fun updateEvent(id: String, occurredAtMs: Long, summary: String, notes: String?) {
        val now = System.currentTimeMillis()
        state = state.copy(
            events = state.events.map { event ->
                if (event.id != id) return@map event
                event.copy(
                    occurredAtMs = occurredAtMs,
                    summary = summary.trim().ifBlank { "Event" },
                    notes = notes?.trim()?.ifBlank { null },
                    updatedAtMs = now,
                )
            },
        )
        saveAndRecompute()
    }

    fun deleteEvent(id: String) {
        state = state.copy(
            events = state.events.filterNot { it.id == id },
            attachments = state.attachments.filterNot { it.ownerType == MachineAttachmentOwnerType.event && it.ownerID == id },
        )
        saveAndRecompute()
    }

    fun attachmentsForMachine(machineID: String): List<MachineAttachment> {
        return state.attachments
            .filter { it.ownedMachineID == machineID }
            .sortedByDescending { it.createdAtMs }
    }

    fun attachmentsForEvent(eventID: String): List<MachineAttachment> {
        return state.attachments
            .filter { it.ownerType == MachineAttachmentOwnerType.event && it.ownerID == eventID }
            .sortedByDescending { it.createdAtMs }
    }

    fun attachmentsForIssue(issueID: String): List<MachineAttachment> {
        return state.attachments
            .filter { it.ownerType == MachineAttachmentOwnerType.issue && it.ownerID == issueID }
            .sortedByDescending { it.createdAtMs }
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
        val normalizedURI = uri.trim()
        if (normalizedURI.isBlank()) return ""
        val attachment = MachineAttachment(
            ownedMachineID = machineID,
            ownerType = ownerType,
            ownerID = ownerID,
            kind = kind,
            uri = normalizedURI,
            thumbnailURI = thumbnailURI?.trim()?.ifBlank { null },
            caption = caption?.trim()?.ifBlank { null },
        )
        state = state.copy(attachments = state.attachments + attachment)
        saveAndRecompute()
        return attachment.id
    }

    fun deleteAttachment(id: String) {
        state = state.copy(attachments = state.attachments.filterNot { it.id == id })
        saveAndRecompute()
    }

    fun updateAttachment(
        id: String,
        caption: String?,
        notes: String?,
    ) {
        val now = System.currentTimeMillis()
        val attachment = state.attachments.firstOrNull { it.id == id } ?: return
        state = state.copy(
            attachments = state.attachments.map { current ->
                if (current.id != id) current else current.copy(caption = normalizeOptionalString(caption))
            },
            events = if (attachment.ownerType == MachineAttachmentOwnerType.event) {
                state.events.map { event ->
                    if (event.id != attachment.ownerID) event else event.copy(
                        notes = normalizeOptionalString(notes),
                        updatedAtMs = now,
                    )
                }
            } else {
                state.events
            },
        )
        saveAndRecompute()
    }

    fun deleteAttachmentAndLinkedEvent(id: String) {
        val attachment = state.attachments.firstOrNull { it.id == id } ?: return
        var nextAttachments = state.attachments.filterNot { it.id == id }
        var nextEvents = state.events
        if (attachment.ownerType == MachineAttachmentOwnerType.event) {
            nextEvents = nextEvents.filterNot { it.id == attachment.ownerID }
            nextAttachments = nextAttachments.filterNot {
                it.ownerType == MachineAttachmentOwnerType.event && it.ownerID == attachment.ownerID
            }
        }
        state = state.copy(
            attachments = nextAttachments,
            events = nextEvents,
        )
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
        val now = System.currentTimeMillis()
        val openedAt = openedAtMs ?: now
        val issue = MachineIssue(
            ownedMachineID = machineID,
            status = MachineIssueStatus.open,
            severity = severity,
            subsystem = subsystem,
            symptom = symptom.trim().ifBlank { "Issue" },
            diagnosis = diagnosis?.trim()?.ifBlank { null },
            openedAtMs = openedAt,
            createdAtMs = now,
            updatedAtMs = now,
        )
        state = state.copy(issues = state.issues + issue)
        addEvent(
            machineID = machineID,
            type = MachineEventType.issueOpened,
            category = MachineEventCategory.issue,
            summary = "Issue opened: ${issue.symptom}",
            occurredAtMs = openedAt,
            notes = diagnosis,
            linkedIssueID = issue.id,
        )
        saveAndRecompute()
        return issue.id
    }

    fun resolveIssue(issueID: String, resolution: String?, resolvedAtMs: Long? = null) {
        val issue = state.issues.firstOrNull { it.id == issueID } ?: return
        val now = System.currentTimeMillis()
        val resolvedAt = resolvedAtMs ?: now
        state = state.copy(
            issues = state.issues.map { current ->
                if (current.id != issueID) return@map current
                current.copy(
                    status = MachineIssueStatus.resolved,
                    resolvedAtMs = resolvedAt,
                    resolution = resolution?.trim()?.ifBlank { null },
                    updatedAtMs = now,
                )
            },
        )
        addEvent(
            machineID = issue.ownedMachineID,
            type = MachineEventType.issueResolved,
            category = MachineEventCategory.issue,
            summary = "Issue resolved: ${issue.symptom}",
            occurredAtMs = resolvedAt,
            notes = resolution,
            linkedIssueID = issueID,
        )
        saveAndRecompute()
    }

    private fun compareMachines(lhs: OwnedMachine, rhs: OwnedMachine): Int {
        val lhsArea = area(lhs.gameRoomAreaID)
        val rhsArea = area(rhs.gameRoomAreaID)
        val lhsAreaOrder = lhsArea?.areaOrder ?: Int.MAX_VALUE
        val rhsAreaOrder = rhsArea?.areaOrder ?: Int.MAX_VALUE
        if (lhsAreaOrder != rhsAreaOrder) return lhsAreaOrder.compareTo(rhsAreaOrder)

        val lhsAreaName = lhsArea?.name?.lowercase().orEmpty()
        val rhsAreaName = rhsArea?.name?.lowercase().orEmpty()
        if (lhsAreaName != rhsAreaName) return lhsAreaName.compareTo(rhsAreaName)

        val lhsGroup = lhs.groupNumber ?: Int.MAX_VALUE
        val rhsGroup = rhs.groupNumber ?: Int.MAX_VALUE
        if (lhsGroup != rhsGroup) return lhsGroup.compareTo(rhsGroup)

        val lhsPosition = lhs.position ?: Int.MAX_VALUE
        val rhsPosition = rhs.position ?: Int.MAX_VALUE
        if (lhsPosition != rhsPosition) return lhsPosition.compareTo(rhsPosition)

        val lhsTitle = lhs.displayTitle.lowercase()
        val rhsTitle = rhs.displayTitle.lowercase()
        if (lhsTitle != rhsTitle) return lhsTitle.compareTo(rhsTitle)

        return lhs.id.compareTo(rhs.id)
    }

    private fun recomputeSnapshots() {
        val now = System.currentTimeMillis()
        snapshots = state.ownedMachines.associate { machine ->
            val machineEvents = state.events
                .filter { it.ownedMachineID == machine.id }
                .sortedByDescending { it.occurredAtMs }
            val machineIssues = state.issues.filter { it.ownedMachineID == machine.id }
            val openIssueCount = machineIssues.count { it.status != MachineIssueStatus.resolved }
            val currentPlayCount = currentPlayCount(machineEvents)
            val dueTaskCount = dueTaskCount(machine, machineEvents, currentPlayCount, now)
            val attention = when {
                machine.status == OwnedMachineStatus.archived ||
                    machine.status == OwnedMachineStatus.sold ||
                    machine.status == OwnedMachineStatus.traded -> GameRoomAttentionState.gray
                machineIssues.any {
                    it.status != MachineIssueStatus.resolved &&
                        (it.severity == MachineIssueSeverity.high || it.severity == MachineIssueSeverity.critical)
                } -> GameRoomAttentionState.red
                openIssueCount > 0 || dueTaskCount > 0 -> GameRoomAttentionState.yellow
                else -> GameRoomAttentionState.green
            }

            fun latestEvent(type: MachineEventType): MachineEvent? = machineEvents.firstOrNull { it.type == type }
            val latestPitch = latestEvent(MachineEventType.pitchChecked)

            machine.id to OwnedMachineSnapshot(
                ownedMachineID = machine.id,
                currentPlayCount = currentPlayCount,
                lastGlassCleanedAtMs = latestEvent(MachineEventType.glassCleaned)?.occurredAtMs,
                lastPlayfieldCleanedAtMs = latestEvent(MachineEventType.playfieldCleaned)?.occurredAtMs,
                lastPlayfieldCleanerUsed = latestEvent(MachineEventType.playfieldCleaned)?.consumablesUsed,
                lastBallsServicedAtMs = latestEvent(MachineEventType.ballsCleaned)?.occurredAtMs,
                lastBallsReplacedAtMs = latestEvent(MachineEventType.ballsReplaced)?.occurredAtMs,
                currentBallSetNotes = latestEvent(MachineEventType.ballsReplaced)?.notes,
                lastPitchCheckedAtMs = latestPitch?.occurredAtMs,
                currentPitchValue = latestPitch?.pitchValue,
                currentPitchMeasurementPoint = latestPitch?.pitchMeasurementPoint,
                lastLeveledAtMs = latestEvent(MachineEventType.machineLeveled)?.occurredAtMs,
                lastRubberServiceAtMs = latestEvent(MachineEventType.rubbersReplaced)?.occurredAtMs,
                lastFlipperServiceAtMs = latestEvent(MachineEventType.flipperServiced)?.occurredAtMs,
                lastGeneralInspectionAtMs = latestEvent(MachineEventType.generalInspection)?.occurredAtMs,
                lastServiceAtMs = machineEvents.firstOrNull { it.category == MachineEventCategory.service }?.occurredAtMs,
                openIssueCount = openIssueCount,
                dueTaskCount = dueTaskCount,
                attentionState = attention,
                updatedAtMs = now,
            )
        }
    }

    private fun dueTaskCount(
        machine: OwnedMachine,
        events: List<MachineEvent>,
        currentPlayCount: Int,
        nowMs: Long,
    ): Int {
        if (machine.status != OwnedMachineStatus.active && machine.status != OwnedMachineStatus.loaned) return 0

        val configs = effectiveReminderConfigs(machine.id)
        if (configs.isEmpty()) return 0
        val lastTaskPlayCounts = lastTaskPlayCounts(events)
        var count = 0

        configs.filter { it.enabled }.forEach { config ->
            when (config.mode) {
                MachineReminderMode.manualOnly -> Unit
                MachineReminderMode.playBased -> {
                    val intervalPlays = config.intervalPlays ?: 0
                    if (intervalPlays <= 0) return@forEach
                    val baseline = lastTaskPlayCounts[config.taskType] ?: 0
                    if ((currentPlayCount - baseline) >= intervalPlays) count += 1
                }
                MachineReminderMode.dateBased -> {
                    val intervalDays = config.intervalDays ?: 0
                    if (intervalDays <= 0) return@forEach
                    val lastAt = latestEventDate(config.taskType, events)
                    if (lastAt == null) {
                        count += 1
                    } else {
                        val dueAt = lastAt + intervalDays * 24L * 60L * 60L * 1000L
                        if (nowMs >= dueAt) count += 1
                    }
                }
            }
        }
        return count
    }

    private fun currentPlayCount(eventsDesc: List<MachineEvent>): Int {
        val asc = eventsDesc.sortedWith(compareBy<MachineEvent> { it.occurredAtMs }.thenBy { it.createdAtMs }.thenBy { it.id })
        var runningTotal = 0
        asc.forEach { event ->
            playLogTotal(event)?.let { runningTotal = it }
        }
        return runningTotal
    }

    private fun lastTaskPlayCounts(eventsDesc: List<MachineEvent>): Map<MachineReminderTaskType, Int> {
        val asc = eventsDesc.sortedWith(compareBy<MachineEvent> { it.occurredAtMs }.thenBy { it.createdAtMs }.thenBy { it.id })
        var runningPlayCount = 0
        val lastByTask = mutableMapOf<MachineReminderTaskType, Int>()
        asc.forEach { event ->
            playLogTotal(event)?.let { runningPlayCount = it }
            MachineReminderTaskType.entries.forEach { taskType ->
                if (eventTypes(taskType).contains(event.type)) {
                    lastByTask[taskType] = runningPlayCount
                }
            }
        }
        return lastByTask
    }

    private fun latestEventDate(taskType: MachineReminderTaskType, events: List<MachineEvent>): Long? {
        val candidateTypes = eventTypes(taskType)
        return events.firstOrNull { candidateTypes.contains(it.type) }?.occurredAtMs
    }

    private fun eventTypes(taskType: MachineReminderTaskType): List<MachineEventType> {
        return when (taskType) {
            MachineReminderTaskType.glassCleaned -> listOf(MachineEventType.glassCleaned)
            MachineReminderTaskType.playfieldCleaned -> listOf(MachineEventType.playfieldCleaned)
            MachineReminderTaskType.ballsReplaced -> listOf(MachineEventType.ballsReplaced)
            MachineReminderTaskType.pitchChecked -> listOf(MachineEventType.pitchChecked)
            MachineReminderTaskType.machineLeveled -> listOf(MachineEventType.machineLeveled)
            MachineReminderTaskType.rubbersReplaced -> listOf(MachineEventType.rubbersReplaced)
            MachineReminderTaskType.flipperServiced -> listOf(MachineEventType.flipperServiced)
            MachineReminderTaskType.generalInspection -> listOf(MachineEventType.generalInspection)
        }
    }

    private fun isPlayCountEvent(event: MachineEvent): Boolean {
        return event.type == MachineEventType.custom && event.category == MachineEventCategory.custom
    }

    private fun playLogTotal(event: MachineEvent): Int? {
        if (!isPlayCountEvent(event)) return null
        val value = event.playCountAtEvent ?: return null
        return value.takeIf { it >= 0 }
    }

    private fun effectiveReminderConfigs(machineID: String): List<MachineReminderConfig> {
        val existing = state.reminderConfigs
            .filter { it.ownedMachineID == machineID }
            .sortedBy { it.taskType.name }
        if (existing.isNotEmpty()) return existing
        return defaultReminderConfigs(machineID)
    }

    private fun defaultReminderConfigs(machineID: String): List<MachineReminderConfig> {
        val now = System.currentTimeMillis()
        return listOf(
            MachineReminderConfig(
                ownedMachineID = machineID,
                taskType = MachineReminderTaskType.glassCleaned,
                mode = MachineReminderMode.dateBased,
                intervalDays = 30,
                createdAtMs = now,
                updatedAtMs = now,
            ),
            MachineReminderConfig(
                ownedMachineID = machineID,
                taskType = MachineReminderTaskType.playfieldCleaned,
                mode = MachineReminderMode.dateBased,
                intervalDays = 90,
                createdAtMs = now,
                updatedAtMs = now,
            ),
            MachineReminderConfig(
                ownedMachineID = machineID,
                taskType = MachineReminderTaskType.ballsReplaced,
                mode = MachineReminderMode.playBased,
                intervalPlays = 5000,
                createdAtMs = now,
                updatedAtMs = now,
            ),
            MachineReminderConfig(
                ownedMachineID = machineID,
                taskType = MachineReminderTaskType.generalInspection,
                mode = MachineReminderMode.dateBased,
                intervalDays = 45,
                createdAtMs = now,
                updatedAtMs = now,
            ),
        )
    }

    private fun saveAndRecompute() {
        recomputeSnapshots()
        saveState()
    }

    private fun normalizeVariantKey(value: String?): String {
        return value?.trim()?.lowercase().orEmpty()
    }

    private fun normalizeOptionalString(value: String?): String? {
        return value?.trim()?.ifBlank { null }
    }
}
