import Foundation

func gameRoomSortedMachineEventsForSnapshots(
    allEvents: [MachineEvent],
    machineID: UUID
) -> [MachineEvent] {
    allEvents
        .filter { $0.ownedMachineID == machineID }
        .sorted { $0.occurredAt > $1.occurredAt }
}

func gameRoomMachineIssues(
    allIssues: [MachineIssue],
    machineID: UUID
) -> [MachineIssue] {
    allIssues.filter { $0.ownedMachineID == machineID }
}

func gameRoomOpenIssueCount(_ machineIssues: [MachineIssue]) -> Int {
    machineIssues.filter { $0.status != .resolved }.count
}

func gameRoomLatestEventLookup(
    events: [MachineEvent]
) -> (MachineEventType) -> MachineEvent? {
    { type in events.first(where: { $0.type == type }) }
}

func gameRoomDueTaskCount(
    for machine: OwnedMachine,
    events: [MachineEvent],
    reminderConfigs: [MachineReminderConfig],
    currentPlayCount: Int,
    now: Date
) -> Int {
    guard machine.status.countsAsActiveInventory else { return 0 }

    let configs = gameRoomEffectiveReminderConfigs(
        reminderConfigs: reminderConfigs,
        machineID: machine.id
    )
    guard !configs.isEmpty else { return 0 }
    let lastTaskPlayCounts = gameRoomLastTaskPlayCounts(events: events)

    var count = 0
    for config in configs where config.enabled {
        switch config.mode {
        case .manualOnly:
            continue
        case .playBased:
            guard let intervalPlays = config.intervalPlays, intervalPlays > 0 else { continue }
            let baseline = lastTaskPlayCounts[config.taskType] ?? 0
            if (currentPlayCount - baseline) >= intervalPlays {
                count += 1
            }
        case .dateBased:
            guard let intervalDays = config.intervalDays, intervalDays > 0 else { continue }
            let lastPerformedAt = gameRoomLatestEventDate(for: config.taskType, events: events)
            if let lastPerformedAt {
                if let dueAt = Calendar.current.date(byAdding: .day, value: intervalDays, to: lastPerformedAt),
                   now >= dueAt {
                    count += 1
                }
            } else {
                count += 1
            }
        }
    }
    return count
}

func gameRoomCurrentPlayCount(for eventsDesc: [MachineEvent]) -> Int {
    let eventsAsc = eventsDesc.sorted {
        if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
        if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
        return $0.id.uuidString < $1.id.uuidString
    }
    var runningTotal = 0
    for event in eventsAsc {
        guard let total = event.loggedPlayCountTotal else { continue }
        runningTotal = total
    }
    return runningTotal
}

func gameRoomLastTaskPlayCounts(events eventsDesc: [MachineEvent]) -> [MachineReminderTaskType: Int] {
    let eventsAsc = eventsDesc.sorted {
        if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
        if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
        return $0.id.uuidString < $1.id.uuidString
    }
    var runningPlayCount = 0
    var lastByTask: [MachineReminderTaskType: Int] = [:]

    for event in eventsAsc {
        if let total = event.loggedPlayCountTotal {
            runningPlayCount = total
        }
        for taskType in MachineReminderTaskType.allCases where taskType.matchingEventTypes.contains(event.type) {
            lastByTask[taskType] = runningPlayCount
        }
    }
    return lastByTask
}

func gameRoomLatestEventDate(for taskType: MachineReminderTaskType, events: [MachineEvent]) -> Date? {
    events.first(where: { taskType.matchingEventTypes.contains($0.type) })?.occurredAt
}

func gameRoomEffectiveReminderConfigs(
    reminderConfigs: [MachineReminderConfig],
    machineID: UUID
) -> [MachineReminderConfig] {
    let machineConfigs = reminderConfigs.filter { $0.ownedMachineID == machineID }
    guard !machineConfigs.isEmpty else {
        return MachineReminderConfig.defaultConfigs(for: machineID)
            .sorted { $0.taskType.rawValue < $1.taskType.rawValue }
    }

    var mergedByTask = Dictionary(
        uniqueKeysWithValues: MachineReminderConfig.defaultConfigs(for: machineID).map { ($0.taskType, $0) }
    )
    for config in machineConfigs {
        mergedByTask[config.taskType] = config
    }
    return mergedByTask.values.sorted { $0.taskType.rawValue < $1.taskType.rawValue }
}
