import Foundation

extension PracticeStore {
    @discardableResult
    func createGroup(
        name: String,
        gameIDs: [String],
        type: GroupType = .custom,
        isActive: Bool = true,
        isArchived: Bool = false,
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
            isArchived: isArchived,
            isPriority: isPriority,
            startDate: startDate ?? Date(),
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
        let gameIDs = games.filter { $0.bank == bank }.map(\.canonicalPracticeKey)
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

        if let priority = state.customGroups.first(where: { !$0.isArchived && $0.isActive && $0.isPriority }) {
            return priority
        }

        if let active = state.customGroups.first(where: { !$0.isArchived && $0.isActive }) {
            return active
        }

        return state.customGroups.first(where: { !$0.isArchived }) ?? state.customGroups.first
    }

    func updateGroup(
        id: UUID,
        name: String? = nil,
        gameIDs: [String]? = nil,
        type: GroupType? = nil,
        isActive: Bool? = nil,
        isArchived: Bool? = nil,
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
        if let isArchived {
            state.customGroups[index].isArchived = isArchived
            if isArchived {
                state.customGroups[index].isActive = false
                state.customGroups[index].isPriority = false
            }
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

    @discardableResult
    func autoArchiveExpiredGroupsIfNeeded(now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        var changed = false
        for index in state.customGroups.indices {
            let group = state.customGroups[index]
            guard !group.isArchived, let endDate = group.endDate else { continue }
            guard let archiveDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) else {
                continue
            }
            if now >= archiveDate {
                state.customGroups[index].isArchived = true
                state.customGroups[index].isActive = false
                state.customGroups[index].isPriority = false
                changed = true
            }
        }
        if changed {
            saveState()
        }
        return changed
    }

    func activeGroup(for gameID: String) -> CustomGameGroup? {
        let gameID = canonicalPracticeGameID(gameID)
        let matches = state.customGroups.enumerated().compactMap { index, group -> (Int, CustomGameGroup)? in
            guard !group.isArchived, group.isActive, group.gameIDs.contains(gameID) else { return nil }
            return (index, group)
        }
        guard !matches.isEmpty else { return nil }
        if let priority = matches.first(where: { $0.1.isPriority }) {
            return priority.1
        }
        return matches.first?.1
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
        let canonical = canonicalPracticeGameID(gameID)
        state.customGroups[index].gameIDs.removeAll { canonicalPracticeGameID($0) == canonical }
        saveState()
    }

    func groupGames(for group: CustomGameGroup) -> [PinballGame] {
        let byPractice = Dictionary(uniqueKeysWithValues: practiceGamesDeduped().map { ($0.canonicalPracticeKey, $0) })
        return group.gameIDs.compactMap { byPractice[canonicalPracticeGameID($0)] }
    }

    func groupProgress(for group: CustomGameGroup) -> [GroupProgressSnapshot] {
        groupGames(for: group).map { game in
            let progress = Dictionary(
                uniqueKeysWithValues: StudyTaskKind.allCases.map { task in
                    (
                            task,
                            latestTaskProgress(
                            gameID: game.canonicalPracticeKey,
                            task: task,
                            startDate: group.startDate,
                            endDate: group.endDate
                        )
                    )
                }
            )
            return GroupProgressSnapshot(game: game, taskProgress: progress)
        }
    }

    func recommendedGame(in group: CustomGameGroup) -> PinballGame? {
        let groupIDs = Set(group.gameIDs.map { canonicalPracticeGameID($0) })
        return practiceGamesDeduped()
            .filter { groupIDs.contains($0.canonicalPracticeKey) }
            .sorted {
                focusPriority(for: $0.canonicalPracticeKey, startDate: group.startDate, endDate: group.endDate) >
                    focusPriority(for: $1.canonicalPracticeKey, startDate: group.startDate, endDate: group.endDate)
            }
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

        let completionValues = groupGames.map {
            studyCompletionPercent(for: $0.canonicalPracticeKey, startDate: group.startDate, endDate: group.endDate)
        }
        let completionAverage = Int((Double(completionValues.reduce(0, +)) / Double(completionValues.count)).rounded())

        let staleGameCount = groupGames.filter { game in
            guard let ts = taskLastTimestamp(
                gameID: game.canonicalPracticeKey,
                task: .practice,
                startDate: group.startDate,
                endDate: group.endDate
            ) else { return true }
            let days = Calendar.current.dateComponents([.day], from: ts, to: Date()).day ?? 0
            return days >= 14
        }.count

        let weakerGameCount = groupGames.filter { game in
            guard let summary = scoreSummary(for: game.canonicalPracticeKey), summary.median > 0 else { return true }
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
            let canonical = canonicalPracticeGameID(id)
            guard !canonical.isEmpty, !seen.contains(canonical) else { continue }
            seen.insert(canonical)
            ordered.append(canonical)
        }
        return ordered
    }
}
