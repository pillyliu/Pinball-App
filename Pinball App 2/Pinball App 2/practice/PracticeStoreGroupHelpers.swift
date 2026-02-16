import Foundation

extension PracticeStore {
    @discardableResult
    func createGroup(
        name: String,
        gameIDs: [String],
        type: GroupType = .custom,
        isActive: Bool = true,
        isPriority: Bool = false,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let group = CustomGameGroup(
            name: trimmed,
            gameIDs: uniqueGameIDsPreservingOrder(gameIDs),
            type: type,
            isActive: isActive,
            isPriority: isPriority,
            startDate: startDate,
            endDate: endDate
        )

        if isPriority {
            for idx in state.customGroups.indices {
                state.customGroups[idx].isPriority = false
            }
        }
        state.customGroups.append(group)
        if state.practiceSettings.selectedGroupID == nil {
            state.practiceSettings.selectedGroupID = group.id
        }
        saveState()
        return group.id
    }

    func applyBankTemplate(bank: Int, into groupName: String) {
        let gameIDs = games.filter { $0.bank == bank }.map(\.id)
        createGroup(
            name: groupName.isEmpty ? "Bank \(bank) Focus" : groupName,
            gameIDs: gameIDs,
            type: .bank
        )
    }

    func setSelectedGroup(id: UUID?) {
        state.practiceSettings.selectedGroupID = id
        saveState()
    }

    func selectedGroup() -> CustomGameGroup? {
        if let selected = state.practiceSettings.selectedGroupID,
           let exact = state.customGroups.first(where: { $0.id == selected }) {
            return exact
        }

        if let priority = state.customGroups.first(where: { $0.isActive && $0.isPriority }) {
            return priority
        }

        if let active = state.customGroups.first(where: { $0.isActive }) {
            return active
        }

        return state.customGroups.first
    }

    func updateGroup(
        id: UUID,
        name: String? = nil,
        gameIDs: [String]? = nil,
        type: GroupType? = nil,
        isActive: Bool? = nil,
        isPriority: Bool? = nil,
        replaceStartDate: Bool = false,
        startDate: Date? = nil,
        replaceEndDate: Bool = false,
        endDate: Date? = nil
    ) {
        guard let index = state.customGroups.firstIndex(where: { $0.id == id }) else { return }
        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                state.customGroups[index].name = trimmed
            }
        }
        if let gameIDs {
            state.customGroups[index].gameIDs = uniqueGameIDsPreservingOrder(gameIDs)
        }
        if let type {
            state.customGroups[index].type = type
        }
        if let isActive {
            state.customGroups[index].isActive = isActive
        }
        if let isPriority {
            if isPriority {
                for idx in state.customGroups.indices {
                    state.customGroups[idx].isPriority = (state.customGroups[idx].id == id)
                }
            } else {
                state.customGroups[index].isPriority = false
            }
        }
        if replaceStartDate {
            state.customGroups[index].startDate = startDate
        }
        if replaceEndDate {
            state.customGroups[index].endDate = endDate
        }
        saveState()
    }

    func deleteGroup(id: UUID) {
        state.customGroups.removeAll { $0.id == id }
        if state.practiceSettings.selectedGroupID == id {
            state.practiceSettings.selectedGroupID = state.customGroups.first?.id
        }
        saveState()
    }

    func reorderGroups(fromOffsets: IndexSet, toOffset: Int) {
        var reordered = state.customGroups
        let sortedOffsets = fromOffsets.sorted()
        let moving = sortedOffsets.map { reordered[$0] }
        for index in sortedOffsets.reversed() {
            reordered.remove(at: index)
        }

        let removedBeforeDestination = sortedOffsets.filter { $0 < toOffset }.count
        let adjustedDestination = toOffset - removedBeforeDestination
        let destination = max(0, min(adjustedDestination, reordered.count))
        reordered.insert(contentsOf: moving, at: destination)
        state.customGroups = reordered
        saveState()
    }

    func removeGame(_ gameID: String, fromGroup groupID: UUID) {
        guard let index = state.customGroups.firstIndex(where: { $0.id == groupID }) else { return }
        state.customGroups[index].gameIDs.removeAll { $0 == gameID }
        saveState()
    }

    func groupGames(for group: CustomGameGroup) -> [PinballGame] {
        let byID = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
        return group.gameIDs.compactMap { byID[$0] }
    }

    func groupProgress(for group: CustomGameGroup) -> [GroupProgressSnapshot] {
        groupGames(for: group).map { game in
            let progress = Dictionary(
                uniqueKeysWithValues: StudyTaskKind.allCases.map { task in
                    (task, latestTaskProgress(gameID: game.id, task: task))
                }
            )
            return GroupProgressSnapshot(game: game, taskProgress: progress)
        }
    }

    func recommendedGame(in group: CustomGameGroup) -> PinballGame? {
        let groupIDs = Set(group.gameIDs)
        return games
            .filter { groupIDs.contains($0.id) }
            .sorted { focusPriority(for: $0.id) > focusPriority(for: $1.id) }
            .first
    }

    func groupDashboardScore(for group: CustomGameGroup) -> GroupDashboardScore {
        let groupGames = groupGames(for: group)
        guard !groupGames.isEmpty else {
            return GroupDashboardScore(
                completionAverage: 0,
                staleGameCount: 0,
                weakerGameCount: 0,
                recommendedFirst: nil
            )
        }

        let completionValues = groupGames.map { studyCompletionPercent(for: $0.id) }
        let completionAverage = Int((Double(completionValues.reduce(0, +)) / Double(completionValues.count)).rounded())

        let staleGameCount = groupGames.filter { game in
            guard let ts = taskLastTimestamp(gameID: game.id, task: .practice) else { return true }
            let days = Calendar.current.dateComponents([.day], from: ts, to: Date()).day ?? 0
            return days >= 14
        }.count

        let weakerGameCount = groupGames.filter { game in
            guard let summary = scoreSummary(for: game.id), summary.median > 0 else { return true }
            let spread = (summary.p75 - summary.floor) / summary.median
            return spread >= 0.6
        }.count

        return GroupDashboardScore(
            completionAverage: completionAverage,
            staleGameCount: staleGameCount,
            weakerGameCount: weakerGameCount,
            recommendedFirst: recommendedGame(in: group)
        )
    }

    func uniqueGameIDsPreservingOrder(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for id in ids {
            guard !id.isEmpty, !seen.contains(id) else { continue }
            seen.insert(id)
            ordered.append(id)
        }
        return ordered
    }
}
