import SwiftUI
import Foundation

struct PracticeScreenState {
    var selectedGameID: String = ""
    var gameNavigationPath: [PracticeRoute] = []
    var presentedSheet: PracticeSheet?
    var selectedPlayfieldImageURLs: [URL] = []
    var selectedRulesheetSource: RulesheetRemoteSource?
    var selectedExternalRulesheetURL: URL?
    var editingGroupID: UUID?
    var currentGroupDateEditorGroupID: UUID?
    var currentGroupDateEditorField: GroupEditorDateField = .start
    var currentGroupDateEditorValue: Date = Date()
    var gameTransitionSourceID: String?
    var quickEntryKind: QuickEntrySheet?
    var isEditingJournalEntries = false
    var selectedJournalItemIDs: Set<String> = []
    var editingJournalEntry: JournalEntry?
    var selectedMechanicSkill: String = ""
    var mechanicsComfort: Double = 3
    var mechanicsNote: String = ""
    var playerName: String = ""
    var ifpaPlayerID: String = ""
    var insightsOpponentName: String = ""
    var insightsOpponentOptions: [String] = []
    var leaguePlayerName: String = ""
    var leaguePlayerOptions: [String] = []
    var leagueImportStatus: String = ""
    var cloudSyncEnabled = false
    var showingNamePrompt = false
    var firstNamePromptValue: String = ""
    var importLplStatsOnNameSave = true
    var showingResetJournalPrompt = false
    var resetJournalConfirmationText: String = ""
    var headToHead: HeadToHeadComparison?
    var isLoadingHeadToHead = false
    var viewportHeight: CGFloat = 0
}
