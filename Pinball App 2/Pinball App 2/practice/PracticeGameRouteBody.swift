import SwiftUI

enum PracticeGameSubview: String, CaseIterable, Identifiable {
    case summary
    case input
    case study
    case log

    var id: String { rawValue }

    var label: String {
        switch self {
        case .summary: return "Summary"
        case .input: return "Input"
        case .study: return "Study"
        case .log: return "Log"
        }
    }
}

struct PracticeGameRouteBody<Summary: View, Input: View, Study: View, Log: View>: View {
    let selectedGame: PinballGame?
    @Binding var subview: PracticeGameSubview
    @Binding var gameSummaryDraft: String
    let selectedGameID: String
    let onSaveNote: () -> Void
    @ViewBuilder let summaryView: () -> Summary
    @ViewBuilder let inputView: () -> Input
    @ViewBuilder let studyView: () -> Study
    @ViewBuilder let logView: () -> Log

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PracticeGameScreenshotSection(game: selectedGame)

                PracticeGameWorkspaceCard(
                    selectedSubview: $subview,
                    summaryView: summaryView,
                    inputView: inputView,
                    studyView: studyView,
                    logView: logView
                )

                PracticeGameNoteCard(
                    note: $gameSummaryDraft,
                    isDisabled: selectedGameID.isEmpty,
                    onSave: onSaveNote
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
    }
}

private struct PracticeGameWorkspaceCard<Summary: View, Input: View, Study: View, Log: View>: View {
    @Binding var selectedSubview: PracticeGameSubview
    @ViewBuilder let summaryView: () -> Summary
    @ViewBuilder let inputView: () -> Input
    @ViewBuilder let studyView: () -> Study
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
                case .study:
                    studyView()
                case .log:
                    logView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
