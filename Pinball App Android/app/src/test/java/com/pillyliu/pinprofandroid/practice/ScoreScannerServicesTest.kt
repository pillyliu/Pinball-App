package com.pillyliu.pinprofandroid.practice

import android.graphics.RectF
import androidx.compose.ui.geometry.Size
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class ScoreScannerServicesTest {

    @Test
    fun parsingService_formatsAndRanksNumericCandidates() {
        val ranked = ScoreScannerParsingService.rankedCandidates(
            listOf(
                ScoreOcrObservation(
                    text = "555,555,555",
                    confidence = 1f,
                    boundingBox = RectF(0.20f, 0.25f, 0.78f, 0.60f),
                ),
                ScoreOcrObservation(
                    text = "55",
                    confidence = 1f,
                    boundingBox = RectF(0.10f, 0.10f, 0.18f, 0.18f),
                ),
            )
        )

        assertTrue(ranked.isNotEmpty())
        assertEquals(555_555_555, ranked.first().normalizedScore)
        assertEquals("555,555,555", ranked.first().formattedScore)
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

    @Test
    fun scoreInputFormatter_stripsNoise() {
        assertEquals("1,234,567", ScoreScannerParsingService.formattedScoreInput("12a34,567"))
        assertEquals(9_999, ScoreScannerParsingService.normalizedScore("9,999"))
    }
}
