import Foundation

extension GameRoomStore {
    var activeMachines: [OwnedMachine] {
        state.ownedMachines
            .filter { $0.status.countsAsActiveInventory }
            .sorted(by: sortMachines)
    }

    var archivedMachines: [OwnedMachine] {
        state.ownedMachines
            .filter { !$0.status.countsAsActiveInventory }
            .sorted(by: sortMachines)
    }

    func snapshot(for machineID: UUID) -> OwnedMachineSnapshot {
        snapshots[machineID] ?? OwnedMachineSnapshot(
            ownedMachineID: machineID,
            currentPlayCount: 0,
            lastGlassCleanedAt: nil,
            lastPlayfieldCleanedAt: nil,
            lastPlayfieldCleanerUsed: nil,
            lastBallsServicedAt: nil,
            lastBallsReplacedAt: nil,
            currentBallSetNotes: nil,
            lastPitchCheckedAt: nil,
            currentPitchValue: nil,
            currentPitchMeasurementPoint: nil,
            lastLeveledAt: nil,
            lastRubberServiceAt: nil,
            lastFlipperServiceAt: nil,
            lastGeneralInspectionAt: nil,
            lastServiceAt: nil,
            openIssueCount: 0,
            dueTaskCount: 0,
            attentionState: .gray,
            updatedAt: Date()
        )
    }

    func recomputeSnapshots() {
        var nextSnapshots: [UUID: OwnedMachineSnapshot] = [:]
        let now = Date()

        for machine in state.ownedMachines {
            let machineEvents = gameRoomSortedMachineEventsForSnapshots(
                allEvents: state.events,
                machineID: machine.id
            )
            let machineIssues = gameRoomMachineIssues(
                allIssues: state.issues,
                machineID: machine.id
            )
            let openIssueCount = gameRoomOpenIssueCount(machineIssues)
            let currentPlayCount = gameRoomCurrentPlayCount(for: machineEvents)
            let dueTaskCount = gameRoomDueTaskCount(
                for: machine,
                events: machineEvents,
                reminderConfigs: state.reminderConfigs,
                currentPlayCount: currentPlayCount,
                now: now
            )
            let attentionState: GameRoomAttentionState = {
                if machine.status == .archived || machine.status == .sold || machine.status == .traded {
                    return .gray
                }
                if machineIssues.contains(where: { $0.status != .resolved && ($0.severity == .high || $0.severity == .critical) }) {
                    return .red
                }
                if openIssueCount > 0 || dueTaskCount > 0 {
                    return .yellow
                }
                return .green
            }()

            let latestEvent = gameRoomLatestEventLookup(events: machineEvents)

            let latestPitchCheck = latestEvent(.pitchChecked)

            nextSnapshots[machine.id] = OwnedMachineSnapshot(
                ownedMachineID: machine.id,
                currentPlayCount: currentPlayCount,
                lastGlassCleanedAt: latestEvent(.glassCleaned)?.occurredAt,
                lastPlayfieldCleanedAt: latestEvent(.playfieldCleaned)?.occurredAt,
                lastPlayfieldCleanerUsed: latestEvent(.playfieldCleaned)?.consumablesUsed,
                lastBallsServicedAt: latestEvent(.ballsCleaned)?.occurredAt,
                lastBallsReplacedAt: latestEvent(.ballsReplaced)?.occurredAt,
                currentBallSetNotes: latestEvent(.ballsReplaced)?.notes,
                lastPitchCheckedAt: latestPitchCheck?.occurredAt,
                currentPitchValue: latestPitchCheck?.pitchValue,
                currentPitchMeasurementPoint: latestPitchCheck?.pitchMeasurementPoint,
                lastLeveledAt: latestEvent(.machineLeveled)?.occurredAt,
                lastRubberServiceAt: latestEvent(.rubbersReplaced)?.occurredAt,
                lastFlipperServiceAt: latestEvent(.flipperServiced)?.occurredAt,
                lastGeneralInspectionAt: latestEvent(.generalInspection)?.occurredAt,
                lastServiceAt: machineEvents.first(where: { $0.category == .service })?.occurredAt,
                openIssueCount: openIssueCount,
                dueTaskCount: dueTaskCount,
                attentionState: attentionState,
                updatedAt: now
            )
        }

        snapshots = nextSnapshots
    }

    func sortMachines(lhs: OwnedMachine, rhs: OwnedMachine) -> Bool {
        let lhsArea = area(for: lhs.gameRoomAreaID)
        let rhsArea = area(for: rhs.gameRoomAreaID)

        let lhsAreaOrder = lhsArea?.areaOrder ?? Int.max
        let rhsAreaOrder = rhsArea?.areaOrder ?? Int.max
        if lhsAreaOrder != rhsAreaOrder { return lhsAreaOrder < rhsAreaOrder }

        let lhsAreaName = lhsArea?.name.lowercased() ?? ""
        let rhsAreaName = rhsArea?.name.lowercased() ?? ""
        if lhsAreaName != rhsAreaName { return lhsAreaName < rhsAreaName }

        let lhsGroup = lhs.groupNumber ?? Int.max
        let rhsGroup = rhs.groupNumber ?? Int.max
        if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }

        let lhsPosition = lhs.position ?? Int.max
        let rhsPosition = rhs.position ?? Int.max
        if lhsPosition != rhsPosition { return lhsPosition < rhsPosition }

        let lhsTitle = lhs.displayTitle.lowercased()
        let rhsTitle = rhs.displayTitle.lowercased()
        if lhsTitle != rhsTitle { return lhsTitle < rhsTitle }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}
