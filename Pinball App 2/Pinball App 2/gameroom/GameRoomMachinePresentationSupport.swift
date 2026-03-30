import SwiftUI

func gameRoomAttentionColor(_ state: GameRoomAttentionState) -> Color {
    switch state {
    case .red:
        return .red
    case .yellow:
        return .yellow
    case .green:
        return .green
    case .gray:
        return .gray
    }
}

func gameRoomLocationText(
    areaName: String?,
    groupNumber: Int?,
    position: Int?
) -> String {
    let group = groupNumber.map(String.init) ?? "—"
    let pos = position.map(String.init) ?? "—"
    if let areaName {
        let trimmed = areaName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty,
           trimmed.lowercased() != "null",
           trimmed.lowercased() != "no area" {
            return "📍 \(trimmed):\(group):\(pos)"
        }
    }
    return "📍 \(group):\(pos)"
}

func gameRoomMachineMetaLine(_ machine: OwnedMachine, areaName: String?) -> String {
    var parts: [String] = []
    if let manufacturer = machine.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
       !manufacturer.isEmpty,
       manufacturer.lowercased() != "null" {
        parts.append(manufacturer)
    }
    if let year = machine.year {
        parts.append(String(year))
    }
    parts.append(
        gameRoomLocationText(
            areaName: areaName,
            groupNumber: machine.groupNumber,
            position: machine.position
        )
    )
    return parts.joined(separator: " • ")
}

func gameRoomStatusLabel(_ status: OwnedMachineStatus) -> String {
    status.rawValue.capitalized
}

func gameRoomStatusColor(_ status: OwnedMachineStatus) -> Color {
    switch status {
    case .active:
        return AppTheme.statsHigh
    case .loaned:
        return AppTheme.brandGold
    case .archived, .sold, .traded:
        return AppTheme.brandChalk
    }
}

func gameRoomSnapshotMetrics(snapshot: OwnedMachineSnapshot, purchaseDate: Date?) -> [AppMetricItem] {
    let pitchText = snapshot.currentPitchValue.map { String(format: "%.1f", $0) } ?? "—"
    return [
        AppMetricItem(label: "Open Issues", value: "\(snapshot.openIssueCount)"),
        AppMetricItem(label: "Current Plays", value: "\(snapshot.currentPlayCount)"),
        AppMetricItem(label: "Due Tasks", value: "\(snapshot.dueTaskCount)"),
        AppMetricItem(label: "Last Service", value: snapshot.lastServiceAt?.formatted(date: .abbreviated, time: .omitted) ?? "None"),
        AppMetricItem(label: "Pitch", value: pitchText),
        AppMetricItem(label: "Last Level", value: snapshot.lastLeveledAt?.formatted(date: .abbreviated, time: .omitted) ?? "None"),
        AppMetricItem(label: "Last Inspection", value: snapshot.lastGeneralInspectionAt?.formatted(date: .abbreviated, time: .omitted) ?? "None"),
        AppMetricItem(label: "Purchase Date", value: purchaseDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
    ]
}
