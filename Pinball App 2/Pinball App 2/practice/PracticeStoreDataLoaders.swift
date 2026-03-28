import Foundation

struct PracticeLibraryLoadResult {
    let games: [PinballGame]
    let allGames: [PinballGame]
    let sources: [PinballLibrarySource]
    let defaultSourceID: String?
    let isFullLibraryScope: Bool
}

extension PracticeStore {
    private static let preferredLibrarySourceDefaultsKey = "preferred-library-source-id"

    func loadGames() async {
        let initialLibraryState = await loadInitialLibraryState()
        applyLibraryState(initialLibraryState)
        saveHomeBootstrapSnapshotIfNeeded()
    }

    func loadInitialLibraryState() async -> PracticeLibraryLoadResult {
        isLoadingGames = true
        defer {
            isLoadingGames = false
        }

        return await PinballPerformanceTrace.measure("PracticeInitialLibraryLoad") {
            do {
                return try await loadPracticeLibraryState(fullLibraryScope: false)
            } catch {
                lastErrorMessage = "Failed to load library for practice upgrade: \(error.localizedDescription)"
                return PracticeLibraryLoadResult(
                    games: [],
                    allGames: [],
                    sources: [],
                    defaultSourceID: nil,
                    isFullLibraryScope: false
                )
            }
        }
    }

    func ensureAllLibraryGamesLoaded() async {
        guard !didLoadAllLibraryGames, !isLoadingAllLibraryGames else { return }

        isLoadingAllLibraryGames = true
        defer { isLoadingAllLibraryGames = false }

        await PinballPerformanceTrace.measure("PracticeFullLibraryHydration") {
            do {
                let fullState = try await loadPracticeLibraryState(fullLibraryScope: true)
                applyLibraryState(fullState)
                saveHomeBootstrapSnapshotIfNeeded()
            } catch {
                lastErrorMessage = "Failed to load full practice library: \(error.localizedDescription)"
            }
        }
    }

    func ensureSearchCatalogGamesLoaded() async {
        if !searchCatalogGames.isEmpty || isLoadingSearchCatalog {
            return
        }

        isLoadingSearchCatalog = true
        defer { isLoadingSearchCatalog = false }

        await PinballPerformanceTrace.measure("PracticeSearchCatalogLoad") {
            do {
                searchCatalogGames = try await loadPracticeCatalogGames()
                saveHomeBootstrapSnapshotIfNeeded()
            } catch {
                if searchCatalogGames.isEmpty {
                    lastErrorMessage = "Failed to load practice search catalog: \(error.localizedDescription)"
                }
            }
        }
    }

    func ensureLeagueCatalogGamesLoaded() async {
        guard leagueCatalogGames.isEmpty, !isLoadingLeagueCatalogGames else { return }

        isLoadingLeagueCatalogGames = true
        defer { isLoadingLeagueCatalogGames = false }

        do {
            leagueCatalogGames = try await PinballPerformanceTrace.measure("PracticeLeagueCatalogLoad") {
                try await loadPracticeCatalogGames()
            }
        } catch {
            leagueCatalogGames = []
        }
    }

    func ensureSearchCatalogGamesLoadedForStoredReferencesIfNeeded() async {
        guard shouldLoadSearchCatalogForStoredReferences else { return }
        await ensureSearchCatalogGamesLoaded()
    }

    func ensureBankTemplateGamesLoadedForStoredReferencesIfNeeded() async {
        guard shouldLoadBankTemplateGamesForStoredReferences else { return }
        await ensureBankTemplateGamesLoaded()
    }

    func ensureAllLibraryGamesLoadedForStoredReferencesIfNeeded() async {
        guard shouldLoadAllLibraryGamesForStoredReferences else { return }
        await ensureAllLibraryGamesLoaded()
    }

    func ensureBankTemplateGamesLoaded() async {
        guard bankTemplateGames.isEmpty, !isLoadingBankTemplateGames else { return }

        isLoadingBankTemplateGames = true
        defer { isLoadingBankTemplateGames = false }

        await PinballPerformanceTrace.measure("PracticeBankTemplateLoad") {
            do {
                bankTemplateGames = try await loadPracticeAvenueBankTemplateGames()
                saveHomeBootstrapSnapshotIfNeeded()
            } catch {
                bankTemplateGames = []
                lastErrorMessage = "Failed to load practice bank templates: \(error.localizedDescription)"
            }
        }
    }

