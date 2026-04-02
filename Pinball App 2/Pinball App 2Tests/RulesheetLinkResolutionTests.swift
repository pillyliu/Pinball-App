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

    func testHostedPinProfResourcesUsePinProfChips() throws {
        let game = try makeGame(
            practiceIdentity: "GrkL5",
            opdbID: "GrkL5-MJoNN",
            playfieldLocalPath: "/pinball/images/playfields/GrkL5-MJoNN-playfield.webp",
            rulesheetLocalPath: "/pinball/rulesheets/GrkL5-rulesheet.md"
        )

        XCTAssertEqual("PinProf", game.localRulesheetChipTitle)
        XCTAssertEqual("PinProf", game.localPlayfieldChipTitle)
        XCTAssertEqual("PinProf", game.resolvedPlayfieldOptions(liveStatus: nil).first?.title)
    }

    func testBundledOnlyFinalExamResourcesStayLocal() throws {
        let game = try makeGame(
            practiceIdentity: "G900001",
            opdbID: "G900001-1",
            playfieldLocalPath: "/pinball/images/playfields/G900001-1-playfield.webp",
            rulesheetLocalPath: "/pinball/rulesheets/G900001-rulesheet.md"
        )

        XCTAssertEqual("Local", game.localRulesheetChipTitle)
        XCTAssertEqual("Local", game.localPlayfieldChipTitle)
        XCTAssertEqual("Local", game.resolvedPlayfieldOptions(liveStatus: nil).first?.title)
        let hostedLiveStatus = LibraryLivePlayfieldStatus(
            effectiveKind: .pillyliu,
            effectiveURL: URL(string: "https://pillyliu.com/pinball/images/playfields/G900001-1-playfield.webp")
        )
        XCTAssertEqual("Local", game.resolvedPlayfieldOptions(liveStatus: hostedLiveStatus).first?.title)
        XCTAssertEqual("Local", game.resolvedPlayfieldButtonLabel(liveStatus: hostedLiveStatus))
    }

    private func makeGame(
        practiceIdentity: String,
        opdbID: String,
        playfieldLocalPath: String,
        rulesheetLocalPath: String
    ) throws -> PinballGame {
        let payload: [String: Any] = [
            "source_id": "venue--test",
            "source_name": "Test Venue",
            "source_type": "venue",
            "name": "Test Game",
            "slug": practiceIdentity.lowercased(),
            "practice_identity": practiceIdentity,
            "opdb_id": opdbID,
            "assets": [
                "playfield_local_practice": playfieldLocalPath,
                "rulesheet_local_practice": rulesheetLocalPath
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(PinballGame.self, from: data)
    }
}
