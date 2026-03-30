package com.pillyliu.pinprofandroid.gameroom

import java.util.UUID

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
) {
    val contributesToPlayCount: Boolean
        get() = type == MachineEventType.custom && category == MachineEventCategory.custom

    val loggedPlayCountTotal: Int?
        get() {
            if (!contributesToPlayCount) return null
            val value = playCountAtEvent ?: return null
            return value.takeIf { it >= 0 }
        }
}

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
) {
    companion object {
        fun defaultConfigs(
            machineID: String,
            nowMs: Long = System.currentTimeMillis(),
        ): List<MachineReminderConfig> {
            return listOf(
                MachineReminderConfig(
                    ownedMachineID = machineID,
                    taskType = MachineReminderTaskType.glassCleaned,
                    mode = MachineReminderMode.dateBased,
                    intervalDays = 30,
                    createdAtMs = nowMs,
                    updatedAtMs = nowMs,
                ),
                MachineReminderConfig(
                    ownedMachineID = machineID,
                    taskType = MachineReminderTaskType.playfieldCleaned,
                    mode = MachineReminderMode.dateBased,
                    intervalDays = 90,
                    createdAtMs = nowMs,
                    updatedAtMs = nowMs,
                ),
                MachineReminderConfig(
                    ownedMachineID = machineID,
                    taskType = MachineReminderTaskType.ballsReplaced,
                    mode = MachineReminderMode.playBased,
                    intervalPlays = 5000,
                    createdAtMs = nowMs,
                    updatedAtMs = nowMs,
                ),
                MachineReminderConfig(
                    ownedMachineID = machineID,
                    taskType = MachineReminderTaskType.generalInspection,
                    mode = MachineReminderMode.dateBased,
                    intervalDays = 45,
                    createdAtMs = nowMs,
                    updatedAtMs = nowMs,
                ),
            )
        }
    }
}

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
        const val CURRENT_SCHEMA_VERSION: Int = 2
        const val DEFAULT_VENUE_NAME: String = "GameRoom"
        val empty = GameRoomPersistedState()
    }
}
