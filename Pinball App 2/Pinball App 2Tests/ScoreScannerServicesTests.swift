import XCTest
@testable import PinProf

private extension ScoreParsingService {
    static func bestCandidate(from observations: [ScoreOCRObservation]) -> ScoreScannerCandidate? {
        rankedCandidates(from: observations).first
    }
}

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

    func testParsingNormalizesStylizedLeadingGlyphsInsideScoreRuns() {
        let observations = [
            ScoreOCRObservation(text: "b.264,010", confidence: 0.63, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 6_264_010)
        XCTAssertEqual(candidate?.formattedScore, "6,264,010")
    }

    func testParsingRecoversLeadingEightFromGroupedLeadingZeroRuns() {
        let observations = [
            ScoreOCRObservation(text: "0,082.000", confidence: 0.79, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 8_082_000)
        XCTAssertEqual(candidate?.digitCount, 7)
    }

    func testParsingRecoversLeadingSixFromGroupedLeadingZeroRuns() {
        let observations = [
            ScoreOCRObservation(text: "0.264.010", confidence: 0.79, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 6_264_010)
        XCTAssertEqual(candidate?.formattedScore, "6,264,010")
    }

    func testParsingRecoversMissingLeadingSixFromLeadingSeparatorRun() {
        let observations = [
            ScoreOCRObservation(text: ".264.010", confidence: 0.79, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 6_264_010)
        XCTAssertEqual(candidate?.formattedScore, "6,264,010")
    }

    func testParsingRecoversMissingLeadingEightFromLeadingSeparatorRun() {
        let observations = [
            ScoreOCRObservation(text: ".082.060", confidence: 0.79, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 8_082_060)
        XCTAssertEqual(candidate?.formattedScore, "8,082,060")
    }

    func testParsingRecoversLeadingSevenFromGroupedLeadingOneRuns() {
        let observations = [
            ScoreOCRObservation(text: "1.082.060", confidence: 0.79, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 7_082_060)
        XCTAssertEqual(candidate?.formattedScore, "7,082,060")
    }

    func testParsingRecoversZeroHeavyGroupedRunBackToStylizedEightAndSix() {
        let observations = [
            ScoreOCRObservation(text: "0.002.000", confidence: 0.74, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 8_082_060)
        XCTAssertEqual(candidate?.formattedScore, "8,082,060")
    }

    func testParsingKeepsLegitimateZeroHeavyGroupedScore() {
        let observations = [
            ScoreOCRObservation(text: "2.004.050", confidence: 0.74, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 2_004_050)
        XCTAssertEqual(candidate?.formattedScore, "2,004,050")
    }

    func testParsingPrefersRecoveredFullLengthCandidateOverNoisyRead() {
        let observations = [
            ScoreOCRObservation(text: "0,082.000", confidence: 0.93, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14)),
            ScoreOCRObservation(text: "8,082.060", confidence: 0.58, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 8_082_060)
        XCTAssertEqual(candidate?.rawText, "8,082.060")
        XCTAssertEqual(candidate?.formattedScore, "8,082,060")
    }

    func testParsingPrefersExactGroupedCandidateOverRecoveredLeadingEightVariant() {
        let observations = [
            ScoreOCRObservation(text: "0.082.060", confidence: 0.93, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14)),
            ScoreOCRObservation(text: "8.082.060", confidence: 0.58, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 8_082_060)
        XCTAssertEqual(candidate?.rawText, "8.082.060")
        XCTAssertEqual(candidate?.formattedScore, "8,082,060")
    }

    func testParsingPrefersRecoveredFullLengthCandidateWithPeriodGroupedOCR() {
        let observations = [
            ScoreOCRObservation(text: "0.082.060", confidence: 0.93, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14)),
            ScoreOCRObservation(text: "8.082.060", confidence: 0.58, boundingBox: CGRect(x: 0.48, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 8_082_060)
        XCTAssertEqual(candidate?.rawText, "8.082.060")
        XCTAssertEqual(candidate?.formattedScore, "8,082,060")
    }

    func testParsingPrefersLongerPlausibleCandidateBeforeCenterBias() {
        let observations = [
            ScoreOCRObservation(text: "1234567", confidence: 0.92, boundingBox: CGRect(x: 0.02, y: 0.10, width: 0.24, height: 0.14)),
            ScoreOCRObservation(text: "123456", confidence: 0.70, boundingBox: CGRect(x: 0.38, y: 0.42, width: 0.24, height: 0.14))
        ]

        let candidate = ScoreParsingService.bestCandidate(from: observations)

        XCTAssertEqual(candidate?.normalizedScore, 1_234_567)
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

    func testStabilityPrefersLongerDominantScoreWhenOccurrenceGapIsSmall() {
        let service = ScoreStabilityService()
        let shortCandidate = ScoreScannerCandidate(
            rawText: "123,456",
            normalizedScore: 123_456,
            formattedScore: "123,456",
            confidence: 0.72,
            boundingBox: .init(x: 0.4, y: 0.4, width: 0.2, height: 0.1),
            digitCount: 6,
            centerBias: 0.95
        )
        let longCandidate = ScoreScannerCandidate(
            rawText: "1,234,567",
            normalizedScore: 1_234_567,
            formattedScore: "1,234,567",
            confidence: 0.58,
            boundingBox: .init(x: 0.4, y: 0.4, width: 0.2, height: 0.1),
            digitCount: 7,
            centerBias: 0.9
        )

        _ = service.ingest(candidate: shortCandidate)
        _ = service.ingest(candidate: shortCandidate)
        _ = service.ingest(candidate: longCandidate)
        let snapshot = service.ingest(candidate: longCandidate)

        XCTAssertEqual(snapshot.state, .stableCandidate)
        XCTAssertEqual(snapshot.dominantReading?.score, 1_234_567)
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
