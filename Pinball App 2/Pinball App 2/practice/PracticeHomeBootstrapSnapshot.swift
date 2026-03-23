import Foundation

nonisolated struct PracticeHomeBootstrapSnapshot: Codable {
    static let currentSchemaVersion = 1

    nonisolated struct Source: Codable {
        let id: String
        let name: String
        let type: PinballLibrarySourceType

        init(source: PinballLibrarySource) {
            id = source.id
            name = source.name
            type = source.type
        }

        var librarySource: PinballLibrarySource {
            PinballLibrarySource(
                id: id,
                name: name,
                type: type
            )
        }
    }

    nonisolated struct Game: Codable {
        let libraryEntryID: String?
        let practiceIdentity: String?
        let opdbID: String?
        let opdbMachineID: String?
        let variant: String?
        let sourceID: String
        let sourceName: String
        let sourceType: PinballLibrarySourceType
        let area: String?
        let areaOrder: Int?
        let group: Int?
        let position: Int?
        let bank: Int?
        let name: String
        let manufacturer: String?
        let year: Int?
        let slug: String
        let primaryImageUrl: String?
        let primaryImageLargeUrl: String?
        let playfieldImageUrl: String?
        let alternatePlayfieldImageUrl: String?
        let playfieldLocalOriginal: String?
        let playfieldLocal: String?

        init(game: PinballGame) {
            libraryEntryID = game.libraryEntryID
            practiceIdentity = game.practiceIdentity
            opdbID = game.opdbID
            opdbMachineID = game.opdbMachineID
            variant = game.variant
            sourceID = game.sourceId
            sourceName = game.sourceName
            sourceType = game.sourceType
            area = game.area
            areaOrder = game.areaOrder
            group = game.group
            position = game.pos
            bank = game.bank
            name = game.name
            manufacturer = game.manufacturer
            year = game.year
            slug = game.slug
            primaryImageUrl = game.primaryImageUrl
            primaryImageLargeUrl = game.primaryImageLargeUrl
            playfieldImageUrl = game.playfieldImageUrl
            alternatePlayfieldImageUrl = game.alternatePlayfieldImageUrl
            playfieldLocalOriginal = game.playfieldLocalOriginal
            playfieldLocal = game.playfieldLocal
        }

        nonisolated var pinballGame: PinballGame {
            PinballGame(snapshot: self)
        }
    }

    let schemaVersion: Int
    let capturedAt: Date
    let playerName: String
    let selectedGroupID: UUID?
    let customGroups: [CustomGameGroup]
    let selectedLibrarySourceID: String?
    let librarySources: [Source]
    let visibleGames: [Game]
    let lookupGames: [Game]

    var isUsable: Bool {
        !playerName.isEmpty ||
            !customGroups.isEmpty ||
            !librarySources.isEmpty ||
            !visibleGames.isEmpty ||
            !lookupGames.isEmpty
    }
}

enum PracticeHomeBootstrapSnapshotStore {
    private static let directoryName = "practice-cache"
    private static let fileName = "practice-home-bootstrap.json"

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    static func load() -> PracticeHomeBootstrapSnapshot? {
        PinballPerformanceTrace.measure("PracticeHomeSnapshotLoad") {
            guard let fileURL = loadFileURL(),
                  let data = try? Data(contentsOf: fileURL),
                  let snapshot = try? decoder.decode(PracticeHomeBootstrapSnapshot.self, from: data),
                  snapshot.schemaVersion == PracticeHomeBootstrapSnapshot.currentSchemaVersion,
                  snapshot.isUsable else {
                return nil
            }
            return snapshot
        }
    }

    static func loadAsync() async -> PracticeHomeBootstrapSnapshot? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: load())
            }
        }
    }

    static func save(_ snapshot: PracticeHomeBootstrapSnapshot) {
        guard snapshot.isUsable else { return }
        DispatchQueue.global(qos: .utility).async {
            PinballPerformanceTrace.measure("PracticeHomeSnapshotSave") {
                guard let fileURL = saveFileURL(),
                      let data = try? encoder.encode(snapshot) else {
                    return
                }
                try? FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    private static func loadFileURL() -> URL? {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return baseURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private static func saveFileURL() -> URL? {
        guard let baseURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }
        return baseURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }
}

extension PinballGame {
    nonisolated init(snapshot: PracticeHomeBootstrapSnapshot.Game) {
        sourceId = snapshot.sourceID
        sourceName = snapshot.sourceName
        sourceType = snapshot.sourceType
        area = snapshot.area
        areaOrder = snapshot.areaOrder
        group = snapshot.group
        pos = snapshot.position
        bank = snapshot.bank
        name = snapshot.name
        variant = snapshot.variant
        manufacturer = snapshot.manufacturer
        year = snapshot.year
        slug = snapshot.slug
        libraryEntryID = snapshot.libraryEntryID
        opdbID = snapshot.opdbID
        opdbMachineID = snapshot.opdbMachineID
        practiceIdentity = snapshot.practiceIdentity
        opdbName = nil
        opdbCommonName = nil
        opdbShortname = nil
        opdbDescription = nil
        opdbType = nil
        opdbDisplay = nil
        opdbPlayerCount = nil
        opdbManufactureDate = nil
        opdbIpdbID = nil
        opdbGroupShortname = nil
        opdbGroupDescription = nil
        primaryImageUrl = snapshot.primaryImageUrl
        primaryImageLargeUrl = snapshot.primaryImageLargeUrl
        playfieldImageUrl = snapshot.playfieldImageUrl
        alternatePlayfieldImageUrl = snapshot.alternatePlayfieldImageUrl
        playfieldSourceLabel = nil
        playfieldLocalOriginal = normalizeLibraryCachePath(snapshot.playfieldLocalOriginal)
        playfieldLocal = normalizeLibraryPlayfieldLocalPath(snapshot.playfieldLocal)
        gameinfoLocal = nil
        rulesheetLocal = nil
        rulesheetUrl = nil
        rulesheetLinks = []
        videos = []
    }
}
