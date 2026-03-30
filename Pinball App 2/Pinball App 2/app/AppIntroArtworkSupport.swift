import SwiftUI
import UIKit

struct AppIntroArtworkFrame: View {
    let card: AppIntroCard

    var body: some View {
        Color.clear
            .aspectRatio(card.artworkAspectRatio, contentMode: .fit)
            .overlay {
                AppIntroArtworkBox(card: card)
            }
    }
}

struct AppIntroArtworkBox: View {
    let card: AppIntroCard

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        ZStack {
            shape
                .fill(AppTheme.atmosphereBottom.opacity(0.99))
                .overlay(
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppIntroTheme.tint.opacity(0.26),
                                    Color.black.opacity(0.14),
                                    AppTheme.brandGold.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            Group {
                if card == .welcome {
                    AppIntroWelcomeArtwork()
                } else {
                    AppIntroScreenshotArtwork(
                        bundledFileName: card.bundledArtworkFileName,
                        accent: card.accent
                    )
                }
            }
        }
        .clipShape(shape)
        .overlay(
            shape
                .stroke(card.accent.opacity(0.72), lineWidth: 1.15)
        )
        .shadow(color: AppIntroTheme.tint.opacity(0.22), radius: 16, y: 8)
    }
}

private struct AppIntroWelcomeArtwork: View {
    var body: some View {
        Group {
            if let image = AppIntroBundledArtProvider.image(named: AppIntroCard.welcome.bundledArtworkFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

private struct AppIntroScreenshotArtwork: View {
    let bundledFileName: String
    let accent: Color

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [accent.opacity(0.18), .clear],
                center: .center,
                startRadius: 14,
                endRadius: 240
            )

            if let image = AppIntroBundledArtProvider.image(named: bundledFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .shadow(color: accent.opacity(0.16), radius: 16, y: 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AppIntroProfessorSpotlight: View {
    let side: AppIntroProfessorSide

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppIntroTheme.glow.opacity(0.34),
                            AppIntroTheme.tint.opacity(0.20),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 54
                    )
                )
                .frame(width: 82, height: 82)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 72, height: 72)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .overlay {
                    if let image = AppIntroBundledArtProvider.image(named: "professor-headshot.webp") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .scaleEffect(x: side == .left ? -1 : 1, y: 1)
                            .offset(y: -2)
                            .clipShape(Circle())
                    }
                }
        }
        .frame(width: 82, height: 82)
    }
}

enum AppIntroBundledArtProvider {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(named fileName: String) -> UIImage? {
        let cacheKey = fileName as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        guard let url = bundledURL(named: fileName),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            NSLog("Missing bundled intro artwork: %@", fileName)
            return nil
        }

        cache.setObject(image, forKey: cacheKey)
        return image
    }

    private static func bundledURL(named fileName: String) -> URL? {
        if let rootURL = Bundle.main.url(forResource: fileName, withExtension: nil) {
            return rootURL
        }
        return Bundle.main.url(
            forResource: fileName,
            withExtension: nil,
            subdirectory: "SharedAppSupport/app-intro"
        )
    }
}
