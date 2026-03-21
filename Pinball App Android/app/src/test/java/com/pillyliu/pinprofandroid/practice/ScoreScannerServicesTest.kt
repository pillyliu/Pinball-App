package com.pillyliu.pinprofandroid.practice

import android.graphics.RectF
import androidx.compose.ui.geometry.Size
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ScoreScannerServicesTest {

    @Test
    fun parsingNormalizesCommonOcrConfusions() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "I2,O5O,O0S",
                    confidence = 0.72f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                )
            )
        )

        assertEquals(12_050_005L, candidate.first().normalizedScore)
        assertEquals("12,050,005", candidate.first().formattedScore)
    }

    @Test
    fun parsingNormalizesLowercaseAndSegmentedGlyphConfusions() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "!2,s50,0L5",
                    confidence = 0.69f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                )
            )
        )

        assertEquals(12_550_015L, candidate.first().normalizedScore)
        assertEquals("12,550,015", candidate.first().formattedScore)
    }

    @Test
    fun parsingNormalizesStylizedLeadingGlyphsInsideScoreRuns() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "b.264,010",
                    confidence = 0.63f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                )
            )
        )

        assertEquals(6_264_010L, candidate.first().normalizedScore)
        assertEquals("6,264,010", candidate.first().formattedScore)
    }

    @Test
    fun parsingRecoversLeadingEightFromGroupedLeadingZeroRuns() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "0,082.000",
                    confidence = 0.79f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                )
            )
        )

        assertEquals(8_082_000L, candidate.first().normalizedScore)
        assertEquals(7, candidate.first().digitCount)
    }

    @Test
    fun parsingRecoversLeadingSixFromGroupedLeadingZeroRuns() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "0.264.010",
                    confidence = 0.79f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                )
            )
        )

        assertEquals(6_264_010L, candidate.first().normalizedScore)
        assertEquals("6,264,010", candidate.first().formattedScore)
    }

    @Test
    fun parsingRecoversMissingLeadingSixFromLeadingSeparatorRun() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = ".264.010",
                    confidence = 0.79f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                )
            )
        )

        assertEquals(6_264_010L, candidate.first().normalizedScore)
        assertEquals("6,264,010", candidate.first().formattedScore)
    }

    @Test
    fun parsingRecoversMissingLeadingEightFromLeadingSeparatorRun() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = ".082.060",
                    confidence = 0.79f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                )
            )
        )

        assertEquals(8_082_060L, candidate.first().normalizedScore)
        assertEquals("8,082,060", candidate.first().formattedScore)
    }

    @Test
    fun parsingRecoversLeadingSevenFromGroupedLeadingOneRuns() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "1.082.060",
                    confidence = 0.79f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                )
            )
        )

        assertEquals(7_082_060L, candidate.first().normalizedScore)
        assertEquals("7,082,060", candidate.first().formattedScore)
    }

    @Test
    fun parsingRecoversZeroHeavyGroupedRunBackToStylizedEightAndSix() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "0.002.000",
                    confidence = 0.74f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                )
            )
        )

        assertEquals(8_082_060L, candidate.first().normalizedScore)
        assertEquals("8,082,060", candidate.first().formattedScore)
    }

    @Test
    fun parsingKeepsLegitimateZeroHeavyGroupedScore() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "2.004.050",
                    confidence = 0.74f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                )
            )
        )

        assertEquals(2_004_050L, candidate.first().normalizedScore)
        assertEquals("2,004,050", candidate.first().formattedScore)
    }

    @Test
    fun parsingPrefersRecoveredFullLengthCandidateOverNoisyRead() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "0.082.060",
                    confidence = 0.93f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                ),
                ScoreOcrObservation(
                    text = "8.082.060",
                    confidence = 0.58f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                ),
            )
        )

        assertEquals(8_082_060L, candidate.first().normalizedScore)
        assertEquals("8.082.060", candidate.first().rawText)
        assertEquals("8,082,060", candidate.first().formattedScore)
    }

    @Test
    fun parsingPrefersExactGroupedCandidateOverRecoveredLeadingEightVariant() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "0.082.060",
                    confidence = 0.93f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                ),
                ScoreOcrObservation(
                    text = "8.082.060",
                    confidence = 0.58f,
                    boundingBox = RectF(0.48f, 0.42f, 0.72f, 0.56f),
                ),
            )
        )

        assertEquals(8_082_060L, candidate.first().normalizedScore)
        assertEquals("8.082.060", candidate.first().rawText)
        assertEquals("8,082,060", candidate.first().formattedScore)
    }

    @Test
    fun parsingPrefersLongerPlausibleCandidateBeforeCenterBias() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "1234567",
                    confidence = 0.92f,
                    boundingBox = RectF(0.02f, 0.10f, 0.26f, 0.24f),
                ),
                ScoreOcrObservation(
                    text = "123456",
                    confidence = 0.70f,
                    boundingBox = RectF(0.38f, 0.42f, 0.62f, 0.56f),
                ),
            )
        )

        assertEquals(1_234_567L, candidate.first().normalizedScore)
    }

    @Test
    fun parsingExtractsScoreFromMixedOcrText() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "SCORE 12,450,000 BALL 2",
                    confidence = 0.68f,
                    boundingBox = RectF(0.44f, 0.38f, 0.72f, 0.54f),
                )
            )
        )

        assertEquals(12_450_000L, candidate.first().normalizedScore)
        assertEquals("12,450,000", candidate.first().formattedScore)
    }

    @Test
    fun parsingPrefersLongerScoreOverTinyCenteredFragmentWhenGapIsLarge() {
        val candidate = ScoreScannerParsingService.rankedCandidates(
            observations = listOf(
                ScoreOcrObservation(
                    text = "65",
                    confidence = 0.90f,
                    boundingBox = RectF(0.45f, 0.42f, 0.55f, 0.58f),
                ),
                ScoreOcrObservation(
                    text = "650,781,260",
                    confidence = 0.64f,
                    boundingBox = RectF(0.22f, 0.38f, 0.76f, 0.54f),
                ),
            )
        )

        assertEquals(650_781_260L, candidate.first().normalizedScore)
    }

    @Test
    fun parsingSupportsLargeScoresAndPreservesZeroInputForManualCorrection() {
        assertEquals(9_876_543_210L, ScoreScannerParsingService.normalizedScore("9,876,543,210"))
        assertEquals("9,876,543,210", ScoreScannerParsingService.formattedScoreInput("9876543210"))
        assertEquals("0", ScoreScannerParsingService.formattedScoreInput("0"))
        assertNull(ScoreScannerParsingService.normalizedScore("0"))
    }

    @Test
    fun stabilityLocksAfterRepeatedConsensus() {
        val service = ScoreScannerStabilityService()
        val candidate = ScoreScannerCandidate(
            rawText = "12,450,000",
            normalizedScore = 12_450_000L,
            formattedScore = "12,450,000",
            confidence = 0.56f,
            boundingBox = RectF(0.4f, 0.4f, 0.6f, 0.5f),
            digitCount = 8,
            centerBias = 0.95,
        )

        service.ingest(candidate)
        service.ingest(candidate)
        val snapshot = service.ingest(candidate)

        assertEquals(ScoreScannerStatus.Locked, snapshot.state)
        assertEquals(12_450_000L, snapshot.dominantReading?.score)
    }

    @Test
    fun stabilityPrefersLongerDominantScoreWhenOccurrenceGapIsSmall() {
        val service = ScoreScannerStabilityService()
        val shortCandidate = ScoreScannerCandidate(
            rawText = "123,456",
            normalizedScore = 123_456L,
            formattedScore = "123,456",
            confidence = 0.72f,
            boundingBox = RectF(0.4f, 0.4f, 0.6f, 0.5f),
            digitCount = 6,
            centerBias = 0.95,
        )
        val longCandidate = ScoreScannerCandidate(
            rawText = "1,234,567",
            normalizedScore = 1_234_567L,
            formattedScore = "1,234,567",
            confidence = 0.58f,
            boundingBox = RectF(0.4f, 0.4f, 0.6f, 0.5f),
            digitCount = 7,
            centerBias = 0.9,
        )

        service.ingest(shortCandidate)
        service.ingest(shortCandidate)
        service.ingest(longCandidate)
        val snapshot = service.ingest(longCandidate)

        assertEquals(ScoreScannerStatus.StableCandidate, snapshot.state)
        assertEquals(1_234_567L, snapshot.dominantReading?.score)
    }

    @Test
    fun frameMapperMapsTargetRectWhenPreviewMatchesFrameAspectRatio() {
        val cropRect = ScoreScannerFrameMapper.cropRect(
            frameSize = Size(100f, 200f),
            previewMapping = ScoreScannerPreviewMapping(
                previewBounds = RectF(0f, 0f, 50f, 100f),
                targetRect = RectF(10f, 20f, 40f, 30f),
            ),
        )

        assertEquals(RectF(20f, 140f, 80f, 160f), cropRect)
    }

    @Test
    fun frameMapperAccountsForAspectFillCropping() {
        val cropRect = ScoreScannerFrameMapper.cropRect(
            frameSize = Size(100f, 200f),
            previewMapping = ScoreScannerPreviewMapping(
                previewBounds = RectF(0f, 0f, 50f, 200f),
                targetRect = RectF(5f, 50f, 45f, 70f),
            ),
        )

        assertEquals(RectF(30f, 130f, 70f, 150f), cropRect)
    }

    @Test
    fun frameMapper_mapsPreviewTargetIntoPortraitFrame() {
        val cropRect = ScoreScannerFrameMapper.cropRect(
            frameSize = Size(720f, 1280f),
            previewMapping = ScoreScannerPreviewMapping(
                previewBounds = RectF(0f, 0f, 960f, 1800f),
                targetRect = RectF(120f, 500f, 840f, 620f),
            ),
        )

        assertNotNull(cropRect)
        cropRect!!
        assertTrue(cropRect.width() > 0f)
        assertTrue(cropRect.height() > 0f)
        assertTrue(cropRect.top >= 0f)
        assertTrue(cropRect.bottom <= 1280f)
    }
}
