import XCTest
@testable import PinProf

final class PracticeQuickEntryDefaultsTests: XCTestCase {
    func testInitialLibraryFilterPrefersSelectedGameSourceBeforeAvenueFallback() {
        let initial = resolveInitialQuickEntryLibraryFilterID(
            kind: .score,
            currentSelectedGameSourceID: "venue--latest-spot",
            preferredLibrarySourceID: "",
            avenueLibrarySourceID: "venue--the-avenue-cafe",
            defaultPracticeSourceID: "",
            availableLibrarySourceIDs: ["venue--the-avenue-cafe", "venue--latest-spot"]
        )

        XCTAssertEqual(initial, "venue--latest-spot")
    }

    func testMechanicsInitialLibraryFilterUsesAllGames() {
        let initial = resolveInitialQuickEntryLibraryFilterID(
            kind: .mechanics,
            currentSelectedGameSourceID: "venue--latest-spot",
            preferredLibrarySourceID: "venue--preferred",
            avenueLibrarySourceID: "venue--the-avenue-cafe",
            defaultPracticeSourceID: "venue--default",
            availableLibrarySourceIDs: ["venue--the-avenue-cafe", "venue--latest-spot"]
        )

        XCTAssertEqual(initial, quickEntryAllGamesLibraryID)
    }
}
