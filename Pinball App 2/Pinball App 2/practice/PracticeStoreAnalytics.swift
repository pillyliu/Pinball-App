import Foundation

extension PracticeStore {
    func groupPriorityCandidates(group: CustomGameGroup) -> [PinballGame] {
        let groupGames = games.filter { group.gameIDs.contains($0.id) }
        return groupGames.sorted { lhs, rhs in
            scoreGapSeverity(for: lhs.id) > scoreGapSeverity(for: rhs.id)
        }
    }

    func recommendedFocusGames(limit: Int = 3) -> [PinballGame] {
        games.sorted { lhs, rhs in
            focusPriority(for: lhs.id) > focusPriority(for: rhs.id)
        }
        .prefix(limit)
        .map { $0 }
    }

    func dashboardAlerts(for gameID: String) -> [PracticeDashboardAlert] {
        var alerts: [PracticeDashboardAlert] = []
        let now = Date()

        if let rulesheetLast = taskLastTimestamp(gameID: gameID, task: .rulesheet) {
            let days = Calendar.current.dateComponents([.day], from: rulesheetLast, to: now).day ?? 0
            if days >= 90 {
                alerts.append(PracticeDashboardAlert(id: UUID(), message: "Rulesheet last read \(days) days ago.", severity: .warning))
            }
        } else {
            alerts.append(PracticeDashboardAlert(id: UUID(), message: "No rulesheet reading logged yet.", severity: .info))
        }

        if let practiceLast = taskLastTimestamp(gameID: gameID, task: .practice) {
            let days = Calendar.current.dateComponents([.day], from: practiceLast, to: now).day ?? 0
            if days >= 14 {
                alerts.append(PracticeDashboardAlert(id: UUID(), message: "No practice logged in the last \(days) days.", severity: .warning))
            }
        } else {
            alerts.append(PracticeDashboardAlert(id: UUID(), message: "No practice sessions logged yet.", severity: .info))
        }

        if let summary = scoreSummary(for: gameID), summary.median > 0 {
            let spreadRatio = (summary.p75 - summary.floor) / summary.median
            if spreadRatio >= 0.6 {
                alerts.append(
                    PracticeDashboardAlert(
                        id: UUID(),
                        message: "Score variance is high (wide floor-to-upper spread).",
                        severity: .caution
                    )
                )
            }
        }

        if alerts.isEmpty {
            alerts.append(PracticeDashboardAlert(id: UUID(), message: "No immediate alerts for this game.", severity: .info))
        }
        return alerts
    }

    func timelineSummary(for gameID: String, gapMode: ChartGapMode) -> PracticeTimelineSummary {
        let scores = state.scoreEntries
            .filter { $0.gameID == gameID }
            .sorted { $0.timestamp < $1.timestamp }
        let timestamps = scores.map(\.timestamp)
        let gaps = timestamps.adjacentDayGaps()
        let longGaps = gaps.filter { $0 >= 14 }
        let longestGap = gaps.max() ?? 0

        let activeSessionCount: Int = switch gapMode {
        case .realTimeline:
            max(1, timestamps.count)
        case .compressInactive:
            max(1, timestamps.count - longGaps.count)
        case .activeSessionsOnly:
            max(1, timestamps.count - longGaps.count)
        case .brokenAxis:
            max(1, timestamps.count)
        }

        let modeDescription: String = switch gapMode {
        case .realTimeline:
            "Shows raw calendar spacing between score entries."
        case .compressInactive:
            "Compresses long inactive gaps to emphasize active periods."
        case .activeSessionsOnly:
            "Focuses only on contiguous active sessions."
        case .brokenAxis:
            "Preserves chronology with visual breaks for long inactivity."
        }

        return PracticeTimelineSummary(
            scoreCount: scores.count,
            activeSessionCount: activeSessionCount,
            longGapCount: longGaps.count,
            longestGapDays: longestGap,
            modeDescription: modeDescription
        )
    }

    func studyCompletionPercent(for gameID: String, startDate: Date? = nil, endDate: Date? = nil) -> Int {
        let values = StudyTaskKind.allCases.map {
            latestTaskProgress(gameID: gameID, task: $0, startDate: startDate, endDate: endDate)
        }
        let total = values.reduce(0, +)
        return Int((Double(total) / Double(max(values.count, 1))).rounded())
    }

    func scoreGapSeverity(for gameID: String) -> Double {
        guard let summary = scoreSummary(for: gameID) else { return 999_999 }
        return max(0, summary.median - summary.floor)
    }

    func focusPriority(for gameID: String, startDate: Date? = nil, endDate: Date? = nil) -> Double {
        let varianceWeight: Double
        if let summary = scoreSummary(for: gameID), summary.median > 0 {
            varianceWeight = (summary.p75 - summary.floor) / summary.median
        } else {
            varianceWeight = 1.0
        }

        let practiceGapDays: Double = {
            guard let last = taskLastTimestamp(gameID: gameID, task: .practice, startDate: startDate, endDate: endDate) else { return 30 }
            return Double(Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0)
        }()

        let completionGap = Double(100 - studyCompletionPercent(for: gameID, startDate: startDate, endDate: endDate)) / 100.0
        return (varianceWeight * 0.45) + (min(practiceGapDays, 30) / 30.0 * 0.4) + (completionGap * 0.15)
    }

    func taskLastTimestamp(gameID: String, task: StudyTaskKind, startDate: Date? = nil, endDate: Date? = nil) -> Date? {
        let action = actionType(for: task)
        return state.journalEntries
            .filter {
                $0.gameID == gameID &&
                    $0.action == action &&
                    isTimestampWithinWindow($0.timestamp, startDate: startDate, endDate: endDate)
            }
            .sorted { $0.timestamp > $1.timestamp }
            .first?
            .timestamp
    }

    func latestTaskProgress(gameID: String, task: StudyTaskKind, startDate: Date? = nil, endDate: Date? = nil) -> Int {
        let explicit = state.studyEvents
            .filter {
                $0.gameID == gameID &&
                    $0.task == task &&
                    isTimestampWithinWindow($0.timestamp, startDate: startDate, endDate: endDate)
            }
            .sorted { $0.timestamp > $1.timestamp }
            .first?
            .progressPercent

        if let explicit {
            return explicit
        }

        if task == .practice {
            let hasPractice = state.journalEntries.contains {
                $0.gameID == gameID &&
                    $0.action == .practiceSession &&
                    isTimestampWithinWindow($0.timestamp, startDate: startDate, endDate: endDate)
            }
            return hasPractice ? 100 : 0
        }

        if task == .playfield {
            let hasViewed = state.journalEntries.contains {
                $0.gameID == gameID &&
                    $0.action == .playfieldViewed &&
                    isTimestampWithinWindow($0.timestamp, startDate: startDate, endDate: endDate)
            }
            return hasViewed ? 100 : 0
        }
        return 0
    }

    private func isTimestampWithinWindow(_ timestamp: Date, startDate: Date?, endDate: Date?) -> Bool {
        if let startDate, timestamp < startDate {
            return false
        }
        if let endDate {
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            if timestamp > endOfDay {
                return false
            }
        }
        return true
    }
}

private extension Array where Element == Date {
    func adjacentDayGaps() -> [Int] {
        guard count > 1 else { return [] }
        let ordered = self.sorted()
        return zip(ordered, ordered.dropFirst()).map { start, end in
            Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        }
    }
}
