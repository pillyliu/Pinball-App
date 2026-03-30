import SwiftUI

struct GameRoomSettingsView: View {
    private struct SectionPickerBar: View {
        @Binding var selectedSection: GameRoomSettingsSection

        var body: some View {
            Picker("Mode", selection: $selectedSection) {
                ForEach(GameRoomSettingsSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .appSegmentedControlStyle()
        }
    }

    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let gameTransition: Namespace.ID
    let onOpenMachineView: (UUID, String?, String) -> Void
    @State private var selectedSection: GameRoomSettingsSection = .importFromPinside
    @State private var saveFeedbackText: String?
    @State private var saveFeedbackToken = 0

    var body: some View {
        ZStack {
            settingsScrollBody
            saveFeedbackOverlay
        }
        .navigationTitle("GameRoom Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await catalogLoader.loadIfNeeded()
        }
    }

    private var settingsScrollBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionPickerBar(selectedSection: $selectedSection)
                errorStatus
                GameRoomSettingsSectionCard(
                    store: store,
                    catalogLoader: catalogLoader,
                    gameTransition: gameTransition,
                    selectedSection: selectedSection,
                    onOpenMachineView: onOpenMachineView,
                    onShowSaveFeedback: showSaveFeedback
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var errorStatus: some View {
        if let lastErrorMessage = store.lastErrorMessage, !lastErrorMessage.isEmpty {
            AppInlineTaskStatus(text: lastErrorMessage, isError: true)
        }
    }

    private var saveFeedbackOverlay: some View {
        GameRoomFloatingSaveFeedbackOverlay(
            token: saveFeedbackToken,
            text: saveFeedbackText
        )
        .allowsHitTesting(false)
        .padding(.horizontal, 28)
    }

    private func showSaveFeedback(_ text: String) {
        saveFeedbackText = text
        saveFeedbackToken += 1
    }
}

struct GameRoomSettingsSectionCard: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let gameTransition: Namespace.ID
    let selectedSection: GameRoomSettingsSection
    let onOpenMachineView: (UUID, String?, String) -> Void
    let onShowSaveFeedback: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionTitle(text: sectionHeading)
            sectionContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .importFromPinside:
            GameRoomImportSettingsView(store: store, catalogLoader: catalogLoader)
        case .editMachines:
            GameRoomEditMachinesView(
                store: store,
                catalogLoader: catalogLoader,
                onShowSaveFeedback: onShowSaveFeedback
            )
        case .archive:
            GameRoomArchiveSettingsView(
                store: store,
                gameTransition: gameTransition,
                onOpenMachineView: onOpenMachineView
            )
        }
    }

    private var sectionHeading: String {
        switch selectedSection {
        case .importFromPinside:
            return "Import from Pinside"
        case .editMachines:
            return "Edit GameRoom"
        case .archive:
            return "Machine Archive"
        }
    }
}
