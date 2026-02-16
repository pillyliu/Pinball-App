import SwiftUI

struct PracticeMechanicsSectionView: View {
    @Binding var selectedMechanicSkill: String
    @Binding var mechanicsComfort: Double
    @Binding var mechanicsNote: String
    let trackedSkills: [String]

    let detectedTags: [String]
    let summaryForSkill: (String) -> MechanicsSkillSummary
    let logsForSkill: (String) -> [MechanicsSkillLog]
    let gameNameForID: (String) -> String
    let maxHistoryHeight: CGFloat

    let onLogMechanicsSession: (_ skill: String, _ comfort: Int, _ note: String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mechanics")
                    .font(.headline)
                Text("Skills are tracked as tags in your notes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Skill", selection: $selectedMechanicSkill) {
                    ForEach(trackedSkills, id: \.self) { skill in
                        Text(skill).tag(skill)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Competency")
                    Spacer()
                    Text("\(Int(mechanicsComfort))/5")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $mechanicsComfort, in: 1...5, step: 1)

                TextField("Mechanics note (ex: #dropcatch felt consistent)", text: $mechanicsNote, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                if !detectedTags.isEmpty {
                    Text("Detected tags: \(detectedTags.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Log Mechanics Session") {
                    onLogMechanicsSession(selectedMechanicSkill, Int(mechanicsComfort), mechanicsNote)
                }
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            if !selectedMechanicSkill.isEmpty {
                let summary = summaryForSkill(selectedMechanicSkill)
                let logs = logsForSkill(selectedMechanicSkill)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(selectedMechanicSkill) History")
                        .font(.headline)

                    HStack(spacing: 8) {
                        MetricPill(label: "Logs", value: "\(summary.totalLogs)")
                        MetricPill(label: "Latest", value: summary.latestComfort.map { "\($0)/5" } ?? "-")
                        MetricPill(label: "Avg", value: summary.averageComfort.map { String(format: "%.1f/5", $0) } ?? "-")
                        MetricPill(label: "Trend", value: summary.trendDelta.map { signedCompact($0) } ?? "-")
                    }

                    MechanicsTrendSparkline(logs: logs)
                        .frame(height: 54)

                    if logs.isEmpty {
                        Text("No sessions logged for this skill yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(logs.reversed())) { log in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(log.note)
                                            .font(.footnote)
                                        Text("\(log.timestamp.formatted(date: .abbreviated, time: .shortened)) • \(gameNameForID(log.gameID))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if log.id != logs.first?.id {
                                        Divider().overlay(.white.opacity(0.14))
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: maxHistoryHeight)
                        .scrollBounceBehavior(.basedOnSize)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .appPanelStyle()
            }

            if let tutorialsURL = URL(string: "https://www.deadflip.com/tutorials") {
                Link("Dead Flip Tutorials", destination: tutorialsURL)
                    .buttonStyle(.glass)
            }
        }
    }

    private func signedCompact(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value))"
    }
}
