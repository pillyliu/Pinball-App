import XCTest
@testable import PinProf

final class ScoreScannerServicesTests: XCTestCase {
    func testParsingNormalizesCommonOCRConfusions() {
        let observations = [
            ScoreOCRObservation(text: "I2,O5O,O0S", confidence: 0.72, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 12_050_005)
        XCTAssertEqual(candidate?.formattedScore, "12,050,005")
    }

    func testParsingPrefersCenteredCandidateBeforeConfidence() {
        let observations = [
            ScoreOCRObservation(text: "1234567", confidence: 0.92, boundingBox: CGRect(x: 0.02, y: 0.10, width: 0.24, height: 0.14)),
            ScoreOCRObservation(text: "123456", confidence: 0.70, boundingBox: CGRect(x: 0.38, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 123_456)
    }

    func testStabilityLocksAfterRepeatedConsensus() {
        let service = ScoreStabilityService()
        let candidate = ScoreScannerCandidate(
            rawText: "12,450,000",
            normalizedScore: 12_450_000,
            formattedScore: "12,450,000",
            confidence: 0.56,
            boundingBox: .init(x: 0.4, y: 0.4, width: 0.2, height: 0.1),
            digitCount: 8,
            centerBias: 0.95
        )

        _ = service.ingest(candidate: candidate)
        _ = service.ingest(candidate: candidate)
        let snapshot = service.ingest(candidate: candidate)

        XCTAssertEqual(snapshot.state, .locked)
        XCTAssertEqual(snapshot.dominantReading?.score, 12_450_000)
    }
}
