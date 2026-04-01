import XCTest
@testable import PinProf

final class LibrarySourceIdentityTests: XCTestCase {
    func testImportedPinballMapVenueNeedsStaleRefreshWhenSyncedBeforeCutoff() {
        let source = PinballImportedSourceRecord(
            id: "venue--pm-16470",
            name: "RLM Amusements",
            type: .venue,
            provider: .pinballMap,
            providerSourceID: "16470",
            machineIDs: ["game-a", "game-b"],
            lastSyncedAt: staleImportedPinballMapVenueRefreshCutoff.addingTimeInterval(-1),
            searchQuery: "rlm",
            distanceMiles: 25
        )

        XCTAssertTrue(importedPinballMapVenueNeedsStaleRefresh(source))
    }

    func testImportedPinballMapVenueNeedsStaleRefreshSkipsNewerOrUnsyncedSources() {
        let newerVenue = PinballImportedSourceRecord(
            id: "venue--pm-16470",
            name: "RLM Amusements",
            type: .venue,
            provider: .pinballMap,
            providerSourceID: "16470",
            machineIDs: ["game-a"],
            lastSyncedAt: staleImportedPinballMapVenueRefreshCutoff.addingTimeInterval(1),
            searchQuery: "rlm",
            distanceMiles: 25
        )
        let unsyncedVenue = PinballImportedSourceRecord(
            id: "venue--pm-10819",
            name: "Electric Bat Arcade",
            type: .venue,
            provider: .pinballMap,
            providerSourceID: "10819",
            machineIDs: ["game-a"],
            lastSyncedAt: nil,
            searchQuery: "electric bat",
            distanceMiles: 25
        )
        let manufacturer = PinballImportedSourceRecord(
            id: "manufacturer-12",
            name: "Stern",
            type: .manufacturer,
            provider: .opdb,
            providerSourceID: "12",
            machineIDs: [],
            lastSyncedAt: staleImportedPinballMapVenueRefreshCutoff.addingTimeInterval(-1),
            searchQuery: nil,
            distanceMiles: nil
        )

        XCTAssertFalse(importedPinballMapVenueNeedsStaleRefresh(newerVenue))
        XCTAssertFalse(importedPinballMapVenueNeedsStaleRefresh(unsyncedVenue))
        XCTAssertFalse(importedPinballMapVenueNeedsStaleRefresh(manufacturer))
    }
}
