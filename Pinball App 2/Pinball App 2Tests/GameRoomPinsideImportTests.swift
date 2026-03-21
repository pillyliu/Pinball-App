import XCTest
@testable import PinProf

final class GameRoomPinsideImportTests: XCTestCase {
    func testCanonicalPinsideDisplayedTitlePrefersSlugDerivedAnniversaryVariantOverPremiumSuffix() {
        let parsed = canonicalPinsideDisplayedTitle(
            "Godzilla (70th Anniversary Premium)",
            fallbackVariant: "70th Anniversary"
        )

        XCTAssertEqual(parsed.title, "Godzilla")
        XCTAssertEqual(parsed.variant, "70th Anniversary")
    }

    func testCanonicalPinsideDisplayedTitleKeepsStandardPremiumVariantLabels() {
        let parsed = canonicalPinsideDisplayedTitle(
            "Foo Fighters (Premium)",
            fallbackVariant: nil
        )

        XCTAssertEqual(parsed.title, "Foo Fighters")
        XCTAssertEqual(parsed.variant, "Premium")
    }
}
