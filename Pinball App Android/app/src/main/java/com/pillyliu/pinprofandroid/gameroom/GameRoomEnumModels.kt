package com.pillyliu.pinprofandroid.gameroom

internal enum class OwnedMachineStatus {
    active,
    loaned,
    archived,
    sold,
    traded,
    ;

    val countsAsActiveInventory: Boolean
        get() = this == active || this == loaned
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
    ;

    val matchingEventTypes: Set<MachineEventType>
        get() = when (this) {
            glassCleaned -> setOf(MachineEventType.glassCleaned)
            playfieldCleaned -> setOf(MachineEventType.playfieldCleaned)
            ballsReplaced -> setOf(MachineEventType.ballsReplaced)
            pitchChecked -> setOf(MachineEventType.pitchChecked)
            machineLeveled -> setOf(MachineEventType.machineLeveled)
            rubbersReplaced -> setOf(MachineEventType.rubbersReplaced)
            flipperServiced -> setOf(MachineEventType.flipperServiced)
            generalInspection -> setOf(MachineEventType.generalInspection)
        }
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