    func ensureLeagueTargetsLoaded() async {
        guard !didLoadLeagueTargets, !isLoadingLeagueTargets else { return }

        isLoadingLeagueTargets = true
        defer { isLoadingLeagueTargets = false }

        await loadLeagueTargets()
        didLoadLeagueTargets = true
    }

    func loadLeagueTargets() async {
        await PinballPerformanceTrace.measure("PracticeLeagueTargetsLoad") {
            do {
                let resolvedCached = try await PinballDataCache.shared.loadText(path: Self.resolvedLeagueTargetsPath, allowMissing: true)
                if let resolvedText = resolvedCached.text, !resolvedText.isEmpty {
                    let resolvedRecords = parseResolvedLeagueTargets(text: resolvedText)
                    if !resolvedRecords.isEmpty {
                        leagueTargetsByPracticeIdentity = resolvedLeagueTargetScoresByPracticeIdentity(records: resolvedRecords)
                        leagueTargetsByNormalizedMachine = [:]
                        return
                    }
                }

                let cached = try await PinballDataCache.shared.loadText(path: Self.leagueTargetsPath, allowMissing: true)
                guard let text = cached.text, !text.isEmpty else {
                    leagueTargetsByPracticeIdentity = [:]
                    leagueTargetsByNormalizedMachine = [:]
                    return
                }
                leagueTargetsByPracticeIdentity = [:]
                leagueTargetsByNormalizedMachine = parseLeagueTargets(text: text)
            } catch {
                leagueTargetsByPracticeIdentity = [:]
                leagueTargetsByNormalizedMachine = [:]
            }
        }
    }

