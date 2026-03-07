import SwiftUI

struct PracticeGameLifecycleContext {
    let store: PracticeStore
    let selectedGameID: Binding<String>
    let gameSummaryDraft: Binding<String>
    let activeVideoID: Binding<String?>
    let onGameViewed: ((String) -> Void)?
    let currentVideoFallbackID: () -> String?
}
