import SwiftUI

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
