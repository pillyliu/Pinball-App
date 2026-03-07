import SwiftUI

struct PracticeHomeContext {
    let store: PracticeStore
    let greetingName: String?
    let hasIFPAProfileAccess: Bool
    let resumeGame: PinballGame?
    let allGames: [PinballGame]
    let librarySources: [PinballLibrarySource]
    let selectedLibrarySourceID: String?
    let activeGroups: [CustomGameGroup]
    let selectedGroupID: UUID?
    let groupGames: (CustomGameGroup) -> [PinballGame]
    let gameTransition: Namespace.ID
    let showingNamePrompt: Bool
    let firstNamePromptValue: Binding<String>
    let importLplStatsOnNameSave: Binding<Bool>
    let onOpenSettings: () -> Void
    let onOpenIFPAProfile: () -> Void
    let onResume: (String) -> Void
    let onSelectLibrarySource: (String) -> Void
    let onPickGame: (String, String?) -> Void
    let onQuickEntry: (QuickEntrySheet) -> Void
    let onNotNow: () -> Void
    let onSaveName: (String, Bool) -> Void
    let onViewportHeightChanged: (CGFloat) -> Void
}
