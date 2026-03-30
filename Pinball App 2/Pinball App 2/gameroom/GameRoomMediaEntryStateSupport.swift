import Foundation

enum GameRoomMediaEntryField: Hashable {
    case uri
    case caption
    case notes
}

struct GameRoomMediaEntryDraft {
    var kind: MachineAttachmentKind = .photo
    var uri = ""
    var caption = ""
    var notes = ""

    var trimmedURI: String {
        uri.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedCaption: String? {
        gameRoomNormalizedOptional(caption)
    }

    var normalizedNotes: String? {
        gameRoomNormalizedOptional(notes)
    }

    var resolvedMediaURL: URL? {
        gameRoomResolvedMediaURL(from: uri)
    }
}
