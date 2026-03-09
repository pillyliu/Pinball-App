import SwiftUI

struct PracticeMechanicsContext {
    let selectedMechanicSkill: Binding<String>
    let mechanicsComfort: Binding<Double>
    let mechanicsNote: Binding<String>
    let trackedSkills: [String]
    let detectedTags: [String]
    let summaryForSkill: (String) -> MechanicsSkillSummary
    let allLogs: () -> [MechanicsSkillLog]
    let logsForSkill: (String) -> [MechanicsSkillLog]
    let gameNameForID: (String) -> String
    let maxHistoryHeight: CGFloat
    let onLogMechanicsSession: (String, Int, String) -> Void
}
