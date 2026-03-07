package com.pillyliu.pinprofandroid.gameroom

import java.util.UUID

internal enum class OwnedMachineStatus {
    active,
    loaned,
    archived,
    sold,
    traded,
}

internal enum class GameRoomAttentionState {
    red,
    yellow,
    green,
    gray,
}

internal enum class MachineEventCategory {
    service,
    ownership,
    mod,
    media,
    inspection,
    issue,
    custom,
}

internal enum class MachineEventType {
    glassCleaned,
    playfieldCleaned,
    ballsCleaned,
    ballsReplaced,
    pitchChecked,
    machineLeveled,
    rubbersReplaced,
    flipperServiced,
    generalInspection,
    partReplaced,
    modInstalled,
    modRemoved,
    purchased,
    moved,
    loanedOut,
    returned,
    listedForSale,
    sold,
    traded,
    reacquired,
    issueOpened,
    issueResolved,
    photoAdded,
    videoAdded,
    custom,
}

internal enum class MachineIssueStatus {
    open,
    monitoring,
    resolved,
    deferred,
}

internal enum class MachineIssueSeverity {
    low,
    medium,
    high,
    critical,
}

internal enum class MachineIssueSubsystem {
    flipper,
    slingshot,
    popBumper,
    trough,
    shooterLane,
    switchMatrix,
    opto,
    coil,
    magnet,
    diverter,
    ramp,
    toyMech,
    lighting,
    sound,
    display,
    cabinet,
    software,
    network,
    other,
}

internal enum class MachineAttachmentOwnerType {
    event,
    issue,
}

internal enum class MachineAttachmentKind {
    photo,
    video,
}

internal enum class MachineReminderTaskType {
    glassCleaned,
    playfieldCleaned,
    ballsReplaced,
    pitchChecked,
    machineLeveled,
    rubbersReplaced,
    flipperServiced,
    generalInspection,
}

internal enum class MachineReminderMode {
    dateBased,
    playBased,
    manualOnly,
}

internal enum class MachineImportSource {
    pinside,
}

internal enum class MachineImportMatchConfidence {
    high,
    medium,
    low,
    manual,
}

internal data class GameRoomArea(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val areaOrder: Int,
    val createdAtMs: Long = System.currentTimeMillis(),
    val updatedAtMs: Long = createdAtMs,
)

internal data class OwnedMachine(
    val id: String = UUID.randomUUID().toString(),
    val catalogGameID: String,
    val canonicalPracticeIdentity: String,
    val displayTitle: String,
    val displayVariant: String? = null,
    val importedSourceTitle: String? = null,
    val manufacturer: String? = null,
    val year: Int? = null,
    val status: OwnedMachineStatus = OwnedMachineStatus.active,
    val gameRoomAreaID: String? = null,
    val groupNumber: Int? = null,
    val position: Int? = null,
    val purchaseDateMs: Long? = null,
    val purchaseDateRawText: String? = null,
    val purchaseSource: String? = null,
    val purchasePrice: Double? = null,
    val serialNumber: String? = null,
    val manufactureDateMs: Long? = null,
    val soldOrTradedDateMs: Long? = null,
    val ownershipNotes: String? = null,
    val createdAtMs: Long = System.currentTimeMillis(),
    val updatedAtMs: Long = createdAtMs,
)

internal data class OwnedMachineSnapshot(
    val ownedMachineID: String,
    val currentPlayCount: Int,
    val lastGlassCleanedAtMs: Long?,
    val lastPlayfieldCleanedAtMs: Long?,
    val lastPlayfieldCleanerUsed: String?,
    val lastBallsServicedAtMs: Long?,
    val lastBallsReplacedAtMs: Long?,
    val currentBallSetNotes: String?,
    val lastPitchCheckedAtMs: Long?,
    val currentPitchValue: Double?,
    val currentPitchMeasurementPoint: String?,
    val lastLeveledAtMs: Long?,
    val lastRubberServiceAtMs: Long?,
    val lastFlipperServiceAtMs: Long?,
    val lastGeneralInspectionAtMs: Long?,
    val lastServiceAtMs: Long?,
    val openIssueCount: Int,
    val dueTaskCount: Int,
    val attentionState: GameRoomAttentionState,
    val updatedAtMs: Long = System.currentTimeMillis(),
)

