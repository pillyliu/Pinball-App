import SwiftUI
import UIKit
import Combine
import CoreHaptics

enum AppShakeWarningLevel: Int {
    case danger = 1
    case doubleDanger = 2
    case tilt = 3

    var title: String {
        switch self {
        case .danger:
            return "DANGER"
        case .doubleDanger:
            return "DANGER DANGER"
        case .tilt:
            return "TILT"
        }
    }

    var subtitle: String {
        switch self {
        case .danger:
            return "A little restraint, if you please."
        case .doubleDanger:
            return "Really, this is most uncivilised shaking."
        case .tilt:
            return "That is quite enough! I will not tolerate any further indignity in this cabinet of higher learning."
        }
    }

    var artAssetName: String {
        switch self {
        case .danger:
            return "ProfessorShakeDanger"
        case .doubleDanger:
            return "ProfessorShakeDoubleDanger"
        case .tilt:
            return "ProfessorShakeTilt"
        }
    }

    var bundledArtFileName: String {
        switch self {
        case .danger:
            return "professor-danger_1024.webp"
        case .doubleDanger:
            return "professor-danger-danger_1024.webp"
        case .tilt:
            return "professor-tilt_1024.webp"
        }
    }

    var tint: Color {
        switch self {
        case .danger:
            return Color(red: 1.00, green: 0.62, blue: 0.18)
        case .doubleDanger:
            return Color(red: 1.00, green: 0.34, blue: 0.16)
        case .tilt:
            return Color(red: 1.00, green: 0.14, blue: 0.14)
        }
    }

    var glow: Color {
        switch self {
        case .danger:
            return Color(red: 1.00, green: 0.82, blue: 0.36)
        case .doubleDanger:
            return Color(red: 1.00, green: 0.52, blue: 0.18)
        case .tilt:
            return Color(red: 1.00, green: 0.28, blue: 0.18)
        }
    }

    var displayDurationNanoseconds: UInt64 {
        switch self {
        case .danger:
            return 3_000_000_000
        case .doubleDanger:
            return 3_500_000_000
        case .tilt:
            return 4_500_000_000
        }
    }

    var hapticStartDelayNanoseconds: UInt64 {
        switch self {
        case .danger:
            return 50_000_000
        case .doubleDanger, .tilt:
            return 200_000_000
        }
    }
}

@MainActor
final class AppShakeCoordinator: ObservableObject {
    @Published private(set) var overlayLevel: AppShakeWarningLevel?

    private let nativeUndoAvailabilityProvider: () -> Bool
    private let hapticsPlayer: (AppShakeWarningLevel) -> Void
    private var fallbackShakeCount = 0
    private var overlayToken = 0

    init() {
        self.nativeUndoAvailabilityProvider = { AppShakeCoordinator.nativeUndoWouldHandleShake() }
        self.hapticsPlayer = { AppShakeWarningHaptics.play($0) }
    }

    init(
        nativeUndoAvailabilityProvider: @escaping () -> Bool,
        hapticsPlayer: @escaping (AppShakeWarningLevel) -> Void
    ) {
        self.nativeUndoAvailabilityProvider = nativeUndoAvailabilityProvider
        self.hapticsPlayer = hapticsPlayer
    }

    nonisolated deinit {}

    func handleDetectedShake() {
        guard !nativeUndoAvailabilityProvider() else {
            return
        }
        guard overlayLevel != .tilt else { return }

        fallbackShakeCount = min(fallbackShakeCount + 1, AppShakeWarningLevel.tilt.rawValue)
        let level = AppShakeWarningLevel(rawValue: fallbackShakeCount) ?? .danger
        if level == .tilt {
            fallbackShakeCount = 0
        }
        present(level)
    }

