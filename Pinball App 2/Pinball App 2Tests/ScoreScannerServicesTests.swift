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

    func testParsingNormalizesLowercaseAndSegmentedGlyphConfusions() {
        let observations = [
            ScoreOCRObservation(text: "!2,s50,0L5", confidence: 0.69, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 12_550_015)
        XCTAssertEqual(candidate?.formattedScore, "12,550,015")
    }

    func testParsingPrefersCenteredCandidateBeforeConfidence() {
        let observations = [
            ScoreOCRObservation(text: "1234567", confidence: 0.92, boundingBox: CGRect(x: 0.02, y: 0.10, width: 0.24, height: 0.14)),
            ScoreOCRObservation(text: "123456", confidence: 0.70, boundingBox: CGRect(x: 0.38, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 123_456)
    }

    func testParsingExtractsScoreFromMixedOCRText() {
        let observations = [
            ScoreOCRObservation(text: "SCORE 12,450,000 BALL 2", confidence: 0.68, boundingBox: CGRect(x: 0.44, y: 0.38, width: 0.28, height: 0.16))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 12_450_000)
        XCTAssertEqual(candidate?.formattedScore, "12,450,000")
    }

    func testParsingPrefersLongerScoreOverTinyCenteredFragmentWhenGapIsLarge() {
        let observations = [
            ScoreOCRObservation(text: "65", confidence: 0.90, boundingBox: CGRect(x: 0.45, y: 0.42, width: 0.10, height: 0.16)),
            ScoreOCRObservation(text: "650,781,260", confidence: 0.64, boundingBox: CGRect(x: 0.22, y: 0.38, width: 0.54, height: 0.16))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 650_781_260)
    }

    func testManualScoreFormattingSupportsLargeValuesAndPreservesZeroInput() {
        XCTAssertEqual(ScoreParsingService.normalizedScore(fromManualInput: "9,876,543,210"), 9_876_543_210)
        XCTAssertEqual(ScoreParsingService.formattedScoreInput(from: "9876543210"), "9,876,543,210")
        XCTAssertEqual(ScoreParsingService.formattedScoreInput(from: "0"), "0")
        XCTAssertNil(ScoreParsingService.normalizedScore(fromManualInput: "0"))
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

    func testFrameMapperMapsTargetRectWhenPreviewMatchesFrameAspectRatio() {
        let mapping = ScoreScannerPreviewMapping(
            previewBounds: CGRect(x: 0, y: 0, width: 50, height: 100),
            targetRect: CGRect(x: 10, y: 20, width: 30, height: 10)
        )

        let cropRect = ScoreScannerFrameMapper.cropRect(
            frameExtent: CGRect(x: 0, y: 0, width: 100, height: 200),
            previewMapping: mapping
        )

        XCTAssertEqual(cropRect, CGRect(x: 20, y: 140, width: 60, height: 20))
    }

    func testFrameMapperAccountsForAspectFillCropping() {
        let mapping = ScoreScannerPreviewMapping(
            previewBounds: CGRect(x: 0, y: 0, width: 50, height: 200),
            targetRect: CGRect(x: 5, y: 50, width: 40, height: 20)
        )

        let cropRect = ScoreScannerFrameMapper.cropRect(
            frameExtent: CGRect(x: 0, y: 0, width: 100, height: 200),
            previewMapping: mapping
        )

        XCTAssertEqual(cropRect, CGRect(x: 30, y: 130, width: 40, height: 20))
    }
}
