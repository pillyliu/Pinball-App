import SwiftUI
import UIKit

enum AppIntroProfessorSide {
    case left
    case right
}

enum AppIntroCard: Int, CaseIterable, Identifiable {
    case welcome
    case league
    case library
    case practice
    case gameroom
    case settings

    var id: Int { rawValue }

    var title: String? {
        switch self {
        case .welcome:
            return nil
        case .league:
            return "League"
        case .library:
            return "Library"
        case .practice:
            return "Practice"
        case .gameroom:
            return "GameRoom"
        case .settings:
            return "Settings"
        }
    }

    var subtitle: String? {
        switch self {
        case .welcome:
            return nil
        case .league:
            return "Lansing Pinball League stats"
        case .library:
            return "Rulesheets, playfields, tutorials"
        case .practice:
            return "Track practice, trends, progress"
        case .gameroom:
            return "Organize machines and upkeep"
        case .settings:
            return "Sources, venues, tournaments, data"
        }
    }

    var quote: String {
        switch self {
        case .welcome:
            return "Welcome to PinProf, a pinball study app. Go from pinball novice to pinball wizard in no time!"
        case .league:
            return "Among peers, statistics reveal true standing."
        case .library:
            return "Attend closely; mastery follows diligence."
        case .practice:
            return "A careful record reveals true progress."
        case .gameroom:
            return "Order and care are marks of excellence."
        case .settings:
            return "A well-curated library reflects discernment."
        }
    }

    var highlightedQuotePhrase: String? {
        switch self {
        case .welcome:
            return "PinProf"
        case .league, .library, .practice, .gameroom, .settings:
            return nil
        }
    }

    var accent: Color {
        switch self {
        case .welcome:
            return AppIntroTheme.glow
        case .league:
            return AppTheme.statsMeanMedian
        case .library:
            return Color(red: 0.56, green: 0.86, blue: 0.78)
        case .practice:
            return Color(red: 1.00, green: 0.86, blue: 0.40)
        case .gameroom:
            return Color(red: 0.96, green: 0.78, blue: 0.36)
        case .settings:
            return Color(red: 0.72, green: 0.90, blue: 0.76)
        }
    }

    var bundledArtworkFileName: String {
        switch self {
        case .welcome:
            return "launch-logo.webp"
        case .league:
            return "league-screenshot.webp"
        case .library:
            return "library-screenshot.webp"
        case .practice:
            return "practice-screenshot.webp"
        case .gameroom:
            return "gameroom-screenshot.webp"
        case .settings:
            return "settings-screenshot.webp"
        }
    }

    var artworkAspectRatio: CGFloat {
        switch self {
        case .welcome:
            return 1.0
        case .league, .library, .practice, .gameroom, .settings:
            return 1206.0 / 1809.0
        }
    }

    var showsProfessorSpotlight: Bool {
        self != .welcome
    }

    var professorSide: AppIntroProfessorSide {
        switch self {
        case .welcome, .league, .practice, .settings:
            return .left
        case .library, .gameroom:
            return .right
        }
    }
}

enum AppIntroTheme {
    static let tint = Color(red: 0.12, green: 0.34, blue: 0.26)
    static let glow = Color(red: 0.64, green: 0.88, blue: 0.74)
    static let text = Color.white.opacity(0.96)
    static let secondaryText = Color.white.opacity(0.84)
}

struct AppIntroOverlay: View {
    static let currentVersion = 1

    let onDismiss: () -> Void

    @State private var selectedIndex = 0

    private let cards = AppIntroCard.allCases
    private var showsDismissButton: Bool { selectedIndex == cards.count - 1 }
    private var bottomAccessoryHeight: CGFloat { showsDismissButton ? 88 : 26 }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let horizontalPadding: CGFloat = isLandscape ? 28 : 22
            let verticalPadding: CGFloat = isLandscape ? 18 : 20
            let cardMaxWidth = min(proxy.size.width - (horizontalPadding * 2), isLandscape ? 960 : 460)

