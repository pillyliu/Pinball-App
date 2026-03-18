import Foundation
import Combine
import SwiftUI

@MainActor
final class GameRoomStore: ObservableObject {
    @Published var state = GameRoomPersistedState.empty
    @Published var snapshots: [UUID: OwnedMachineSnapshot] = [:]
    @Published var lastErrorMessage: String?

    static let storageKey = "gameroom-state-json"
    static let legacyStorageKey = "gameroom-state-v1"

    private(set) var didLoad = false

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        loadState()
    }

    func loadState() {
        let defaults = UserDefaults.standard
        guard let loaded = GameRoomStateCodec.loadFromDefaults(
            defaults,
            storageKey: Self.storageKey,
            legacyStorageKey: Self.legacyStorageKey
        ) else {
            state = .empty
            recomputeSnapshots()
            return
        }

        state = loaded
        recomputeSnapshots()

        if defaults.data(forKey: Self.storageKey) == nil || defaults.data(forKey: Self.legacyStorageKey) != nil {
            saveState()
        }
    }

    func saveState() {
        do {
            state.schemaVersion = GameRoomPersistedState.currentSchemaVersion
            let data = try GameRoomStateCodec.canonicalEncoder().encode(state)
            let defaults = UserDefaults.standard
            defaults.set(data, forKey: Self.storageKey)
            defaults.removeObject(forKey: Self.legacyStorageKey)
        } catch {
            lastErrorMessage = "Failed to save GameRoom data: \(error.localizedDescription)"
        }
    }

    var activeMachines: [OwnedMachine] {
        state.ownedMachines
            .filter { $0.status == .active || $0.status == .loaned }
            .sorted(by: sortMachines)
    }

    var archivedMachines: [OwnedMachine] {
        state.ownedMachines
            .filter { !($0.status == .active || $0.status == .loaned) }
            .sorted(by: sortMachines)
    }

    var venueName: String {
        let trimmed = state.venueName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? GameRoomPersistedState.defaultVenueName : trimmed
    }

    func area(for id: UUID?) -> GameRoomArea? {
        guard let id else { return nil }
        return state.areas.first(where: { $0.id == id })
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

    func addOwnedMachine(from game: GameRoomCatalogGame, displayVariant: String? = nil) {
        let machine = OwnedMachine(
            catalogGameID: game.catalogGameID,
            canonicalPracticeIdentity: game.canonicalPracticeIdentity,
            displayTitle: game.displayTitle,
            displayVariant: normalizedOptionalString(displayVariant) ?? game.displayVariant,
            manufacturer: game.manufacturer,
            year: game.year
        )
        state.ownedMachines.append(machine)
        saveAndRecompute()
    }

    func updateMachine(
        id: UUID,
        areaID: UUID?,
        groupNumber: Int?,
        position: Int?,
        status: OwnedMachineStatus,
        displayVariant: String?,
        purchaseSource: String?,
        serialNumber: String?,
        ownershipNotes: String?
    ) {
        guard let index = state.ownedMachines.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        state.ownedMachines[index].gameRoomAreaID = areaID
        state.ownedMachines[index].groupNumber = groupNumber
        state.ownedMachines[index].position = position
        state.ownedMachines[index].status = status
        state.ownedMachines[index].displayVariant = normalizedOptionalString(displayVariant)
        state.ownedMachines[index].purchaseSource = normalizedOptionalString(purchaseSource)
        state.ownedMachines[index].serialNumber = normalizedOptionalString(serialNumber)
        state.ownedMachines[index].ownershipNotes = normalizedOptionalString(ownershipNotes)
        state.ownedMachines[index].updatedAt = now
        saveAndRecompute()
    }

    func deleteMachine(id: UUID) {
        state.ownedMachines.removeAll { $0.id == id }
        state.events.removeAll { $0.ownedMachineID == id }
        state.issues.removeAll { $0.ownedMachineID == id }
        state.attachments.removeAll { $0.ownedMachineID == id }
        state.reminderConfigs.removeAll { $0.ownedMachineID == id }
        state.importRecords.removeAll { $0.createdOwnedMachineID == id }
        snapshots.removeValue(forKey: id)
        saveAndRecompute()
    }

    func updateEvent(id: UUID, occurredAt: Date, summary: String, notes: String?) {
        guard let index = state.events.firstIndex(where: { $0.id == id }) else { return }
        state.events[index].occurredAt = occurredAt
        state.events[index].summary = normalizedOptionalString(summary) ?? "Event"
        state.events[index].notes = normalizedOptionalString(notes)
        state.events[index].updatedAt = Date()
        saveAndRecompute()
    }

    func deleteEvent(id: UUID) {
        state.events.removeAll { $0.id == id }
        state.attachments.removeAll { $0.ownerType == .event && $0.ownerID == id }
        saveAndRecompute()
    }

    @discardableResult
    func addEvent(
        machineID: UUID,
        type: MachineEventType,
        category: MachineEventCategory,
        occurredAt: Date = Date(),
        playCountAtEvent: Int? = nil,
        summary: String,
        notes: String? = nil,
        partsUsed: String? = nil,
        consumablesUsed: String? = nil,
        pitchValue: Double? = nil,
        pitchMeasurementPoint: String? = nil,
        linkedIssueID: UUID? = nil
    ) -> UUID {
        let now = Date()
        let event = MachineEvent(
            ownedMachineID: machineID,
            type: type,
            category: category,
            occurredAt: occurredAt,
            playCountAtEvent: playCountAtEvent,
            summary: normalizedOptionalString(summary) ?? "Event",
            notes: normalizedOptionalString(notes),
            partsUsed: normalizedOptionalString(partsUsed),
            consumablesUsed: normalizedOptionalString(consumablesUsed),
            pitchValue: pitchValue,
            pitchMeasurementPoint: normalizedOptionalString(pitchMeasurementPoint),
            linkedIssueID: linkedIssueID,
            createdAt: now,
            updatedAt: now
        )
        state.events.append(event)
        saveAndRecompute()
        return event.id
    }

    @discardableResult
    func openIssue(
        machineID: UUID,
        openedAt: Date = Date(),
        symptom: String,
        severity: MachineIssueSeverity = .medium,
        subsystem: MachineIssueSubsystem = .other,
        diagnosis: String? = nil
    ) -> UUID {
        let now = Date()
        let issue = MachineIssue(
            ownedMachineID: machineID,
            status: .open,
            severity: severity,
            subsystem: subsystem,
            symptom: normalizedOptionalString(symptom) ?? "Issue",
            diagnosis: normalizedOptionalString(diagnosis),
            openedAt: openedAt,
            createdAt: now,
            updatedAt: now
        )
        state.issues.append(issue)
        saveAndRecompute()
        return issue.id
    }

    func resolveIssue(id: UUID, resolvedAt: Date = Date(), resolution: String?) {
        guard let index = state.issues.firstIndex(where: { $0.id == id }) else { return }
        state.issues[index].status = .resolved
        state.issues[index].resolvedAt = resolvedAt
        state.issues[index].resolution = normalizedOptionalString(resolution)
        state.issues[index].updatedAt = Date()
        saveAndRecompute()
    }

    func addAttachment(
        machineID: UUID,
        ownerType: MachineAttachmentOwnerType,
        ownerID: UUID,
        kind: MachineAttachmentKind,
        uri: String,
        caption: String? = nil
    ) {
        let normalizedURI = normalizedOptionalString(uri)
        guard let normalizedURI else { return }
        state.attachments.append(
            MachineAttachment(
                ownedMachineID: machineID,
                ownerType: ownerType,
                ownerID: ownerID,
                kind: kind,
                uri: normalizedURI,
                caption: normalizedOptionalString(caption)
            )
        )
        saveAndRecompute()
    }

    func updateAttachment(
        id: UUID,
        caption: String?,
        notes: String?
    ) {
        guard let attachmentIndex = state.attachments.firstIndex(where: { $0.id == id }) else { return }
        state.attachments[attachmentIndex].caption = normalizedOptionalString(caption)

        let attachment = state.attachments[attachmentIndex]
        if attachment.ownerType == .event,
           let eventIndex = state.events.firstIndex(where: { $0.id == attachment.ownerID }) {
            state.events[eventIndex].notes = normalizedOptionalString(notes)
            state.events[eventIndex].updatedAt = Date()
        }

        saveAndRecompute()
    }

    func deleteAttachmentAndLinkedEvent(id: UUID) {
        guard let attachment = state.attachments.first(where: { $0.id == id }) else { return }
        state.attachments.removeAll { $0.id == id }

        if attachment.ownerType == .event {
            state.events.removeAll { $0.id == attachment.ownerID }
            state.attachments.removeAll { $0.ownerType == .event && $0.ownerID == attachment.ownerID }
        }

        saveAndRecompute()
    }

    func upsertArea(id: UUID? = nil, name: String, areaOrder: Int) {
        let normalizedName = normalizedOptionalString(name) ?? "Area"
        let now = Date()

        if let id, let index = state.areas.firstIndex(where: { $0.id == id }) {
            state.areas[index].name = normalizedName
            state.areas[index].areaOrder = max(0, areaOrder)
            state.areas[index].updatedAt = now
        } else if let index = state.areas.firstIndex(where: { $0.name.caseInsensitiveCompare(normalizedName) == .orderedSame }) {
            state.areas[index].name = normalizedName
            state.areas[index].areaOrder = max(0, areaOrder)
            state.areas[index].updatedAt = now
        } else {
            state.areas.append(
                GameRoomArea(
                    name: normalizedName,
                    areaOrder: max(0, areaOrder),
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        state.areas.sort {
            if $0.areaOrder != $1.areaOrder { return $0.areaOrder < $1.areaOrder }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        saveAndRecompute()
    }

    func deleteArea(id: UUID) {
        state.areas.removeAll { $0.id == id }
        for index in state.ownedMachines.indices where state.ownedMachines[index].gameRoomAreaID == id {
            state.ownedMachines[index].gameRoomAreaID = nil
            state.ownedMachines[index].updatedAt = Date()
        }
        saveAndRecompute()
    }

    func updateVenueName(_ rawName: String) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        state.venueName = trimmed.isEmpty ? GameRoomPersistedState.defaultVenueName : trimmed
        saveAndRecompute()
    }

    func hasImportFingerprint(_ fingerprint: String) -> Bool {
        let normalized = fingerprint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return state.importRecords.contains {
            $0.fingerprint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
    }

    func hasOwnedMachine(catalogGameID: String, displayVariant: String?) -> Bool {
        existingOwnedMachine(catalogGameID: catalogGameID, displayVariant: displayVariant) != nil
    }

    func existingOwnedMachine(catalogGameID: String, displayVariant: String?) -> OwnedMachine? {
        let normalizedCatalogID = catalogGameID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedCatalogID.isEmpty else { return nil }
        let normalizedVariant = normalizedOptionalString(displayVariant)?.lowercased()
        return state.ownedMachines.first { machine in
            guard machine.catalogGameID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedCatalogID else {
                return false
            }
            let machineVariant = normalizedOptionalString(machine.displayVariant)?.lowercased()
            return machineVariant == normalizedVariant
        }
    }

    @discardableResult
    func importOwnedMachine(
        game: GameRoomCatalogGame,
        sourceUserOrURL: String,
        sourceItemKey: String?,
        rawTitle: String,
        rawVariant: String?,
        rawPurchaseDateText: String?,
        normalizedPurchaseDate: Date?,
        matchConfidence: MachineImportMatchConfidence,
        fingerprint: String?
    ) -> UUID {
        let now = Date()
        let machine = OwnedMachine(
            catalogGameID: game.catalogGameID,
            canonicalPracticeIdentity: game.canonicalPracticeIdentity,
            displayTitle: game.displayTitle,
            displayVariant: normalizedOptionalString(rawVariant) ?? game.displayVariant,
            importedSourceTitle: normalizedOptionalString(rawTitle),
            manufacturer: game.manufacturer,
            year: game.year,
            purchaseDate: normalizedPurchaseDate,
            purchaseDateRawText: normalizedOptionalString(rawPurchaseDateText),
            createdAt: now,
            updatedAt: now
        )
        state.ownedMachines.append(machine)

        let importRecord = MachineImportRecord(
            source: .pinside,
            sourceUserOrURL: sourceUserOrURL,
            sourceItemKey: normalizedOptionalString(sourceItemKey),
            rawTitle: normalizedOptionalString(rawTitle) ?? game.displayTitle,
            rawVariant: normalizedOptionalString(rawVariant),
            rawPurchaseDateText: normalizedOptionalString(rawPurchaseDateText),
            normalizedPurchaseDate: normalizedPurchaseDate,
            matchedCatalogGameID: game.catalogGameID,
            matchConfidence: matchConfidence,
            createdOwnedMachineID: machine.id,
            importedAt: now,
            fingerprint: normalizedOptionalString(fingerprint)
        )
        state.importRecords.append(importRecord)
        saveAndRecompute()
        return machine.id
    }

    private func sortMachines(lhs: OwnedMachine, rhs: OwnedMachine) -> Bool {
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

    private func recomputeSnapshots() {
        var nextSnapshots: [UUID: OwnedMachineSnapshot] = [:]
        let now = Date()

        for machine in state.ownedMachines {
            let machineEvents = state.events
                .filter { $0.ownedMachineID == machine.id }
                .sorted { $0.occurredAt > $1.occurredAt }
            let machineIssues = state.issues.filter { $0.ownedMachineID == machine.id }
            let openIssueCount = machineIssues.filter { $0.status != .resolved }.count
            let currentPlayCount = currentPlayCount(for: machineEvents)
            let dueTaskCount = dueTaskCount(for: machine, events: machineEvents, currentPlayCount: currentPlayCount, now: now)
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

            func latestEvent(_ type: MachineEventType) -> MachineEvent? {
                machineEvents.first(where: { $0.type == type })
            }

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

    private func dueTaskCount(for machine: OwnedMachine, events: [MachineEvent], currentPlayCount: Int, now: Date) -> Int {
        guard machine.status == .active || machine.status == .loaned else { return 0 }

        let configs = effectiveReminderConfigs(for: machine.id)
        guard !configs.isEmpty else { return 0 }
        let lastTaskPlayCounts = lastTaskPlayCounts(events: events)

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
                let lastPerformedAt = latestEventDate(for: config.taskType, events: events)
                if let lastPerformedAt {
                    if let dueAt = Calendar.current.date(byAdding: .day, value: intervalDays, to: lastPerformedAt),
                       now >= dueAt {
                        count += 1
                    }
                } else {
                    // A configured routine with no history is considered due.
                    count += 1
                }
            }
        }
        return count
    }

    private func currentPlayCount(for eventsDesc: [MachineEvent]) -> Int {
        let eventsAsc = eventsDesc.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        var runningTotal = 0
        for event in eventsAsc {
            guard let total = playLogTotal(for: event) else { continue }
            runningTotal = total
        }
        return runningTotal
    }

    private func lastTaskPlayCounts(events eventsDesc: [MachineEvent]) -> [MachineReminderTaskType: Int] {
        let eventsAsc = eventsDesc.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        var runningPlayCount = 0
        var lastByTask: [MachineReminderTaskType: Int] = [:]

        for event in eventsAsc {
            if let total = playLogTotal(for: event) {
                runningPlayCount = total
            }
            for taskType in MachineReminderTaskType.allCases where eventTypes(for: taskType).contains(event.type) {
                lastByTask[taskType] = runningPlayCount
            }
        }
        return lastByTask
    }

    private func latestEventDate(for taskType: MachineReminderTaskType, events: [MachineEvent]) -> Date? {
        let candidateTypes = eventTypes(for: taskType)

        return events.first(where: { candidateTypes.contains($0.type) })?.occurredAt
    }

    private func eventTypes(for taskType: MachineReminderTaskType) -> [MachineEventType] {
        switch taskType {
        case .glassCleaned:
            return [.glassCleaned]
        case .playfieldCleaned:
            return [.playfieldCleaned]
        case .ballsReplaced:
            return [.ballsReplaced]
        case .pitchChecked:
            return [.pitchChecked]
        case .machineLeveled:
            return [.machineLeveled]
        case .rubbersReplaced:
            return [.rubbersReplaced]
        case .flipperServiced:
            return [.flipperServiced]
        case .generalInspection:
            return [.generalInspection]
        }
    }

    private func isPlayCountEvent(_ event: MachineEvent) -> Bool {
        event.type == .custom && event.category == .custom
    }

    private func playLogTotal(for event: MachineEvent) -> Int? {
        guard isPlayCountEvent(event),
              let value = event.playCountAtEvent,
              value >= 0 else {
            return nil
        }
        return value
    }

    private func effectiveReminderConfigs(for machineID: UUID) -> [MachineReminderConfig] {
        let machineConfigs = state.reminderConfigs
            .filter { $0.ownedMachineID == machineID }
            .sorted { lhs, rhs in
                lhs.taskType.rawValue < rhs.taskType.rawValue
            }
        if !machineConfigs.isEmpty {
            return machineConfigs
        }
        return defaultReminderConfigs(for: machineID)
    }

    private func defaultReminderConfigs(for machineID: UUID) -> [MachineReminderConfig] {
        let now = Date()
        return [
            MachineReminderConfig(
                ownedMachineID: machineID,
                taskType: .glassCleaned,
                mode: .dateBased,
                intervalDays: 30,
                createdAt: now,
                updatedAt: now
            ),
            MachineReminderConfig(
                ownedMachineID: machineID,
                taskType: .playfieldCleaned,
                mode: .dateBased,
                intervalDays: 90,
                createdAt: now,
                updatedAt: now
            ),
            MachineReminderConfig(
                ownedMachineID: machineID,
                taskType: .ballsReplaced,
                mode: .playBased,
                intervalPlays: 5000,
                createdAt: now,
                updatedAt: now
            ),
            MachineReminderConfig(
                ownedMachineID: machineID,
                taskType: .generalInspection,
                mode: .dateBased,
                intervalDays: 45,
                createdAt: now,
                updatedAt: now
            )
        ]
    }

    private func saveAndRecompute() {
        recomputeSnapshots()
        saveState()
        postPinballLibrarySourcesDidChange()
    }

    private func normalizedOptionalString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
