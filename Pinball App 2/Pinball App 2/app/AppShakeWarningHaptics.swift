import UIKit
import CoreHaptics

@MainActor
enum AppShakeWarningHaptics {
    private static var engine: CHHapticEngine?
    private static var playbackTask: Task<Void, Never>?

    static func play(_ level: AppShakeWarningLevel) {
        playbackTask?.cancel()
        playbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: level.hapticStartDelayNanoseconds)
            guard !Task.isCancelled else { return }
            if playCoreHaptics(level) {
                return
            }
            await playUIKitFallback(level)
        }
    }

    private static func playCoreHaptics(_ level: AppShakeWarningLevel) -> Bool {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return false }

        do {
            let engine = try hapticEngine()
            let pattern = try CHHapticPattern(events: events(for: level), parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            engine = nil
            return false
        }
    }

    private static func hapticEngine() throws -> CHHapticEngine {
        if let engine {
            return engine
        }

        let createdEngine = try CHHapticEngine()
        createdEngine.isAutoShutdownEnabled = true
        createdEngine.resetHandler = {
            Task { @MainActor in
                engine = nil
            }
        }
        createdEngine.stoppedHandler = { _ in
            Task { @MainActor in
                engine = nil
            }
        }
        engine = createdEngine
        return createdEngine
    }

    private static func events(for level: AppShakeWarningLevel) -> [CHHapticEvent] {
        switch level {
        case .danger:
            return buzzEvents(
                count: 1,
                spacing: 0.0,
                intensity: 0.74,
                sharpness: 0.36,
                duration: 0.11
            )
        case .doubleDanger:
            return buzzEvents(
                count: 2,
                spacing: 0.17,
                intensity: 0.82,
                sharpness: 0.38,
                duration: 0.11
            )
        case .tilt:
            return buzzEvents(
                count: 3,
                spacing: 0.15,
                intensity: 1.0,
                sharpness: 0.45,
                duration: 0.14
            )
        }
    }

    private static func buzzEvents(
        count: Int,
        spacing: TimeInterval,
        intensity: Float,
        sharpness: Float,
        duration: TimeInterval
    ) -> [CHHapticEvent] {
        (0..<count).flatMap { index -> [CHHapticEvent] in
            let startTime = Double(index) * spacing
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: startTime
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: startTime,
                    duration: duration
                )
            ]
        }
    }

    private static func playUIKitFallback(_ level: AppShakeWarningLevel) async {
        switch level {
        case .danger:
            impact(style: .rigid, intensity: 1.0)
        case .doubleDanger:
            await impacts(style: .rigid, intensity: 1.0, count: 2, spacingNanoseconds: 170_000_000)
        case .tilt:
            await impacts(style: .heavy, intensity: 1.0, count: 3, spacingNanoseconds: 150_000_000)
        }
    }

    private static func impacts(
        style: UIImpactFeedbackGenerator.FeedbackStyle,
        intensity: CGFloat,
        count: Int,
        spacingNanoseconds: UInt64
    ) async {
        for index in 0..<count {
            guard !Task.isCancelled else { return }
            impact(style: style, intensity: intensity)
            guard index < count - 1 else { continue }
            try? await Task.sleep(nanoseconds: spacingNanoseconds)
        }
    }

    private static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }
}