            ZStack {
                AppIntroBackdrop()

                TabView(selection: $selectedIndex) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        AppIntroDeckPage(
                            card: card,
                            isLandscape: isLandscape,
                            bottomAccessoryHeight: bottomAccessoryHeight
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: cardMaxWidth)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    VStack(spacing: 12) {
                        AppIntroPageIndicators(
                            count: cards.count,
                            selectedIndex: selectedIndex
                        )

                        if showsDismissButton {
                            Button("Start Exploring") {
                                withAnimation(.easeOut(duration: 0.26)) {
                                    onDismiss()
                                }
                            }
                            .buttonStyle(AppPrimaryActionButtonStyle(fillsWidth: true))
                        }
                    }
                    .frame(maxWidth: cardMaxWidth)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, isLandscape ? 8 : 14)
                }
            }
        }
        .transition(.opacity)
    }
}

private struct AppIntroDeckPage: View {
    let card: AppIntroCard
    let isLandscape: Bool
    let bottomAccessoryHeight: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if card == .welcome {
                        Spacer(minLength: 0)
                    }

                    AppIntroCardView(card: card, isLandscape: isLandscape)
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)

                    if card == .welcome {
                        Spacer(minLength: 0)
                    }
                }
                .frame(
                    minHeight: max(0, proxy.size.height - bottomAccessoryHeight - 8),
                    alignment: card == .welcome ? .center : .top
                )
                .padding(.bottom, bottomAccessoryHeight + 12)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct AppIntroBackdrop: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.64)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    AppIntroTheme.tint.opacity(0.82),
                    Color.black.opacity(0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [AppIntroTheme.glow.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: 340
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [AppTheme.brandGold.opacity(0.14), .clear],
                center: .bottomTrailing,
                startRadius: 24,
                endRadius: 320
            )
            .ignoresSafeArea()
        }
    }
}

