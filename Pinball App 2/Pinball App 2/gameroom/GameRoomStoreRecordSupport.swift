import Foundation

extension GameRoomStore {
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
}
