import XCTest
@testable import Pinball_App_2

final class PracticeStateCodecTests: XCTestCase {
    func testCanonicalFixtureDecodesWithMillisecondsStrategy() throws {
        let data = try fixtureData(named: "canonical_millis_v4")
        let decoded = try PracticeStateCodec.decode(data)

        XCTAssertFalse(decoded.usedFallbackDateDecoding)
        XCTAssertEqual(decoded.state.practiceSettings.playerName, "P")
        XCTAssertEqual(decoded.state.leagueSettings.playerName, "L")
        XCTAssertEqual(decoded.state.studyEvents.first?.progressPercent, 60)
        XCTAssertEqual(decoded.state.customGroups.count, 1)
        XCTAssertEqual(decoded.state.customGroups.first?.isPriority, true)
    }

    func testLegacyReferenceDateFixtureUsesFallbackAndConvertsToUnixTime() throws {
        let data = try fixtureData(named: "legacy_reference_date_v4")
        let decoded = try PracticeStateCodec.decode(data)

        XCTAssertTrue(decoded.usedFallbackDateDecoding)
        XCTAssertEqual(decoded.state.practiceSettings.playerName, "Legacy P")
        XCTAssertEqual(decoded.state.leagueSettings.playerName, "Legacy L")
        XCTAssertEqual(decoded.state.studyEvents.first?.progressPercent, 40)

        let timestamp = decoded.state.studyEvents.first?.timestamp.timeIntervalSince1970 ?? 0
        XCTAssertGreaterThan(timestamp, 1_700_000_000)
    }

    private func fixtureData(named name: String) throws -> Data {
        let fixturesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
        return try Data(contentsOf: fixturesDir.appendingPathComponent("\(name).json"))
    }
}