    func parseLeagueTargets(text: String) -> [String: LeagueTargetScores] {
        let table = parseCSVRows(text)
        guard let header = table.first else { return [:] }

        let headers = header.map(normalizeCSVHeader)
        guard let gameIndex = headers.firstIndex(of: "game"),
              let secondIndex = headers.firstIndex(of: "second_highest_avg"),
              let fourthIndex = headers.firstIndex(of: "fourth_highest_avg"),
              let eighthIndex = headers.firstIndex(of: "eighth_highest_avg") else {
            return [:]
        }

        var targets: [String: LeagueTargetScores] = [:]
        for row in table.dropFirst() {
            guard row.indices.contains(gameIndex),
                  row.indices.contains(secondIndex),
                  row.indices.contains(fourthIndex),
                  row.indices.contains(eighthIndex) else {
                continue
            }

            let game = row[gameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !game.isEmpty else { continue }

            let second = row[secondIndex].replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let fourth = row[fourthIndex].replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let eighth = row[eighthIndex].replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let great = Double(second), let main = Double(fourth), let floor = Double(eighth) else { continue }

            targets[LibraryGameLookup.normalizeMachineName(game)] = LeagueTargetScores(great: great, main: main, floor: floor)
        }

        return targets
    }

    func selectPracticeLibrarySource(id sourceID: String?) {
        let trimmed = sourceID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let selectedSource = librarySources.first { $0.id == trimmed }
        let pool = allLibraryGames.isEmpty ? games : allLibraryGames
        if let selectedSource {
            games = pool.filter { $0.sourceId == selectedSource.id }
            defaultPracticeSourceID = selectedSource.id
            UserDefaults.standard.set(selectedSource.id, forKey: Self.preferredLibrarySourceDefaultsKey)
            var state = PinballLibrarySourceStateStore.load()
            state.selectedSourceID = selectedSource.id
            PinballLibrarySourceStateStore.save(state)
        } else {
            games = pool
            defaultPracticeSourceID = nil
            UserDefaults.standard.removeObject(forKey: Self.preferredLibrarySourceDefaultsKey)
            var state = PinballLibrarySourceStateStore.load()
            state.selectedSourceID = nil
            PinballLibrarySourceStateStore.save(state)
        }
        saveHomeBootstrapSnapshotIfNeeded()
    }

    func applyLibraryState(_ state: PracticeLibraryLoadResult) {
        games = state.games
        allLibraryGames = state.allGames
        librarySources = state.sources
        defaultPracticeSourceID = state.defaultSourceID
        didLoadAllLibraryGames = state.isFullLibraryScope
        if let selectedSourceID = state.defaultSourceID {
            UserDefaults.standard.set(selectedSourceID, forKey: Self.preferredLibrarySourceDefaultsKey)
            var sourceState = PinballLibrarySourceStateStore.load()
            sourceState.selectedSourceID = selectedSourceID
            PinballLibrarySourceStateStore.save(sourceState)
        }
    }

    private func loadPracticeLibraryState(fullLibraryScope: Bool) async throws -> PracticeLibraryLoadResult {
        let extraction = try await (fullLibraryScope ? loadFullLibraryExtraction() : loadLibraryExtraction())
        let payload = extraction.payload
        let savedSourceID = UserDefaults.standard.string(forKey: Self.preferredLibrarySourceDefaultsKey)
        let preferredCandidates = [savedSourceID, extraction.state.selectedSourceID]
        let selectedSource =
            preferredCandidates.compactMap { $0 }.first(where: { id in payload.sources.contains(where: { $0.id == id }) })
                .flatMap { id in payload.sources.first(where: { $0.id == id }) }
            ?? payload.sources.first

        return PracticeLibraryLoadResult(
            games: selectedSource.map { source in
                payload.games.filter { $0.sourceId == source.id }
            } ?? payload.games,
            allGames: payload.games,
            sources: payload.sources,
            defaultSourceID: selectedSource?.id,
            isFullLibraryScope: fullLibraryScope
        )
    }

    private var shouldLoadAllLibraryGamesForStoredReferences: Bool {
        guard !didLoadAllLibraryGames else { return false }
        return storedPracticeReferenceIDs.contains(where: needsAllLibraryGamesForStoredReference)
    }

    private var shouldLoadBankTemplateGamesForStoredReferences: Bool {
        guard bankTemplateGames.isEmpty else { return false }
        return storedPracticeReferenceIDs.contains(where: needsBankTemplateGamesForStoredReference)
    }

    private var shouldLoadSearchCatalogForStoredReferences: Bool {
        guard searchCatalogGames.isEmpty else { return false }
        return storedPracticeReferenceIDs.contains(where: needsSearchCatalogForStoredReference)
    }

    private var storedPracticeReferenceIDs: [String] {
        let defaults = UserDefaults.standard
        var ids: [String] = []
        ids += state.studyEvents.map(\.gameID)
        ids += state.videoProgressEntries.map(\.gameID)
        ids += state.scoreEntries.map(\.gameID)
        ids += state.noteEntries.map(\.gameID)
        ids += state.journalEntries.map(\.gameID)
        ids += state.customGroups.flatMap(\.gameIDs)
        ids += Array(state.rulesheetResumeOffsets.keys)
        ids += Array(state.videoResumeHints.keys)
        ids += Array(state.gameSummaryNotes.keys)
        ids += Self.practicePreferenceGameIDKeys.compactMap { defaults.string(forKey: $0) }
        return ids
    }

    private func needsSearchCatalogForStoredReference(_ raw: String) -> Bool {
        let parsed = parseSourceScopedPracticeGameID(raw)
        let trimmed = parsed.gameID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, parsed.sourceID == nil else { return false }
        return gameForAnyID(trimmed) == nil
    }

    private func needsBankTemplateGamesForStoredReference(_ raw: String) -> Bool {
        let parsed = parseSourceScopedPracticeGameID(raw)
        let sourceID = canonicalLibrarySourceID(parsed.sourceID)
        guard sourceID == pmAvenueLibrarySourceID else { return false }
        return gameForAnyID(raw) == nil
    }

    private func needsAllLibraryGamesForStoredReference(_ raw: String) -> Bool {
        let parsed = parseSourceScopedPracticeGameID(raw)
        let sourceID = canonicalLibrarySourceID(parsed.sourceID)
        guard let sourceID, sourceID != pmAvenueLibrarySourceID else { return false }
        return gameForAnyID(raw) == nil
    }
}

private struct PracticeVenueLayoutAssetsRoot: Decodable {
    let records: [PracticeVenueLayoutAssetRecord]
}

private struct PracticeVenueLayoutAssetRecord: Decodable {
    let sourceId: String
    let practiceIdentity: String?
    let opdbId: String
    let area: String?
    let areaOrder: Int?
    let groupNumber: Int?
    let position: Int?
    let bank: Int?
}

private func loadPracticeAvenueBankTemplateGames() async throws -> [PinballGame] {
    let practiceIdentityCurationsData = try await loadHostedOrCachedPinballJSONData(
        path: hostedPracticeIdentityCurationsPath,
        allowMissing: true
    )
    guard let opdbExportData = try await loadHostedOrCachedPinballJSONData(
        path: hostedOPDBExportPath,
        allowMissing: true
    ),
    let venueLayoutData = try await loadHostedOrCachedPinballJSONData(
        path: hostedVenueLayoutAssetsPath,
        allowMissing: true
    ),
    !opdbExportData.isEmpty,
    !venueLayoutData.isEmpty else {
        return []
    }

    let machines = try decodeOPDBExportCatalogMachines(
        data: opdbExportData,
        practiceIdentityCurationsData: practiceIdentityCurationsData
    )
    let layoutRoot = try JSONDecoder().decode(PracticeVenueLayoutAssetsRoot.self, from: venueLayoutData)

    let avenueRecords = layoutRoot.records
        .filter { canonicalLibrarySourceID($0.sourceId) == pmAvenueLibrarySourceID }
        .filter { ($0.bank ?? 0) > 0 }

    let machinesByOPDBID = Dictionary(uniqueKeysWithValues: machines.compactMap { machine -> (String, CatalogMachineRecord)? in
        guard let opdbID = machine.opdbMachineID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !opdbID.isEmpty else {
            return nil
        }
        return (opdbID, machine)
    })
    let machinesByPracticeIdentity = Dictionary(grouping: machines, by: \.practiceIdentity)

    var seen = Set<String>()
    let sortedRecords = avenueRecords.sorted { lhs, rhs in
        let lhsBank = lhs.bank ?? Int.max
        let rhsBank = rhs.bank ?? Int.max
        if lhsBank != rhsBank { return lhsBank < rhsBank }
        let lhsGroup = lhs.groupNumber ?? Int.max
        let rhsGroup = rhs.groupNumber ?? Int.max
        if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }
        let lhsPosition = lhs.position ?? Int.max
        let rhsPosition = rhs.position ?? Int.max
        if lhsPosition != rhsPosition { return lhsPosition < rhsPosition }
        return lhs.opdbId.localizedCaseInsensitiveCompare(rhs.opdbId) == .orderedAscending
    }

