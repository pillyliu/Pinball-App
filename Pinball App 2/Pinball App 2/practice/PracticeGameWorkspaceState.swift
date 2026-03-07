import SwiftUI

struct PracticeGameWorkspaceState {
    var subview: PracticeGameSubview = .summary
    var entryTask: StudyTaskKind?
    var showingScoreSheet = false
    var saveBanner: String?
    var activeVideoID: String?
    var gameSummaryDraft: String = ""
    var revealedLogEntryID: String?
    var editingLogEntry: JournalEntry?
    var pendingDeleteLogEntry: JournalEntry?
}
