import XCTest
@testable import PinProf

final class PracticeQuickEntryDefaultsTests: XCTestCase {
    func testInitialLibraryFilterPrefersSelectedGameSourceBeforeAvenueFallback() {
        let initial = resolveInitialQuickEntryLibraryFilterID(
            kind: .score,
            currentSelectedGameSourceID: "venue--latest-spot",
            preferredLibrarySourceID: "",
            avenueLibrarySourceID: "venue--pm-8760",
            defaultPracticeSourceID: "",
            availableLibrarySourceIDs: ["venue--pm-8760", "venue--latest-spot"]
        )

        XCTAssertEqual(initial, "venue--latest-spot")
    }

    func testMechanicsInitialLibraryFilterUsesAllGames() {
        let initial = resolveInitialQuickEntryLibraryFilterID(
            kind: .mechanics,
            currentSelectedGameSourceID: "venue--latest-spot",
            preferredLibrarySourceID: "venue--preferred",
            avenueLibrarySourceID: "venue--pm-8760",
            defaultPracticeSourceID: "venue--default",
            availableLibrarySourceIDs: ["venue--pm-8760", "venue--latest-spot"]
        )

        XCTAssertEqual(initial, quickEntryAllGamesLibraryID)
    }
}
