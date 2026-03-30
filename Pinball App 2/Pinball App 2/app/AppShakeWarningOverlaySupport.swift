import SwiftUI
import UIKit

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
        _image = State(initialValue: AppShakeProfessorArtProvider.cachedImage(for: level))
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
            if let local = await AppShakeProfessorArtProvider.loadImage(for: level) {
                image = local
                return
            }

            image = await AppShakeProfessorArtProvider.loadFallbackImage()
        }
    }
}

private enum AppShakeProfessorArtProvider {
    private static let fallbackPath = libraryMissingArtworkPath
    private static let dataCache = NSCache<NSString, NSData>()
    private static let fallbackCacheKey = "__app_shake_fallback__" as NSString

    static func cachedImage(for level: AppShakeWarningLevel) -> UIImage? {
        image(forCacheKey: level.bundledArtFileName as NSString)
    }

    static func loadImage(for level: AppShakeWarningLevel) async -> UIImage? {
        let cacheKey = level.bundledArtFileName as NSString
        if let image = image(forCacheKey: cacheKey) {
            return image
        }

        guard let url = bundledURL(named: level.bundledArtFileName),
              let data = await loadData(from: url) else {
            return nil
        }

        dataCache.setObject(data as NSData, forKey: cacheKey)
        return UIImage(data: data)
    }

    static func loadFallbackImage() async -> UIImage? {
        if let image = image(forCacheKey: fallbackCacheKey) {
            return image
        }

        let path = fallbackPath
        let data = await Task.detached(priority: .utility) {
            try? loadCachedPinballData(path: path)
        }.value
        guard let data else {
            return nil
        }

        dataCache.setObject(data as NSData, forKey: fallbackCacheKey)
        return UIImage(data: data)
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

    private static func image(forCacheKey key: NSString) -> UIImage? {
        guard let data = dataCache.object(forKey: key) else { return nil }
        return UIImage(data: data as Data)
    }

    private static func loadData(from url: URL) async -> Data? {
        await Task.detached(priority: .utility) {
            try? Data(contentsOf: url)
        }.value
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
