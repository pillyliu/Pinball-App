import SwiftUI

enum PracticeHubDestination: String, CaseIterable, Identifiable, Hashable {
    case groupDashboard
    case journal
    case insights
    case mechanics

    var id: String { rawValue }

    var label: String {
        switch self {
        case .groupDashboard: return "Group Dashboard"
        case .journal: return "Journal Timeline"
        case .insights: return "Insights"
        case .mechanics: return "Mechanics"
        }
    }

    var subtitle: String {
        switch self {
        case .groupDashboard: return "View and edit groups"
        case .journal: return "Full app activity history"
        case .insights: return "Scores, variance, and trends"
        case .mechanics: return "Track pinball skills"
        }
    }

    var icon: String {
        switch self {
        case .groupDashboard: return "square.grid.2x2"
        case .journal: return "list.bullet.rectangle"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .mechanics: return "circle.fill"
        }
    }
}

enum PracticeNavRoute: Hashable {
    case destination(PracticeHubDestination)
    case game(String)
}

enum QuickEntrySheet: String, Identifiable {
    case score
    case study
    case practice
    case mechanics

    var id: String { rawValue }

    var title: String {
        "Quick Entry"
    }

    var defaultActivity: QuickEntryActivity {
        switch self {
        case .score: return .score
        case .study: return .rulesheet
        case .practice: return .practice
        case .mechanics: return .mechanics
        }
    }
}

enum QuickEntryActivity: String, CaseIterable, Identifiable {
    case score
    case rulesheet
    case tutorialVideo
    case gameplayVideo
    case playfield
    case practice
    case mechanics

    var id: String { rawValue }

    var label: String {
        switch self {
        case .score: return "Score"
        case .rulesheet: return "Rulesheet"
        case .tutorialVideo: return "Tutorial Video"
        case .gameplayVideo: return "Gameplay Video"
        case .playfield: return "Playfield Image"
        case .practice: return "Practice"
        case .mechanics: return "Mechanics"
        }
    }

    var asTask: StudyTaskKind? {
        switch self {
        case .rulesheet: return .rulesheet
        case .tutorialVideo: return .tutorialVideo
        case .gameplayVideo: return .gameplayVideo
        case .playfield: return .playfield
        case .practice: return .practice
        case .mechanics: return nil
        case .score: return nil
        }
    }
}

enum JournalFilter: String, CaseIterable, Identifiable {
    case all
    case study
    case practice
    case score
    case notes
    case league

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .study: return "Study"
        case .practice: return "Practice"
        case .score: return "Scores"
        case .notes: return "Notes"
        case .league: return "League"
        }
    }
}
