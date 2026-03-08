import SwiftUI

enum PracticeGameSubview: String, CaseIterable, Identifiable {
    case summary
    case input
    case log

    var id: String { rawValue }

    var label: String {
        switch self {
        case .summary: return "Summary"
        case .input: return "Input"
        case .log: return "Log"
        }
    }
}

struct PracticeGameRouteBody<Summary: View, Input: View, Log: View>: View {
    let selectedGame: PinballGame?
    @Binding var subview: PracticeGameSubview
    @Binding var gameSummaryDraft: String
    let selectedGameID: String
    let playableVideos: [PinballGame.PlayableVideo]
    @Binding var activeVideoID: String?
    let onOpenURL: OpenURLAction
    let onSaveNote: () -> Void
    @ViewBuilder let summaryView: () -> Summary
    @ViewBuilder let inputView: () -> Input
    @ViewBuilder let logView: () -> Log

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PracticeGameScreenshotSection(game: selectedGame)

                    PracticeGameWorkspaceCard(
                        selectedSubview: $subview,
                        summaryView: summaryView,
                        inputView: inputView,
                        logView: logView
                    )

                    PracticeGameNoteCard(
                        note: $gameSummaryDraft,
                        isDisabled: selectedGameID.isEmpty,
                        onSave: onSaveNote
                    )

                    PracticeGameResourceCard(
                        game: selectedGame,
                        playableVideos: playableVideos,
                        activeVideoID: $activeVideoID,
                        onOpenURL: onOpenURL
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
        }
    }
}

private struct PracticeGameWorkspaceCard<Summary: View, Input: View, Log: View>: View {
    @Binding var selectedSubview: PracticeGameSubview
    @ViewBuilder let summaryView: () -> Summary
    @ViewBuilder let inputView: () -> Input
    @ViewBuilder let logView: () -> Log

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Mode", selection: $selectedSubview) {
                ForEach(PracticeGameSubview.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .appSegmentedControlStyle()

            Group {
                switch selectedSubview {
                case .summary:
                    summaryView()
                case .input:
                    inputView()
                case .log:
                    logView()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }
}
