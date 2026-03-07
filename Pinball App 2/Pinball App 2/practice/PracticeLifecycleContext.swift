import SwiftUI

struct PracticeLifecycleContext {
    let lastViewedLibraryGameID: String?
    let journalFilterRaw: String
    let presentedSheet: PracticeSheet?
    let onInitialLoad: () async -> Void
    let onLibraryGameViewedChanged: (String?) -> Void
    let onJournalFilterChanged: () -> Void
    let onPresentedSheetChanged: (PracticeSheet?) -> Void
    let onLibrarySourcesChanged: () async -> Void
}
