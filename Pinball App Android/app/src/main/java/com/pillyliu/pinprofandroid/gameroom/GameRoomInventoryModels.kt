package com.pillyliu.pinprofandroid.gameroom

import java.util.UUID

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
    val opdbID: String? = null,
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