    private func present(_ level: AppShakeWarningLevel) {
        overlayToken += 1
        let currentToken = overlayToken
        hapticsPlayer(level)
        withAnimation(.easeInOut(duration: 0.18)) {
            overlayLevel = level
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: level.displayDurationNanoseconds)
            guard let self else { return }
            guard currentToken == self.overlayToken else { return }
            withAnimation(.easeOut(duration: 0.30)) {
                self.overlayLevel = nil
            }
        }
    }

    private static func nativeUndoWouldHandleShake() -> Bool {
        guard UIApplication.shared.applicationSupportsShakeToEdit else { return false }

        if let responder = UIResponder.currentFirstResponder,
           responder.undoManager?.canUndo == true || responder.undoManager?.canRedo == true {
            return true
        }

        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)

        let undoManagers: [UndoManager?] = [
            keyWindow?.undoManager,
            keyWindow?.rootViewController?.undoManager
        ]
        return undoManagers.contains { manager in
            manager?.canUndo == true || manager?.canRedo == true
        }
    }
}

@MainActor
private enum AppShakeWarningHaptics {
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

struct AppShakeWarningOverlay: View {
    let level: AppShakeWarningLevel

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let outerHorizontalPadding: CGFloat = 28
            let outerVerticalPadding: CGFloat = 24
            let cardHorizontalPadding: CGFloat = isLandscape ? 22 : 28
            let cardVerticalPadding: CGFloat = isLandscape ? 20 : 24
            let landscapeSpacing: CGFloat = 20
            let maxLandscapeCardWidth = min(proxy.size.width - (outerHorizontalPadding * 2), 760)
            let maxLandscapeCardHeight = min(proxy.size.height - (outerVerticalPadding * 2), 340)
            let landscapePaneWidth = min(
                (maxLandscapeCardWidth - (cardHorizontalPadding * 2) - landscapeSpacing) / 2,
                maxLandscapeCardHeight - (cardVerticalPadding * 2)
            )
            let landscapeCardWidth = (landscapePaneWidth * 2) + landscapeSpacing + (cardHorizontalPadding * 2)
            let landscapeCardHeight = landscapePaneWidth + (cardVerticalPadding * 2)
            let portraitCardWidth = min(max(proxy.size.width - (outerHorizontalPadding * 2), 280), 420)
            let portraitImageSide = min(portraitCardWidth - (cardHorizontalPadding * 2), 360)

