import SwiftUI

enum TournamentImportError: LocalizedError {
    case noLinkedArenas

    var errorDescription: String? {
        switch self {
        case .noLinkedArenas:
            return "No OPDB-linked arenas were found for that tournament."
        }
    }
}

struct SettingsTournamentImportCard: View {
    @Binding var rawTournamentID: String
    let isImporting: Bool
    let errorMessage: String?
    let canImportTournament: Bool
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsProviderCaption(prefix: "Import powered by ", linkText: "Match Play", urlString: "https://matchplay.events")

            TextField("Tournament ID or URL", text: $rawTournamentID)
                .submitLabel(.done)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()

            Text("Enter a Match Play tournament ID or URL to import its arena list into Library and Practice.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(isImporting ? "Importing..." : "Import Tournament", action: onImport)
                .buttonStyle(AppPrimaryActionButtonStyle())
                .disabled(!canImportTournament)

            if isImporting {
                AppInlineTaskStatus(text: "Importing tournament…", showsProgress: true)
            } else if let errorMessage {
                AppInlineTaskStatus(text: errorMessage, isError: true)
            }
        }
        .padding(12)
        .appPanelStyle()
    }
}

func extractTournamentID(from rawValue: String) -> String? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if trimmed.allSatisfy(\.isNumber) {
        return trimmed
    }

    if let match = trimmed.range(of: #"tournaments/(\d+)"#, options: .regularExpression) {
        let matched = String(trimmed[match])
        return matched.components(separatedBy: "/").last
    }

    return nil
}
