import XCTest
@testable import PinProf

@MainActor
final class AppShakeCoordinatorTests: XCTestCase {
    func testMotionTuningMatchesSharedParitySpec() {
        XCTAssertEqual(AppShakeMotionTuning.updateInterval, 1.0 / 30.0, accuracy: 0.000_1)
        XCTAssertEqual(AppShakeMotionTuning.minimumAcceptedShakeInterval, 0.85, accuracy: 0.000_1)
        XCTAssertEqual(AppShakeMotionTuning.candidateWindow, 0.18, accuracy: 0.000_1)
        XCTAssertEqual(AppShakeMotionTuning.strongMagnitudeThreshold, 2.45, accuracy: 0.000_1)
        XCTAssertEqual(AppShakeMotionTuning.combinedMagnitudeThreshold, 1.85, accuracy: 0.000_1)
        XCTAssertEqual(AppShakeMotionTuning.combinedPeakAxisThreshold, 1.35, accuracy: 0.000_1)
    }

    func testWarningDurationsMatchEscalationTiming() {
        XCTAssertEqual(AppShakeWarningLevel.danger.displayDurationNanoseconds, 3_000_000_000)
        XCTAssertEqual(AppShakeWarningLevel.doubleDanger.displayDurationNanoseconds, 3_500_000_000)
        XCTAssertEqual(AppShakeWarningLevel.tilt.displayDurationNanoseconds, 4_500_000_000)
        XCTAssertEqual(AppShakeWarningLevel.danger.hapticStartDelayNanoseconds, 50_000_000)
        XCTAssertEqual(AppShakeWarningLevel.doubleDanger.hapticStartDelayNanoseconds, 200_000_000)
        XCTAssertEqual(AppShakeWarningLevel.tilt.hapticStartDelayNanoseconds, 200_000_000)
        XCTAssertEqual(AppShakeWarningLevel.danger.artAssetName, "ProfessorShakeDanger")
        XCTAssertEqual(AppShakeWarningLevel.doubleDanger.artAssetName, "ProfessorShakeDoubleDanger")
        XCTAssertEqual(AppShakeWarningLevel.tilt.artAssetName, "ProfessorShakeTilt")
        XCTAssertEqual(
            AppShakeWarningLevel.danger.bundledArtFileName,
            "professor-danger_1024.webp"
        )
        XCTAssertEqual(
            AppShakeWarningLevel.doubleDanger.bundledArtFileName,
            "professor-danger-danger_1024.webp"
        )
        XCTAssertEqual(
            AppShakeWarningLevel.tilt.bundledArtFileName,
            "professor-tilt_1024.webp"
        )
    }

    func testShakeStaysQuietWhenNativeUndoWouldHandleIt() {
        let coordinator = AppShakeCoordinator(
            nativeUndoAvailabilityProvider: { true },
            hapticsPlayer: { _ in }
        )

        coordinator.handleDetectedShake()

        XCTAssertNil(coordinator.overlayLevel)
    }

    func testFallbackShakesEscalateToTiltAcrossSeparateShakes() {
        let coordinator = AppShakeCoordinator(
            nativeUndoAvailabilityProvider: { false },
            hapticsPlayer: { _ in }
        )

        coordinator.handleDetectedShake()
        XCTAssertEqual(coordinator.overlayLevel, .danger)

        coordinator.handleDetectedShake()
        XCTAssertEqual(coordinator.overlayLevel, .doubleDanger)

        coordinator.handleDetectedShake()
        XCTAssertEqual(coordinator.overlayLevel, .tilt)
    }

    func testNativeUndoDoesNotResetEscalationProgress() {
        var nativeUndoAvailable = false
        let coordinator = AppShakeCoordinator(
            nativeUndoAvailabilityProvider: { nativeUndoAvailable },
            hapticsPlayer: { _ in }
        )

        coordinator.handleDetectedShake()
        XCTAssertEqual(coordinator.overlayLevel, .danger)

        nativeUndoAvailable = true
        coordinator.handleDetectedShake()

        nativeUndoAvailable = false
        coordinator.handleDetectedShake()
        XCTAssertEqual(coordinator.overlayLevel, .doubleDanger)
    }

    func testFallbackShakesTriggerEscalatingHaptics() {
        var playedLevels: [AppShakeWarningLevel] = []
        let coordinator = AppShakeCoordinator(
            nativeUndoAvailabilityProvider: { false },
            hapticsPlayer: { playedLevels.append($0) }
        )

        coordinator.handleDetectedShake()
        coordinator.handleDetectedShake()
        coordinator.handleDetectedShake()

        XCTAssertEqual(playedLevels, [.danger, .doubleDanger, .tilt])
    }
}
