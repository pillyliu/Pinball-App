import Foundation

extension PracticeStore {
    var mechanicsSkills: [String] {
        [
            "Dead Bounce",
            "Post Pass",
            "Post Catch",
            "Flick Pass",
            "Nudge Pass",
            "Drop Catch",
            "Live Catch",
            "Shatz",
            "Back Flip",
            "Loop Pass",
            "Slap Save (Single)",
            "Slap Save (Double)",
            "Air Defense",
            "Cradle Separation",
            "Over Under",
            "Tap Pass"
        ]
    }

    func detectedMechanicsTags(in text: String) -> [String] {
        let normalized = text.lowercased()
        return mechanicsSkills.filter { skill in
            mechanicsAliases(for: skill).contains { alias in
                normalized.contains(alias)
            }
        }
    }

    func mechanicsLogs(for skill: String) -> [MechanicsSkillLog] {
        let trimmedSkill = skill.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSkill.isEmpty else { return [] }

        return state.noteEntries
            .filter { entry in
                let detailMatch = detectedMechanicsTags(in: entry.detail ?? "").contains(trimmedSkill)
                let tagMatch = entry.note.localizedCaseInsensitiveContains("#\(trimmedSkill.replacingOccurrences(of: " ", with: "").lowercased())")
                let termMatch = detectedMechanicsTags(in: entry.note).contains(trimmedSkill)
                return detailMatch || tagMatch || termMatch
            }
            .sorted { $0.timestamp < $1.timestamp }
            .map { entry in
                MechanicsSkillLog(
                    id: entry.id,
                    skill: trimmedSkill,
                    timestamp: entry.timestamp,
                    comfort: parseComfortValue(from: entry.note),
                    gameID: entry.gameID,
                    note: entry.note
                )
            }
    }

    func mechanicsSummary(for skill: String) -> MechanicsSkillSummary {
        let logs = mechanicsLogs(for: skill)
        let comforts = logs.compactMap(\.comfort)

        let latestComfort = comforts.last
        let averageComfort = comforts.isEmpty ? nil : (Double(comforts.reduce(0, +)) / Double(comforts.count))
        let trendDelta: Double? = {
            guard comforts.count >= 2 else { return nil }
            let split = max(1, comforts.count / 2)
            let firstAvg = Double(comforts.prefix(split).reduce(0, +)) / Double(split)
            let secondSlice = comforts.suffix(comforts.count - split)
            guard !secondSlice.isEmpty else { return nil }
            let secondAvg = Double(secondSlice.reduce(0, +)) / Double(secondSlice.count)
            return secondAvg - firstAvg
        }()

        return MechanicsSkillSummary(
            skill: skill,
            totalLogs: logs.count,
            latestComfort: latestComfort,
            averageComfort: averageComfort,
            trendDelta: trendDelta,
            latestTimestamp: logs.last?.timestamp
        )
    }

    func allTrackedMechanicsSkills() -> [String] {
        var tracked = Set(mechanicsSkills)
        for note in state.noteEntries {
            if let detail = note.detail, !detail.isEmpty {
                for matched in detectedMechanicsTags(in: detail) {
                    tracked.insert(matched)
                }
            }
            for skill in detectedMechanicsTags(in: note.note) {
                tracked.insert(skill)
            }
        }
        return mechanicsSkills.filter { tracked.contains($0) }
    }

    func parseComfortValue(from note: String) -> Int? {
        let pattern = #"comfort\s+([1-5])(?:\s*/\s*5)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(location: 0, length: note.utf16.count)
        guard let match = regex.firstMatch(in: note, options: [], range: range),
              match.numberOfRanges >= 2,
              let comfortRange = Range(match.range(at: 1), in: note) else {
            return nil
        }
        return Int(note[comfortRange])
    }

    func mechanicsAliases(for skill: String) -> [String] {
        switch skill {
        case "Dead Bounce": return ["dead bounce", "deadbounce", "dead flip", "deadflip"]
        case "Post Pass": return ["post pass", "postpass"]
        case "Post Catch": return ["post catch", "postcatch"]
        case "Flick Pass": return ["flick pass", "flickpass"]
        case "Nudge Pass": return ["nudge pass", "nudgepass", "nudge control", "nudgecontrol"]
        case "Drop Catch": return ["drop catch", "dropcatch"]
        case "Live Catch": return ["live catch", "livecatch"]
        case "Shatz": return ["shatz", "shatzing", "alley pass", "alleypass"]
        case "Back Flip": return ["back flip", "backflip", "bang back", "bangback"]
        case "Loop Pass": return ["loop pass", "looppass"]
        case "Slap Save (Single)": return ["slap save", "slap save single", "single slap save"]
        case "Slap Save (Double)": return ["slap save double", "double slap save"]
        case "Air Defense": return ["air defense", "airdefense"]
        case "Cradle Separation": return ["cradle separation", "cradleseparation"]
        case "Over Under": return ["over under", "overunder"]
        case "Tap Pass": return ["tap pass", "tappass"]
        default: return [skill.lowercased()]
        }
    }
}