private struct AppIntroCardView: View {
    let card: AppIntroCard
    let isLandscape: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        Group {
            if isLandscape {
                HStack(alignment: .top, spacing: 18) {
                    AppIntroArtworkFrame(card: card)
                        .frame(width: 322)

                    AppIntroCopyColumn(card: card, isLandscape: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    AppIntroArtworkFrame(card: card)

                    AppIntroCopyColumn(card: card, isLandscape: false)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            shape
                .fill(Color.black.opacity(0.76))
                .overlay(
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppIntroTheme.tint.opacity(0.30),
                                    AppTheme.atmosphereBottom.opacity(0.12),
                                    AppTheme.brandGold.opacity(0.11)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    shape
                        .stroke(Color.white.opacity(0.18), lineWidth: 1.1)
                )
        )
        .shadow(color: AppIntroTheme.tint.opacity(0.32), radius: 24, y: 12)
    }
}

private struct AppIntroArtworkFrame: View {
    let card: AppIntroCard

    var body: some View {
        Color.clear
            .aspectRatio(card.artworkAspectRatio, contentMode: .fit)
            .overlay {
                AppIntroArtworkBox(card: card)
            }
    }
}

private struct AppIntroArtworkBox: View {
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

private struct AppIntroCopyColumn: View {
    let card: AppIntroCard
    let isLandscape: Bool

    var body: some View {
        VStack(alignment: isLandscape ? .leading : .center, spacing: 2) {
            if let title = card.title {
                Text(title)
                    .font(.appIntroTitle(size: isLandscape ? 24 : 26))
                    .foregroundStyle(AppTheme.brandGold)
                    .multilineTextAlignment(isLandscape ? .leading : .center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)
            }

            if let subtitle = card.subtitle {
                Text(subtitle)
                    .font(.appIntroSubtitle(size: isLandscape ? 16 : 17))
                    .foregroundStyle(AppTheme.brandChalk)
                    .multilineTextAlignment(isLandscape ? .leading : .center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AppIntroQuoteRow(
                quote: card.quote,
                highlightedPhrase: card.highlightedQuotePhrase,
                side: card.professorSide,
                centerAligned: !isLandscape,
                showsProfessorSpotlight: card.showsProfessorSpotlight,
                quoteSize: card == .welcome ? 22 : 19
            )
            .padding(.top, card == .welcome ? 6 : 1)
        }
        .frame(maxWidth: .infinity, alignment: isLandscape ? .leading : .center)
    }
}

private struct AppIntroQuoteRow: View {
    let quote: String
    let highlightedPhrase: String?
    let side: AppIntroProfessorSide
    let centerAligned: Bool
    let showsProfessorSpotlight: Bool
    let quoteSize: CGFloat

    var body: some View {
        Group {
            if !showsProfessorSpotlight {
                quoteText
            } else if side == .left {
                HStack(alignment: .center, spacing: 12) {
                    AppIntroProfessorSpotlight(side: side)
                    quoteText
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    quoteText
                    AppIntroProfessorSpotlight(side: side)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: centerAligned ? .center : .leading)
    }

    private var quoteText: some View {
        Text(styledQuoteText)
            .multilineTextAlignment(centerAligned ? .center : .leading)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var styledQuoteText: AttributedString {
        let quoteFont = Font.appIntroQuote(size: quoteSize)
        let highlightedFont = Font.appIntroQuoteHighlighted(size: quoteSize)
        let baseColor = AppIntroTheme.secondaryText

        func styledFragment(
            _ text: String,
            font: Font = quoteFont,
            color: Color = baseColor
        ) -> AttributedString {
            var fragment = AttributedString(text)
            fragment.font = font
            fragment.foregroundColor = color
            return fragment
        }

        guard
            let highlightedPhrase,
            let range = quote.range(of: highlightedPhrase)
        else {
            return styledFragment("“\(quote)”")
        }

        var attributed = styledFragment("“")
        attributed += styledFragment(String(quote[..<range.lowerBound]))

        if highlightedPhrase == "PinProf" {
            attributed += styledFragment("Pin", font: highlightedFont)
            attributed += styledFragment("Prof", font: highlightedFont, color: AppTheme.brandGold)
            attributed += styledFragment(String(quote[range.upperBound...]))
            attributed += styledFragment("”")
            return attributed
        }

        attributed += styledFragment(highlightedPhrase, font: highlightedFont)
        attributed += styledFragment(String(quote[range.upperBound...]))
        attributed += styledFragment("”")
        return attributed
    }
}

private struct AppIntroProfessorSpotlight: View {
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

private struct AppIntroPageIndicators: View {
    let count: Int
    let selectedIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == selectedIndex ? AppTheme.brandGold : Color.white.opacity(0.18))
                    .frame(width: index == selectedIndex ? 34 : 18, height: 8)
                    .animation(.easeInOut(duration: 0.18), value: selectedIndex)
            }
        }
    }
}

private struct AppIntroGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AppPressFeedbackButtonStyleBody(isPressed: configuration.isPressed) { isPressed in
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(isPressed ? 0.18 : 0.10))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                )
        }
    }
}

private extension Font {
    static func appIntroTitle(size: CGFloat) -> Font {
        let preferredNames = [
            "Didot-Bold",
            "BodoniSvtyTwoITCTT-Bold",
            "AvenirNextCondensed-Heavy"
        ]

        if let fontName = preferredNames.first(where: { UIFont(name: $0, size: size) != nil }) {
            return .custom(fontName, size: size, relativeTo: .title3)
        }

        return .system(size: size, weight: .bold, design: .rounded)
    }

    static func appIntroSubtitle(size: CGFloat) -> Font {
        let preferredNames = [
            "Optima-Regular",
            "GillSans-SemiBold",
            "AvenirNext-DemiBold"
        ]

        if let fontName = preferredNames.first(where: { UIFont(name: $0, size: size) != nil }) {
            return .custom(fontName, size: size, relativeTo: .subheadline)
        }

        return .system(size: size, weight: .semibold, design: .rounded)
    }

    static func appIntroQuote(size: CGFloat) -> Font {
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

    static func appIntroQuoteHighlighted(size: CGFloat) -> Font {
        let preferredNames = [
            "Baskerville-BoldItalic",
            "Baskerville-SemiBoldItalic",
            "TimesNewRomanPS-BoldItalicMT"
        ]

        if let fontName = preferredNames.first(where: { UIFont(name: $0, size: size) != nil }) {
            return .custom(fontName, size: size, relativeTo: .body)
        }

        return .system(size: size, weight: .bold, design: .serif).italic()
    }
}

#Preview("Intro Overlay") {
    ZStack {
        AppBackground()
        AppIntroOverlay(onDismiss: {})
    }
}
