import SwiftUI

struct ScoreConfirmationSheet: View {
    let status: ScoreScannerStatus
    let lockedReading: ScoreScannerLockedReading?
    @Binding var confirmationText: String
    let validationMessage: String?
    let onUseReading: () -> Void
    let onRetake: () -> Void

    @FocusState private var scoreFieldFocused: Bool

    private var canUseReading: Bool {
        ScoreParsingService.normalizedScore(fromManualInput: confirmationText) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(status == .locked ? "Locked score" : "Confirm score")
                    .font(.headline)

                Text(lockedReading?.formattedScore ?? (confirmationText.isEmpty ? "No reading yet" : confirmationText))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()

                if let lockedReading, !lockedReading.rawText.isEmpty {
                    Text("OCR: \(lockedReading.rawText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Manual correction")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Score", text: $confirmationText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()
                    .focused($scoreFieldFocused)
                    .onChange(of: confirmationText) { _, newValue in
                        let formatted = ScoreParsingService.formattedScoreInput(from: newValue)
                        if formatted != newValue {
                            confirmationText = formatted
                        }
                    }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack(spacing: 10) {
                Button("Retake", action: onRetake)
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.85))

                Button("Manual Entry") {
                    scoreFieldFocused = true
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.85))

                Button("Use Reading", action: onUseReading)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canUseReading)
            }
            .buttonBorderShape(.capsule)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.34), radius: 16, y: 8)
    }
}
