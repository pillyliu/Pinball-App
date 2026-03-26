import SwiftUI

extension PracticeScreen {
    func practiceLifecycleHost<Content: View>(_ content: Content) -> some View {
        let lifecycleContext = practiceLifecycleContext

        return content
            .task {
                await lifecycleContext.onInitialLoad()
            }
            .onChange(of: lifecycleContext.scenePhase) { _, newPhase in
                Task {
                    await lifecycleContext.onScenePhaseChanged(newPhase)
                }
            }
            .onChange(of: lifecycleContext.lastViewedLibraryGameID) { _, newValue in
                lifecycleContext.onLibraryGameViewedChanged(newValue)
            }
            .onChange(of: lifecycleContext.journalFilterRaw) { _, _ in
                lifecycleContext.onJournalFilterChanged()
            }
            .onChange(of: lifecycleContext.presentedSheet) { _, newValue in
                lifecycleContext.onPresentedSheetChanged(newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: .pinballLibrarySourcesDidChange)) { _ in
                Task {
                    await lifecycleContext.onLibrarySourcesChanged()
                }
            }
    }
}
