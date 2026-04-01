import XCTest
@testable import PinProf

final class LibraryImportedSourcesStoreTests: XCTestCase {
    func testUpsertReplacesExistingVenueMachineIDs() throws {
        let defaults = UserDefaults.standard
        let importedSourcesKey = "pinball-imported-sources-v1"
        let priorImportedSources = defaults.data(forKey: importedSourcesKey)

        defer {
            if let priorImportedSources {
                defaults.set(priorImportedSources, forKey: importedSourcesKey)
            } else {
                defaults.removeObject(forKey: importedSourcesKey)
            }
        }

        PinballImportedSourcesStore.save([])

        let sourceID = "venue--pm-16470"
        PinballImportedSourcesStore.upsert(
            PinballImportedSourceRecord(
                id: sourceID,
                name: "RLM Amusements",
                type: .venue,
                provider: .pinballMap,
                providerSourceID: "16470",
                machineIDs: ["game-a", "game-b", "game-c"],
                lastSyncedAt: Date(timeIntervalSince1970: 100),
                searchQuery: "rlm",
                distanceMiles: 25
            )
        )

        PinballImportedSourcesStore.upsert(
            PinballImportedSourceRecord(
                id: sourceID,
                name: "RLM Amusements",
                type: .venue,
                provider: .pinballMap,
                providerSourceID: "16470",
                machineIDs: ["game-a"],
                lastSyncedAt: Date(timeIntervalSince1970: 200),
                searchQuery: "rlm",
                distanceMiles: 25
            )
        )

        let savedRecord = try XCTUnwrap(PinballImportedSourcesStore.load().first(where: { $0.id == sourceID }))
        XCTAssertEqual(savedRecord.machineIDs, ["game-a"])
        XCTAssertEqual(savedRecord.lastSyncedAt, Date(timeIntervalSince1970: 200))
    }
}