            ZStack {
                LinearGradient(
                    colors: [
                        level.tint.opacity(level == .tilt ? 0.32 : 0.20),
                        Color.black.opacity(level == .tilt ? 0.58 : 0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Group {
                    if isLandscape {
                        HStack(alignment: .center, spacing: landscapeSpacing) {
                            AppShakeProfessorArt(level: level, boxSide: landscapePaneWidth)
                                .frame(width: landscapePaneWidth, height: landscapePaneWidth)

                            warningCopy(isLandscape: true)
                                .frame(width: landscapePaneWidth, height: landscapePaneWidth, alignment: .center)
                        }
                    } else {
                        VStack(spacing: 18) {
                            AppShakeProfessorArt(level: level, boxSide: portraitImageSide)

                            warningCopy(isLandscape: false)
                        }
                    }
                }
                .frame(
                    maxWidth: isLandscape ? landscapeCardWidth : portraitCardWidth,
                    maxHeight: isLandscape ? landscapeCardHeight : nil
                )
                .padding(.horizontal, cardHorizontalPadding)
                .padding(.vertical, cardVerticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [level.glow.opacity(0.34), .clear, level.tint.opacity(0.22)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(level.glow.opacity(0.78), lineWidth: 1.2)
                        )
                )
                .shadow(color: level.tint.opacity(0.35), radius: 28, y: 12)
                .padding(.horizontal, outerHorizontalPadding)
                .padding(.vertical, outerVerticalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func warningCopy(isLandscape: Bool) -> some View {
        VStack(alignment: isLandscape ? .leading : .center, spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<AppShakeWarningLevel.tilt.rawValue, id: \.self) { index in
                    Capsule()
                        .fill(index < level.rawValue ? level.glow : Color.white.opacity(0.14))
                        .frame(width: isLandscape ? 44 : 52, height: 8)
                }
            }
            VStack(alignment: isLandscape ? .leading : .center, spacing: 8) {
                Text(level.title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(level.glow)

                Text(level.subtitle)
                    .font(.appShakeProfessorSubtitle(size: 17))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .multilineTextAlignment(isLandscape ? .leading : .center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: isLandscape ? nil : .infinity, maxHeight: isLandscape ? .infinity : nil, alignment: .center)
    }
}

private struct AppShakeProfessorArt: View {
    let level: AppShakeWarningLevel
    let boxSide: CGFloat
    @State private var image: UIImage?

    init(level: AppShakeWarningLevel, boxSide: CGFloat) {
        self.level = level
        self.boxSide = boxSide
        _image = State(initialValue: AppShakeProfessorArtProvider.localImage(for: level))
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        ZStack {
            shape
                .fill(AppTheme.atmosphereBottom.opacity(0.96))

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    AppShakeProfessorEmergencyPlaceholder(level: level)
                        .padding(14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(width: boxSide, height: boxSide)
        .clipShape(shape)
        .overlay(
            shape
                .stroke(level.glow.opacity(0.72), lineWidth: 1.2)
        )
        .shadow(color: level.tint.opacity(0.24), radius: 18, y: 8)
        .task(id: level.rawValue) {
            if let local = AppShakeProfessorArtProvider.localImage(for: level) {
                image = local
                return
            }

            image = AppShakeProfessorArtProvider.bundledFallbackImage
        }
    }
}

private enum AppShakeProfessorArtProvider {
    private static let fallbackPath = libraryMissingArtworkPath

    static let bundledFallbackImage: UIImage? = {
        guard let data = try? loadCachedPinballData(path: fallbackPath) else { return nil }
        return UIImage(data: data)
    }()

    static func localImage(for level: AppShakeWarningLevel) -> UIImage? {
        guard let url = bundledURL(named: level.bundledArtFileName),
        let data = try? Data(contentsOf: url),
        let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    private static func bundledURL(named fileName: String) -> URL? {
        if let rootURL = Bundle.main.url(forResource: fileName, withExtension: nil) {
            return rootURL
        }
        return Bundle.main.url(
            forResource: fileName,
            withExtension: nil,
            subdirectory: "SharedAppSupport/shake-warnings"
        )
    }
}

private extension Font {
    static func appShakeProfessorSubtitle(size: CGFloat) -> Font {
        let preferredNames = [
            "Baskerville-SemiBoldItalic",
            "Baskerville-Italic",
            "TimesNewRomanPS-ItalicMT"
        ]

        if let fontName = preferredNames.first(where: { UIFont(name: $0, size: size) != nil }) {
            return .custom(fontName, size: size, relativeTo: .body)
        }

        return .system(size: size, weight: .semibold, design: .serif).italic()
    }
}

private struct AppShakeProfessorEmergencyPlaceholder: View {
    let level: AppShakeWarningLevel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.76),
                    level.tint.opacity(0.18),
                    AppTheme.brandInk.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 14) {
                Spacer(minLength: 0)

                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(level.glow.opacity(0.94))

                VStack(spacing: 6) {
                    PinballMediaPreviewPlaceholder(message: "Sorry, no image available")
                        .frame(maxWidth: 220)
                }

                Spacer(minLength: 0)

                Text("Drop artwork into asset: \(level.artAssetName)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.bottom, 14)
            }
            .padding(16)
        }
    }
}

private extension UIResponder {
    static weak var storedFirstResponder: UIResponder?

    static var currentFirstResponder: UIResponder? {
        storedFirstResponder = nil
        UIApplication.shared.sendAction(#selector(captureFirstResponder), to: nil, from: nil, for: nil)
        return storedFirstResponder
    }

    @objc
    func captureFirstResponder() {
        UIResponder.storedFirstResponder = self
    }
}
