import Foundation

let practiceLeagueImportDescription = "Select name to import Lansing Pinball League scores. Automatically imports new scores throughout the season."

func importedLeagueScoreSummary(_ count: Int) -> String {
    switch count {
    case 0:
        return "No imported league scores are currently saved."
    case 1:
        return "Remove only the 1 imported league score. Manual Practice notes and scores stay."
    default:
        return "Remove only the \(count) imported league scores. Manual Practice notes and scores stay."
    }
}

func clearImportedLeagueScoresButtonTitle(_ count: Int) -> String {
    switch count {
    case 0:
        return "Clear Imported League Scores"
    case 1:
        return "Clear 1 Imported League Score"
    default:
        return "Clear \(count) Imported League Scores"
    }
}

func clearImportedLeagueScoresAlertMessage(_ count: Int) -> String {
    switch count {
    case 0:
        return "No imported league scores are currently saved."
    case 1:
        return "This removes the 1 imported league score and matching journal rows. Manual Practice entries stay."
    default:
        return "This removes the \(count) imported league scores and matching journal rows. Manual Practice entries stay."
    }
}

func clearedImportedLeagueScoresStatusMessage(_ count: Int) -> String {
    switch count {
    case 0:
        return "No imported league scores to clear."
    case 1:
        return "Cleared 1 imported league score."
    default:
        return "Cleared \(count) imported league scores."
    }
}
