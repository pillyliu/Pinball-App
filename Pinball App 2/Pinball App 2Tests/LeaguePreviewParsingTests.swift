import XCTest
@testable import PinProf

final class LeaguePreviewParsingTests: XCTestCase {
    func testStandingsPreviewUsesSixAroundRowsWhenSelectedPlayerIsOutsideTopFive() {
        let payload = buildLeagueStandingsPreview(
            standingsCSV: standingsCSV,
            selectedPlayer: "Player 8"
        )

        XCTAssertEqual(payload.topRows.count, 5)
        XCTAssertEqual(payload.aroundRows.count, 6)
        XCTAssertEqual(payload.currentPlayerStanding?.rank, 8)
        XCTAssertEqual(payload.aroundRows.map(\.rank), [5, 6, 7, 8, 9, 10])
    }

    func testStandingsPreviewKeepsFiveAroundRowsWhenSelectedPlayerIsInsideTopFive() {
        let payload = buildLeagueStandingsPreview(
            standingsCSV: standingsCSV,
            selectedPlayer: "Player 3"
        )

        XCTAssertEqual(payload.topRows.count, 5)
        XCTAssertEqual(payload.aroundRows.count, 5)
        XCTAssertEqual(payload.currentPlayerStanding?.rank, 3)
        XCTAssertEqual(payload.aroundRows.map(\.rank), [1, 2, 3, 4, 5])
    }

    private var standingsCSV: String {
        """
        season,rank,player,total
        2026,1,Player 1,100
        2026,2,Player 2,90
        2026,3,Player 3,80
        2026,4,Player 4,70
        2026,5,Player 5,60
        2026,6,Player 6,50
        2026,7,Player 7,40
        2026,8,Player 8,30
        2026,9,Player 9,20
        2026,10,Player 10,10
        """
    }
}
