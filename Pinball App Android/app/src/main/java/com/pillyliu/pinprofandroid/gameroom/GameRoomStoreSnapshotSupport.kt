package com.pillyliu.pinprofandroid.gameroom

internal fun compareGameRoomMachines(
    lhs: OwnedMachine,
    rhs: OwnedMachine,
    areasById: Map<String, GameRoomArea>,
): Int {
    val lhsArea = lhs.gameRoomAreaID?.let(areasById::get)
    val rhsArea = rhs.gameRoomAreaID?.let(areasById::get)
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

internal fun computeOwnedMachineSnapshots(
    state: GameRoomPersistedState,
    nowMs: Long,
): Map<String, OwnedMachineSnapshot> {
    return state.ownedMachines.associate { machine ->
        val machineEvents = state.events
            .filter { it.ownedMachineID == machine.id }
            .sortedByDescending { it.occurredAtMs }
        val machineIssues = state.issues.filter { it.ownedMachineID == machine.id }
        val openIssueCount = machineIssues.count { it.status != MachineIssueStatus.resolved }
        val currentPlayCount = currentPlayCount(machineEvents)
        val dueTaskCount = dueTaskCount(
            machine = machine,
            events = machineEvents,
            currentPlayCount = currentPlayCount,
            nowMs = nowMs,
            reminderConfigs = state.reminderConfigs,
        )
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
            updatedAtMs = nowMs,
        )
    }
}

private fun dueTaskCount(
    machine: OwnedMachine,
    events: List<MachineEvent>,
    currentPlayCount: Int,
    nowMs: Long,
    reminderConfigs: List<MachineReminderConfig>,
): Int {
    if (!machine.status.countsAsActiveInventory) return 0

    val configs = effectiveReminderConfigs(machine.id, reminderConfigs)
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
        event.loggedPlayCountTotal?.let { runningTotal = it }
    }
    return runningTotal
}

private fun lastTaskPlayCounts(eventsDesc: List<MachineEvent>): Map<MachineReminderTaskType, Int> {
    val asc = eventsDesc.sortedWith(compareBy<MachineEvent> { it.occurredAtMs }.thenBy { it.createdAtMs }.thenBy { it.id })
    var runningPlayCount = 0
    val lastByTask = mutableMapOf<MachineReminderTaskType, Int>()
    asc.forEach { event ->
        event.loggedPlayCountTotal?.let { runningPlayCount = it }
        MachineReminderTaskType.entries.forEach { taskType ->
            if (taskType.matchingEventTypes.contains(event.type)) {
                lastByTask[taskType] = runningPlayCount
            }
        }
    }
    return lastByTask
}

private fun latestEventDate(taskType: MachineReminderTaskType, events: List<MachineEvent>): Long? {
    return events.firstOrNull { taskType.matchingEventTypes.contains(it.type) }?.occurredAtMs
}

private fun effectiveReminderConfigs(
    machineID: String,
    reminderConfigs: List<MachineReminderConfig>,
): List<MachineReminderConfig> {
    val existing = reminderConfigs.filter { it.ownedMachineID == machineID }
    if (existing.isEmpty()) {
        return MachineReminderConfig.defaultConfigs(machineID).sortedBy { it.taskType.name }
    }

    val mergedByTask = MachineReminderConfig.defaultConfigs(machineID)
        .associateBy { it.taskType }
        .toMutableMap()
    existing.forEach { config ->
        mergedByTask[config.taskType] = config
    }
    return mergedByTask.values.sortedBy { it.taskType.name }
}
