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

extension Font {
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
