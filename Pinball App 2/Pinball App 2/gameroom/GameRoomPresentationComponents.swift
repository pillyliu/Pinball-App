import SwiftUI

struct GameRoomLogDetailCard: View {
    let event: MachineEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AppCardSubheading(text: "Selected Log Entry")

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    AppCardTitle(text: event.summary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Type: \(event.type.displayTitle) • Category: \(event.category.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let notes = normalized(event.notes) {
                        detailLine("Notes", notes)
                    }
                    if let playTotal = event.playCountAtEvent, playTotal >= 0 {
                        detailLine("Total Plays", "\(playTotal)")
                    }
                    if let consumables = normalized(event.consumablesUsed) {
                        detailLine("Consumables", consumables)
                    }
                    if let parts = normalized(event.partsUsed) {
                        detailLine("Parts / Mod", parts)
                    }
                    if event.pitchValue != nil || normalized(event.pitchMeasurementPoint) != nil {
                        let pitchValue = event.pitchValue.map { String(format: "%.1f", $0) } ?? "—"
                        let pitchPoint = normalized(event.pitchMeasurementPoint) ?? "—"
                        detailLine("Pitch", "\(pitchValue) @ \(pitchPoint)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 164)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.controlBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.controlBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func detailLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        return gameRoomNormalizedOptional(value)
    }
}

extension MachineEventType {
    var displayTitle: String {
        switch self {
        case .loanedOut: return "Loaned Out"
        case .listedForSale: return "Listed For Sale"
        default:
            return rawValue
                .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .capitalized
        }
    }
}
