import XCTest
@testable import PinProf

final class RulesheetLinkResolutionTests: XCTestCase {
    func testResolveRulesheetLinksKeepsLocalPathWhenExternalSiblingSortsFirst() {
        let resolved = resolveRulesheetLinks(
            override: nil,
            rulesheetLinks: [
                CatalogRulesheetLinkRecord(
                    practiceIdentity: "GrkL5",
                    provider: "pinprof",
                    label: "Rulesheet (PinProf)",
                    localPath: "/pinball/rulesheets/GrkL5-rulesheet.md",
                    url: nil,
                    priority: 0
                ),
                CatalogRulesheetLinkRecord(
                    practiceIdentity: "GrkL5",
                    provider: "pinprof",
                    label: "Rulesheet",
                    localPath: nil,
                    url: "https://pinballnews.com/games/tron/index6b.html",
                    priority: 0
                ),
                CatalogRulesheetLinkRecord(
                    practiceIdentity: "GrkL5",
                    provider: "pp",
                    label: "Rulesheet (PP)",
                    localPath: nil,
                    url: "https://pinballprimer.github.io/tron_GrkL5.html",
                    priority: 0
                )
            ]
        )

        XCTAssertEqual(resolved.localPath, "/pinball/rulesheets/GrkL5-rulesheet.md")
        XCTAssertEqual(
            resolved.links.map(\.url),
            [
                "https://pinballnews.com/games/tron/index6b.html",
                "https://pinballprimer.github.io/tron_GrkL5.html"
            ]
        )
    }
}
