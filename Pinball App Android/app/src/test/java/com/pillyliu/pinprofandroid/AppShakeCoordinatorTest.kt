package com.pillyliu.pinprofandroid

import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AppShakeCoordinatorTest {
    @Test
    fun motionTuningMatchesParitySpec() {
        assertEquals(30, AppShakeMotionTuning.sampleRateHz)
        assertEquals(850L, AppShakeMotionTuning.minimumAcceptedShakeIntervalMillis)
        assertEquals(180L, AppShakeMotionTuning.candidateWindowMillis)
        assertEquals(2.45f, AppShakeMotionTuning.strongMagnitudeThreshold)
        assertEquals(1.85f, AppShakeMotionTuning.combinedMagnitudeThreshold)
        assertEquals(1.35f, AppShakeMotionTuning.combinedPeakAxisThreshold)
    }

    @Test
    fun warningLevelsMatchParitySpec() {
        assertEquals("DANGER", AppShakeWarningLevel.Danger.title)
        assertEquals("A little restraint, if you please.", AppShakeWarningLevel.Danger.subtitle)
        assertEquals(3_000L, AppShakeWarningLevel.Danger.displayDurationMillis)
        assertEquals(50L, AppShakeWarningLevel.Danger.hapticStartDelayMillis)
        assertEquals(
            "shake-warnings/professor-danger_1024.webp",
            AppShakeWarningLevel.Danger.bundledArtAssetPath,
        )

        assertEquals("DANGER DANGER", AppShakeWarningLevel.DoubleDanger.title)
        assertEquals("Really, this is most uncivilised shaking.", AppShakeWarningLevel.DoubleDanger.subtitle)
        assertEquals(3_500L, AppShakeWarningLevel.DoubleDanger.displayDurationMillis)
        assertEquals(200L, AppShakeWarningLevel.DoubleDanger.hapticStartDelayMillis)
        assertEquals(
            "shake-warnings/professor-danger-danger_1024.webp",
            AppShakeWarningLevel.DoubleDanger.bundledArtAssetPath,
        )

        assertEquals("TILT", AppShakeWarningLevel.Tilt.title)
        assertEquals(
            "That is quite enough! I will not tolerate any further indignity in this cabinet of higher learning.",
            AppShakeWarningLevel.Tilt.subtitle,
        )
        assertEquals(4_500L, AppShakeWarningLevel.Tilt.displayDurationMillis)
        assertEquals(200L, AppShakeWarningLevel.Tilt.hapticStartDelayMillis)
        assertEquals(
            "shake-warnings/professor-tilt_1024.webp",
            AppShakeWarningLevel.Tilt.bundledArtAssetPath,
        )
    }

    @Test
    fun shakeStaysQuietWhenNativeUndoWouldHandleIt() {
        val coordinator = AppShakeCoordinator(
            nativeUndoAvailabilityProvider = { true },
            hapticsPlayer = {},
            dispatcher = Dispatchers.Unconfined,
        )

        try {
            coordinator.handleDetectedShake()

            assertNull(coordinator.overlayLevel)
        } finally {
            coordinator.dispose()
        }
    }

    @Test
    fun fallbackShakesEscalateToTiltAcrossSeparateShakes() {
        val coordinator = AppShakeCoordinator(
            nativeUndoAvailabilityProvider = { false },
            hapticsPlayer = {},
            dispatcher = Dispatchers.Unconfined,
        )

        try {
            coordinator.handleDetectedShake()
            assertEquals(AppShakeWarningLevel.Danger, coordinator.overlayLevel)

            coordinator.handleDetectedShake()
            assertEquals(AppShakeWarningLevel.DoubleDanger, coordinator.overlayLevel)

            coordinator.handleDetectedShake()
            assertEquals(AppShakeWarningLevel.Tilt, coordinator.overlayLevel)
        } finally {
            coordinator.dispose()
        }
    }

    @Test
    fun nativeUndoDoesNotResetEscalationProgress() {
        var nativeUndoAvailable = false
        val coordinator = AppShakeCoordinator(
            nativeUndoAvailabilityProvider = { nativeUndoAvailable },
            hapticsPlayer = {},
            dispatcher = Dispatchers.Unconfined,
        )

        try {
            coordinator.handleDetectedShake()
            assertEquals(AppShakeWarningLevel.Danger, coordinator.overlayLevel)

            nativeUndoAvailable = true
            coordinator.handleDetectedShake()
            assertEquals(AppShakeWarningLevel.Danger, coordinator.overlayLevel)

            nativeUndoAvailable = false
            coordinator.handleDetectedShake()
            assertEquals(AppShakeWarningLevel.DoubleDanger, coordinator.overlayLevel)
        } finally {
            coordinator.dispose()
        }
    }

    @Test
    fun fallbackShakesTriggerEscalatingHaptics() {
        val playedLevels = mutableListOf<AppShakeWarningLevel>()
        val coordinator = AppShakeCoordinator(
            nativeUndoAvailabilityProvider = { false },
            hapticsPlayer = { playedLevels += it },
            dispatcher = Dispatchers.Unconfined,
        )

        try {
            coordinator.handleDetectedShake()
            coordinator.handleDetectedShake()
            coordinator.handleDetectedShake()

            assertEquals(
                listOf(
                    AppShakeWarningLevel.Danger,
                    AppShakeWarningLevel.DoubleDanger,
                    AppShakeWarningLevel.Tilt,
                ),
                playedLevels,
            )
        } finally {
            coordinator.dispose()
        }
    }

    @Test
    fun hapticFailuresDoNotPreventOverlayPresentation() {
        val coordinator = AppShakeCoordinator(
            nativeUndoAvailabilityProvider = { false },
            hapticsPlayer = { throw SecurityException("Requires VIBRATE permission") },
            dispatcher = Dispatchers.Unconfined,
        )

        try {
            coordinator.handleDetectedShake()

            assertEquals(AppShakeWarningLevel.Danger, coordinator.overlayLevel)
        } finally {
            coordinator.dispose()
        }
    }

    @Test
    fun tiltIgnoresAdditionalShakesUntilItDismisses() {
        val playedLevels = mutableListOf<AppShakeWarningLevel>()
        val coordinator = AppShakeCoordinator(
            nativeUndoAvailabilityProvider = { false },
            hapticsPlayer = { playedLevels += it },
            dispatcher = Dispatchers.Unconfined,
        )

        try {
            coordinator.handleDetectedShake()
            coordinator.handleDetectedShake()
            coordinator.handleDetectedShake()
            coordinator.handleDetectedShake()

            assertEquals(AppShakeWarningLevel.Tilt, coordinator.overlayLevel)
            assertEquals(
                listOf(
                    AppShakeWarningLevel.Danger,
                    AppShakeWarningLevel.DoubleDanger,
                    AppShakeWarningLevel.Tilt,
                ),
                playedLevels,
            )
        } finally {
            coordinator.dispose()
        }
    }
}
