import SwiftUI

struct GameRoomMediaImportStatusSection: View {
    let mediaImportState: GameRoomMediaImportState

    var body: some View {
        if mediaImportState.isImportingAsset {
            AppInlineTaskStatus(text: "Importing media…", showsProgress: true)
        }

        if let importErrorMessage = mediaImportState.importErrorMessage {
            AppInlineStatusMessage(text: importErrorMessage, isError: true)
        }
    }
}