    return sortedRecords.compactMap { record in
        guard seen.insert(record.opdbId).inserted else { return nil }
        let machine =
            machinesByOPDBID[record.opdbId] ??
            record.practiceIdentity.flatMap { machinesByPracticeIdentity[$0]?.first }
        guard let machine else { return nil }

        let opdbPlayfieldImageURL = catalogNormalizedOptionalString(
            machine.playfieldImage?.largeURL ?? machine.playfieldImage?.mediumURL
        )
        let resolved = ResolvedCatalogRecord(
            sourceID: pmAvenueLibrarySourceID,
            sourceName: "The Avenue Cafe",
            sourceType: .venue,
            area: catalogNormalizedOptionalString(record.area),
            areaOrder: record.areaOrder,
            groupNumber: record.groupNumber,
            position: record.position,
            bank: record.bank,
            name: machine.name,
            variant: catalogNormalizedOptionalString(machine.variant),
            manufacturer: catalogNormalizedOptionalString(machine.manufacturerName),
            year: machine.year,
            slug: catalogNormalizedOptionalString(machine.slug) ?? machine.practiceIdentity,
            opdbID: catalogNormalizedOptionalString(machine.opdbMachineID) ?? record.opdbId,
            opdbMachineID: catalogNormalizedOptionalString(machine.opdbMachineID) ?? record.opdbId,
            practiceIdentity: record.practiceIdentity ?? machine.practiceIdentity,
            opdbName: machine.opdbName,
            opdbCommonName: machine.opdbCommonName,
            opdbShortname: machine.opdbShortname,
            opdbDescription: machine.opdbDescription,
            opdbType: machine.opdbType,
            opdbDisplay: machine.opdbDisplay,
            opdbPlayerCount: machine.opdbPlayerCount,
            opdbManufactureDate: machine.opdbManufactureDate,
            opdbIpdbID: machine.opdbIpdbID,
            opdbGroupShortname: machine.opdbGroupShortname,
            opdbGroupDescription: machine.opdbGroupDescription,
            primaryImageURL: catalogNormalizedOptionalString(machine.primaryImage?.mediumURL),
            primaryImageLargeURL: catalogNormalizedOptionalString(machine.primaryImage?.largeURL),
            playfieldImageURL: opdbPlayfieldImageURL,
            alternatePlayfieldImageURL: nil,
            playfieldLocalPath: nil,
            playfieldSourceLabel: machine.playfieldImage != nil ? "Playfield (OPDB)" : nil,
            gameinfoLocalPath: nil,
            rulesheetLocalPath: nil,
            rulesheetURL: nil,
            rulesheetLinks: [],
            videos: []
        )
        return PinballGame(record: resolved)
    }
}
