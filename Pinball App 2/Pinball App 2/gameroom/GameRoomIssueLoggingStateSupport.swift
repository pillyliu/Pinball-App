import Foundation

struct GameRoomIssueLogDraft {
    var openedAt = Date()
    var symptom = ""
    var severity: MachineIssueSeverity = .medium
    var subsystem: MachineIssueSubsystem = .flipper
    var diagnosis = ""
    var attachments: [GameRoomIssueAttachmentDraft] = []

    var trimmedSymptom: String {
        symptom.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedDiagnosis: String? {
        gameRoomNormalizedOptional(diagnosis)
    }

    mutating func deleteAttachment(id: UUID) {
        attachments.removeAll { $0.id == id }
    }

    mutating func appendAttachment(kind: MachineAttachmentKind, url: URL) {
        attachments.append(
            GameRoomIssueAttachmentDraft(
                kind: kind,
                uri: url.path,
                caption: gameRoomImportedMediaCaption(for: url)
            )
        )
    }
}
