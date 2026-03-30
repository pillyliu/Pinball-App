import SwiftUI

struct GameScoreEntrySheet: View {
    let gameID: String
    @ObservedObject var store: PracticeStore
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var scoreText: String = ""
    @State private var scoreContext: ScoreContext = .practice
    @State private var tournamentName: String = ""
    @State private var validationMessage: String?
    @State private var showingScoreScanner = false
    @State private var pendingScoreScannerPresentation = false
    @FocusState private var scoreFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                PracticeEntryGlassCard(maxHeight: 420) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Score", text: $scoreText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appControlStyle()
                            .focused($scoreFieldFocused)
                            .onChange(of: scoreText) { _, newValue in
                                let formatted = formatPracticeScoreInputWithCommas(newValue)
                                if formatted != newValue { scoreText = formatted }
                            }

                        Button {
                            presentScoreScanner()
                        } label: {
                            Label("Scan Score", systemImage: "viewfinder")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .appControlStyle()
                                .contentShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)

                        Picker("Context", selection: $scoreContext) {
                            ForEach(ScoreContext.allCases) { context in
                                Text(context.label).tag(context)
                            }
                        }
                        .appSegmentedControlStyle()

                        if scoreContext == .tournament {
                            TextField("Tournament name", text: $tournamentName)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .appControlStyle()
                        }

                        if let validationMessage {
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Spacer()
                    }
                    .padding(14)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .navigationTitle("Log Score")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: scoreFieldFocused) { _, isFocused in
                guard !isFocused, pendingScoreScannerPresentation else { return }
                pendingScoreScannerPresentation = false
                Task { @MainActor in
                    await Task.yield()
                    showingScoreScanner = true
                }
            }
            .fullScreenCover(isPresented: $showingScoreScanner) {
                ScoreScannerView(
                    onUseReading: { score in
                        scoreText = ScoreParsingService.formattedScore(score: score)
                        validationMessage = nil
                        showingScoreScanner = false
                    },
                    onClose: {
                        showingScoreScanner = false
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCancelAction {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(title: "Save", isDisabled: gameID.isEmpty) {
                        if save() {
                            onSaved()
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func presentScoreScanner() {
        validationMessage = nil
        guard !showingScoreScanner else { return }
        if scoreFieldFocused {
            pendingScoreScannerPresentation = true
            scoreFieldFocused = false
        } else {
            showingScoreScanner = true
        }
    }

    private func save() -> Bool {
        validationMessage = nil
        let normalized = scoreText.replacingOccurrences(of: ",", with: "")
        guard let score = Double(normalized), score > 0 else {
            validationMessage = "Enter a valid score above 0."
            return false
        }
        store.addScore(gameID: gameID, score: score, context: scoreContext, tournamentName: tournamentName)
        return true
    }
}
