import SwiftUI

struct GameRoomImportSourceSection: View {
    @Binding var sourceInput: String
    let isLoading: Bool
    let errorMessage: String?
    let canFetchCollection: Bool
    let onFetchCollection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Pinside username or public collection URL", text: $sourceInput)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.go)
                .onSubmit(onFetchCollection)

            HStack(spacing: 10) {
                Button("Fetch Collection", action: onFetchCollection)
                    .buttonStyle(AppPrimaryActionButtonStyle())
                    .disabled(!canFetchCollection)
            }

            if isLoading {
                AppInlineTaskStatus(text: "Fetching collection…", showsProgress: true)
            } else if let errorMessage {
                AppInlineTaskStatus(text: errorMessage, isError: true)
            }
        }
    }
}
