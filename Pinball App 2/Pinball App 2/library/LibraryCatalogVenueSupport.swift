import Foundation

func catalogCuratedOverride(
    practiceIdentity: String?,
    opdbGroupID: String?,
    opdbID: String? = nil,
    overridesByKey: [String: LegacyCuratedOverride]
) -> LegacyCuratedOverride? {
    var candidateKeys: [String] = []

    func appendCandidateKey(_ value: String?) {
        guard let normalized = catalogNormalizedOptionalString(value),
              !candidateKeys.contains(normalized) else {
            return
        }
        candidateKeys.append(normalized)
    }

    appendCandidateKey(opdbID)
    appendCandidateKey(practiceIdentity)
    appendCandidateKey(opdbGroupID)

    for key in candidateKeys {
        if let override = overridesByKey[key] {
            return override
        }
    }
    return nil
}

func buildCAFLibraryPayload(
    machines: [CatalogMachineRecord],
    importedSources: [PinballImportedSourceRecord],
    rulesheetLinksByPracticeIdentity: [String: [CatalogRulesheetLinkRecord]],
    videoLinksByPracticeIdentity: [String: [CatalogVideoLinkRecord]],
    curatedOverridesByKey: [String: LegacyCuratedOverride],
    venueMetadataOverlays: VenueMetadataOverlayIndex
) -> PinballLibraryPayload {
    guard !importedSources.isEmpty else {
        return PinballLibraryPayload(games: [], sources: [])
    }

    let machineByPracticeIdentity = Dictionary(grouping: machines, by: \.practiceIdentity)
    let machineByOPDBID = Dictionary(uniqueKeysWithValues: machines.compactMap { machine in
        catalogNormalizedOptionalString(machine.opdbMachineID).map { ($0, machine) }
    })

    var resolvedSources: [PinballLibrarySource] = []
    var resolvedGames: [PinballGame] = []

    for importedSource in importedSources {
        resolvedSources.append(
            PinballLibrarySource(id: importedSource.id, name: importedSource.name, type: importedSource.type)
        )

        switch importedSource.type {
        case .manufacturer:
            let groupedMachines = Dictionary(
                grouping: machines.filter { $0.manufacturerID == importedSource.providerSourceID },
                by: \.practiceIdentity
            )
            let sourceMachines = groupedMachines.values.compactMap { group in
                group.min(by: catalogPreferredManufacturerMachine)
            }
            .sorted { lhs, rhs in
                let leftYear = lhs.year ?? Int.max
                let rightYear = rhs.year ?? Int.max
                if leftYear != rightYear { return leftYear < rightYear }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            resolvedGames.append(contentsOf: sourceMachines.map { machine in
                resolveImportedGame(
                    machine: machine,
                    source: importedSource,
                    manufacturerByID: [:],
                    curatedOverride: catalogCuratedOverride(
                        practiceIdentity: machine.practiceIdentity,
                        opdbGroupID: machine.opdbGroupID,
                        opdbID: machine.opdbMachineID,
                        overridesByKey: curatedOverridesByKey
                    ),
                    opdbRulesheets: rulesheetLinksByPracticeIdentity[machine.practiceIdentity] ?? [],
                    opdbVideos: videoLinksByPracticeIdentity[machine.practiceIdentity] ?? [],
                    venueMetadata: nil
                )
            })
        case .venue, .tournament:
            let sourceMachines = importedSource.machineIDs.compactMap { requestedMachineID -> (String, CatalogMachineRecord)? in
                guard let machine = catalogPreferredMachineForSourceLookup(
                    requestedMachineID: requestedMachineID,
                    machineByOPDBID: machineByOPDBID,
                    machineByPracticeIdentity: machineByPracticeIdentity
                ) else {
                    return nil
                }
                return (requestedMachineID, machine)
            }

            resolvedGames.append(contentsOf: sourceMachines.map { requestedOpdbID, machine in
                resolveImportedGame(
                    machine: machine,
                    source: importedSource,
                    manufacturerByID: [:],
                    curatedOverride: catalogCuratedOverride(
                        practiceIdentity: machine.practiceIdentity,
                        opdbGroupID: machine.opdbGroupID,
                        opdbID: requestedOpdbID,
                        overridesByKey: curatedOverridesByKey
                    ),
                    opdbRulesheets: rulesheetLinksByPracticeIdentity[machine.practiceIdentity] ?? [],
                    opdbVideos: videoLinksByPracticeIdentity[machine.practiceIdentity] ?? [],
                    venueMetadata: importedSource.type == .venue
                        ? resolvedImportedVenueMetadata(
                            sourceID: importedSource.id,
                            requestedOpdbID: requestedOpdbID,
                            machine: machine,
                            overlays: venueMetadataOverlays
                        )
                        : nil
                )
            })
        case .category:
            continue
        }
    }

    return PinballLibraryPayload(
        games: resolvedGames,
        sources: catalogDedupedSources(resolvedSources)
    )
}

func buildCAFLibraryExtraction(
    opdbExportData: Data,
    practiceIdentityCurationsData: Data?,
    rulesheetAssetsData: Data?,
    videoAssetsData: Data?,
    playfieldAssetsData: Data?,
    gameinfoAssetsData: Data?,
    importedSources: [PinballImportedSourceRecord],
    venueMetadataOverlays: VenueMetadataOverlayIndex,
    filterBySourceState: Bool
) throws -> LibraryExtraction {
    let machines = try decodeOPDBExportCatalogMachines(data: opdbExportData, practiceIdentityCurationsData: practiceIdentityCurationsData)
    let payload = buildCAFLibraryPayload(
        machines: machines,
        importedSources: importedSources,
        rulesheetLinksByPracticeIdentity: buildCAFGroupedRulesheetLinks(data: rulesheetAssetsData),
        videoLinksByPracticeIdentity: buildCAFGroupedVideoLinks(data: videoAssetsData),
        curatedOverridesByKey: buildCAFOverrides(
            playfieldData: playfieldAssetsData,
            gameinfoData: gameinfoAssetsData
        ),
        venueMetadataOverlays: venueMetadataOverlays
    )
    let state = PinballLibrarySourceStateStore.synchronize(with: payload.sources)
    return libraryExtraction(payload: payload, state: state, filterBySourceState: filterBySourceState)
}
