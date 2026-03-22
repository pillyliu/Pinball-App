import SwiftUI

struct PracticeGameLogPanel: View {
    @ObservedObject var store: PracticeStore
    let gameID: String
    let onEditEntry: (JournalEntry) -> Void
    let onDeleteEntry: (JournalEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let logs = store.gameJournalEntries(for: gameID)
            if logs.isEmpty {
                AppPanelEmptyCard(text: "No actions logged yet.")
            } else {
                List {
                    ForEach(logs) { entry in
                        gameLogRow(entry)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .frame(height: embeddedLogListHeight(for: logs.count))
                .appEmbeddedListStyle()
            }
        }
    }

    private func embeddedLogListHeight(for count: Int) -> CGFloat {
        min(280, max(72, CGFloat(count) * 72))
    }

    @ViewBuilder
    private func gameLogRow(_ entry: JournalEntry) -> some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            styledPracticeJournalSummary(store.journalSummary(for: entry))
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if store.canEditJournalEntry(entry) {
            JournalStaticEditableRow {
                content
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    onDeleteEntry(entry)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)

                Button {
                    onEditEntry(entry)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(AppTheme.statsMeanMedian)
            }
        } else {
            content
        }
    }
}

struct PracticeGameInputPanel: View {
    let onSelectTask: (StudyTaskKind) -> Void
    let onShowScore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task-specific logging")
                .font(.footnote)
                .foregroundStyle(.secondary)

            let inputButtons: [GameInputShortcut] = [
                .init(title: "Rulesheet", icon: "book.closed", action: { onSelectTask(.rulesheet) }),
                .init(title: "Playfield", icon: "photo.on.rectangle", action: { onSelectTask(.playfield) }),
                .init(title: "Score", icon: "number.circle", action: onShowScore),
                .init(title: "Tutorial", icon: "graduationcap.circle", action: { onSelectTask(.tutorialVideo) }),
                .init(title: "Practice", icon: "figure.run.circle", action: { onSelectTask(.practice) }),
                .init(title: "Gameplay", icon: "gamecontroller", action: { onSelectTask(.gameplayVideo) })
            ]

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(inputButtons) { button in
                    Button(action: button.action) {
                        VStack(spacing: 3) {
                            Image(systemName: button.icon)
                            Text(button.title)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .appControlStyle()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct PracticeGameSummaryPanel: View {
    @ObservedObject var store: PracticeStore
    let gameID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let group = store.activeGroup(for: gameID) {
                let taskProgress = Dictionary(
                    uniqueKeysWithValues: StudyTaskKind.allCases.map { task in
                        (
                            task,
                            store.latestTaskProgress(
                                gameID: gameID,
                                task: task,
                                startDate: group.startDate,
                                endDate: group.endDate
                            )
                        )
                    }
                )
                HStack(spacing: 10) {
                    GroupProgressWheel(taskProgress: taskProgress)
                        .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.footnote.weight(.semibold))
                        Text(wheelProgressSummary(taskProgress: taskProgress))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let next = nextAction(gameID: gameID) {
                VStack(alignment: .leading, spacing: 2) {
                    AppCardSubheading(text: "Next Action")
                    Text(next)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            let alerts = store.dashboardAlerts(for: gameID)
            if !alerts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    AppCardSubheading(text: "Alerts")
                    ForEach(alerts) { alert in
                        Text("• \(alert.message)")
                            .font(.footnote)
                            .foregroundStyle(alertColor(alert.severity))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                AppCardSubheading(text: "Consistency")

                if let summary = store.scoreSummary(for: gameID), summary.median > 0 {
                    let spreadRatio = (summary.p75 - summary.floor) / summary.median
                    Text(
                        spreadRatio >= 0.6
                            ? "High variance: raise floor through repeatable safe scoring paths."
                            : "Stable spread: keep pressure on median improvements."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Log more scores to unlock floor/variance guidance.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    AppCardSubheading(text: "Score Stats")

                    if let stats = scoreStats(for: gameID) {
                        statRow("High", formatScore(stats.high), color: AppTheme.statsHigh)
                        statRow("Low", formatScore(stats.low), color: AppTheme.statsLow)
                        statRow("Mean", formatScore(stats.mean), color: AppTheme.statsMeanMedian)
                        statRow("Median", formatScore(stats.median), color: AppTheme.statsMeanMedian)
                        statRow("St Dev", formatScore(stats.stdev), color: .secondary)
                    } else {
                        Text("Log scores to unlock.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    AppCardSubheading(text: "Target Scores")

                    if let targets = store.leagueTargetScores(for: gameID) {
                        statRow("2nd", formatScore(targets.great), color: AppTheme.targetGreat)
                        statRow("4th", formatScore(targets.main), color: AppTheme.targetMain)
                        statRow("8th", formatScore(targets.floor), color: AppTheme.targetFloor)
                    } else if store.isLoadingLeagueTargets && !store.didLoadLeagueTargets {
                        AppPanelEmptyCard(text: "Loading target data...")
                    } else {
                        AppPanelEmptyCard(text: "No target data yet.")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task(id: gameID) {
            await store.ensureLeagueTargetsLoaded()
        }
    }

    @ViewBuilder
    private func statRow(_ label: String, _ value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(color)
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private func wheelProgressSummary(taskProgress: [StudyTaskKind: Int]) -> String {
        let ordered = StudyTaskKind.allCases.map { task in
            let label: String
            switch task {
            case .playfield: label = "Playfield"
            case .rulesheet: label = "Rules"
            case .tutorialVideo: label = "Tutorial"
            case .gameplayVideo: label = "Gameplay"
            case .practice: label = "Practice"
            }
            return "\(label) \(taskProgress[task] ?? 0)%"
        }
        return ordered.joined(separator: "  •  ")
    }

    private struct PracticeGameScoreStats {
        let high: Double
        let low: Double
        let mean: Double
        let median: Double
        let stdev: Double
    }

    private func scoreStats(for gameID: String) -> PracticeGameScoreStats? {
        let values = store.recentScores(for: gameID, limit: 10_000).map(\.score).sorted()
        guard !values.isEmpty else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let median: Double
        if values.count % 2 == 0 {
            let upper = values.count / 2
            median = (values[upper - 1] + values[upper]) / 2
        } else {
            median = values[values.count / 2]
        }
        let variance = values.reduce(0) { partial, value in
            let delta = value - mean
            return partial + (delta * delta)
        } / Double(values.count)

        return PracticeGameScoreStats(
            high: values.last ?? mean,
            low: values.first ?? mean,
            mean: mean,
            median: median,
            stdev: variance.squareRoot()
        )
    }

    private func formatScore(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    private func nextAction(gameID: String) -> String? {
        let rows = store.gameTaskSummary(for: gameID)
        if let missing = rows.first(where: { $0.count == 0 }) {
            return "Start with \(missing.task.label.lowercased()) for this game."
        }

        let stale = rows.compactMap { row -> (StudyTaskKind, Int)? in
            guard let ts = row.lastTimestamp else { return nil }
            let days = Calendar.current.dateComponents([.day], from: ts, to: Date()).day ?? 0
            return (row.task, days)
        }
        .max(by: { $0.1 < $1.1 })

        if let stale, stale.1 >= 14 {
            return "Refresh \(stale.0.label.lowercased()) - last update was \(stale.1) days ago."
        }

        return "Continue practice and add a fresh score to track trend changes."
    }

    private func alertColor(_ severity: PracticeDashboardAlert.Severity) -> Color {
        switch severity {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .caution:
            return .yellow
        }
    }
}

private struct GameInputShortcut: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}