internal data class MachineEvent(
    val id: String = UUID.randomUUID().toString(),
    val ownedMachineID: String,
    val type: MachineEventType,
    val category: MachineEventCategory,
    val occurredAtMs: Long = System.currentTimeMillis(),
    val playCountAtEvent: Int? = null,
    val summary: String,
    val notes: String? = null,
    val performedBy: String? = null,
    val cost: Double? = null,
    val partsUsed: String? = null,
    val consumablesUsed: String? = null,
    val pitchValue: Double? = null,
    val pitchMeasurementPoint: String? = null,
    val linkedIssueID: String? = null,
    val createdAtMs: Long = System.currentTimeMillis(),
    val updatedAtMs: Long = createdAtMs,
)

internal data class MachineIssue(
    val id: String = UUID.randomUUID().toString(),
    val ownedMachineID: String,
    val status: MachineIssueStatus = MachineIssueStatus.open,
    val severity: MachineIssueSeverity = MachineIssueSeverity.medium,
    val subsystem: MachineIssueSubsystem = MachineIssueSubsystem.other,
    val symptom: String,
    val reproSteps: String? = null,
    val diagnosis: String? = null,
    val resolution: String? = null,
    val openedAtMs: Long = System.currentTimeMillis(),
    val resolvedAtMs: Long? = null,
    val createdAtMs: Long = System.currentTimeMillis(),
    val updatedAtMs: Long = createdAtMs,
)

internal data class MachineAttachment(
    val id: String = UUID.randomUUID().toString(),
    val ownedMachineID: String,
    val ownerType: MachineAttachmentOwnerType,
    val ownerID: String,
    val kind: MachineAttachmentKind,
    val uri: String,
    val thumbnailURI: String? = null,
    val caption: String? = null,
    val createdAtMs: Long = System.currentTimeMillis(),
)

internal data class MachineReminderConfig(
    val id: String = UUID.randomUUID().toString(),
    val ownedMachineID: String,
    val taskType: MachineReminderTaskType,
    val mode: MachineReminderMode,
    val intervalDays: Int? = null,
    val intervalPlays: Int? = null,
    val enabled: Boolean = true,
    val createdAtMs: Long = System.currentTimeMillis(),
    val updatedAtMs: Long = createdAtMs,
)

internal data class MachineImportRecord(
    val id: String = UUID.randomUUID().toString(),
    val source: MachineImportSource,
    val sourceUserOrURL: String,
    val sourceItemKey: String? = null,
    val rawTitle: String,
    val rawVariant: String? = null,
    val rawPurchaseDateText: String? = null,
    val normalizedPurchaseDateMs: Long? = null,
    val matchedCatalogGameID: String? = null,
    val matchConfidence: MachineImportMatchConfidence,
    val createdOwnedMachineID: String? = null,
    val importedAtMs: Long = System.currentTimeMillis(),
    val fingerprint: String? = null,
)

internal data class GameRoomPersistedState(
    val schemaVersion: Int = CURRENT_SCHEMA_VERSION,
    val venueName: String = DEFAULT_VENUE_NAME,
    val areas: List<GameRoomArea> = emptyList(),
    val ownedMachines: List<OwnedMachine> = emptyList(),
    val events: List<MachineEvent> = emptyList(),
    val issues: List<MachineIssue> = emptyList(),
    val attachments: List<MachineAttachment> = emptyList(),
    val reminderConfigs: List<MachineReminderConfig> = emptyList(),
    val importRecords: List<MachineImportRecord> = emptyList(),
) {
    companion object {
        const val CURRENT_SCHEMA_VERSION: Int = 1
        const val DEFAULT_VENUE_NAME: String = "GameRoom"
        val empty = GameRoomPersistedState()
    }
}

