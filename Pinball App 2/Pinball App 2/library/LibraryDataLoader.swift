import Foundation

private enum LibraryDataLoader {
    static let gameRoomLibrarySourceID = "venue--gameroom"
}

private struct GameRoomOPDBCatalogRoot: Decodable {
    struct Machine: Decodable {
        struct RemoteImageSet: Decodable {
            let mediumURL: String?
            let largeURL: String?

            enum CodingKeys: String, CodingKey {
                case mediumURL = "medium_url"
                case largeURL = "large_url"
            }
        }

        let practiceIdentity: String
        let opdbMachineID: String?
        let opdbGroupID: String?
        let name: String
        let variant: String?
        let year: Int?
        let primaryImage: RemoteImageSet?

        enum CodingKeys: String, CodingKey {
            case practiceIdentity = "practice_identity"
            case opdbMachineID = "opdb_machine_id"
            case opdbGroupID = "opdb_group_id"
            case name
            case variant
            case year
            case primaryImage = "primary_image"
        }
    }

    let machines: [Machine]
}

private struct GameRoomOPDBMediaRecord {
    let practiceIdentity: String
    let opdbMachineID: String?
    let opdbGroupID: String?
    let variant: String?
    let year: Int?
    let primaryMediumURL: String?
    let primaryLargeURL: String?
}

func loadLibraryExtraction() async throws -> LegacyCatalogExtraction {
    try await loadLibraryExtraction(filterBySourceState: true)
}

func loadFullLibraryExtraction() async throws -> LegacyCatalogExtraction {
    try await loadLibraryExtraction(filterBySourceState: false)
}

private func loadLibraryExtraction(filterBySourceState: Bool) async throws -> LegacyCatalogExtraction {
    do {
        let extraction = try await loadHostedLibraryExtraction(filterBySourceState: filterBySourceState)
        return augmentExtractionWithGameRoom(extraction)
    } catch {
        if let bundled = try loadBundledLibraryExtraction(filterBySourceState: filterBySourceState) {
            return augmentExtractionWithGameRoom(bundled)
        }
        let seedExtraction = try await LibrarySeedDatabase.shared.loadExtraction(filterBySourceState: filterBySourceState)
        return augmentExtractionWithGameRoom(seedExtraction)
    }
}

private func augmentExtractionWithGameRoom(_ extraction: LegacyCatalogExtraction) -> LegacyCatalogExtraction {
    let gameRoomData = loadGameRoomLibraryData(extractionGames: extraction.payload.games)
    let gameRoomSource = PinballLibrarySource(
        id: LibraryDataLoader.gameRoomLibrarySourceID,
        name: gameRoomData.venueName,
        type: .venue
    )
    let gameRoomGames = gameRoomData.games

    var sources = extraction.payload.sources.filter { $0.id != gameRoomSource.id }
    var games = extraction.payload.games.filter { $0.sourceId != gameRoomSource.id }

    guard !gameRoomGames.isEmpty else {
        return LegacyCatalogExtraction(
            payload: PinballLibraryPayload(games: games, sources: sources),
            state: extraction.state
        )
    }

    sources.append(gameRoomSource)
    games.append(contentsOf: gameRoomGames)

    return LegacyCatalogExtraction(
        payload: PinballLibraryPayload(games: games, sources: sources),
        state: extraction.state
    )
}

private func loadGameRoomLibraryData(extractionGames: [PinballGame]) -> (venueName: String, games: [PinballGame]) {
    let defaults = UserDefaults.standard
    guard let state = GameRoomStateCodec.loadFromDefaults(
        defaults,
        storageKey: GameRoomStore.storageKey,
        legacyStorageKey: GameRoomStore.legacyStorageKey
    ) else {
        return (GameRoomPersistedState.defaultVenueName, [])
    }
    let venueName = normalizedGameRoomVenueName(state.venueName)

    let areasByID = Dictionary(uniqueKeysWithValues: state.areas.map { ($0.id, $0) })
    let activeMachines = state.ownedMachines.filter { $0.status == .active || $0.status == .loaned }
    if activeMachines.isEmpty {
        return (venueName, [])
    }
    let opdbMediaIndex = loadGameRoomOPDBMediaIndex()

    let sortedMachines = activeMachines.sorted { lhs, rhs in
        let lhsArea = lhs.gameRoomAreaID.flatMap { areasByID[$0] }
        let rhsArea = rhs.gameRoomAreaID.flatMap { areasByID[$0] }

        let lhsAreaOrder = lhsArea?.areaOrder ?? Int.max
        let rhsAreaOrder = rhsArea?.areaOrder ?? Int.max
        if lhsAreaOrder != rhsAreaOrder { return lhsAreaOrder < rhsAreaOrder }

        let lhsAreaName = (lhsArea?.name ?? "").lowercased()
        let rhsAreaName = (rhsArea?.name ?? "").lowercased()
        if lhsAreaName != rhsAreaName { return lhsAreaName < rhsAreaName }

        let lhsGroup = lhs.groupNumber ?? Int.max
        let rhsGroup = rhs.groupNumber ?? Int.max
        if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }

        let lhsPosition = lhs.position ?? Int.max
        let rhsPosition = rhs.position ?? Int.max
        if lhsPosition != rhsPosition { return lhsPosition < rhsPosition }

        let lhsTitle = lhs.displayTitle.lowercased()
        let rhsTitle = rhs.displayTitle.lowercased()
        if lhsTitle != rhsTitle { return lhsTitle < rhsTitle }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    let gameRecords = sortedMachines.compactMap { machine -> PinballGame? in
        let area = machine.gameRoomAreaID.flatMap { areasByID[$0] }
        let template = bestTemplateGame(for: machine, from: extractionGames)
        let opdbMedia = bestOPDBMediaRecord(for: machine, from: opdbMediaIndex)
        let canonicalPracticeIdentity = machine.canonicalPracticeIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPracticeIdentity: String = {
            if let opdbPracticeIdentity = opdbMedia?.practiceIdentity.trimmingCharacters(in: .whitespacesAndNewlines),
               !opdbPracticeIdentity.isEmpty {
                return opdbPracticeIdentity
            }
            if let templatePracticeIdentity = template?.practiceIdentity?.trimmingCharacters(in: .whitespacesAndNewlines),
               !templatePracticeIdentity.isEmpty {
                return templatePracticeIdentity
            }
            return canonicalPracticeIdentity.isEmpty ? machine.catalogGameID : canonicalPracticeIdentity
        }()
        let resolvedName = machine.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (template?.name ?? machine.catalogGameID)
            : machine.displayTitle
        let normalizedSlug = slugForLibraryGame(
            title: resolvedName,
            fallback: normalizedPracticeIdentity.isEmpty ? machine.id.uuidString : normalizedPracticeIdentity
        )

        var row: [String: Any] = [
            "library_id": LibraryDataLoader.gameRoomLibrarySourceID,
            "library_name": venueName,
            "library_type": PinballLibrarySourceType.venue.rawValue,
            "name": resolvedName,
            "slug": normalizedSlug,
            "library_entry_id": "\(LibraryDataLoader.gameRoomLibrarySourceID)--\(machine.id.uuidString)",
            "practice_identity": normalizedPracticeIdentity
        ]

        if let areaName = area?.name, !areaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            row["area"] = areaName
        }
        if let areaOrder = area?.areaOrder {
            row["area_order"] = areaOrder
        }
        if let group = machine.groupNumber {
            row["group"] = group
        }
        if let position = machine.position {
            row["position"] = position
        }
        if let variant = machine.displayVariant, !variant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            row["variant"] = variant
        }
        if let manufacturer = machine.manufacturer, !manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            row["manufacturer"] = manufacturer
        }
        if let year = machine.year {
            row["year"] = year
        }
        if !machine.catalogGameID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            row["opdb_id"] = machine.catalogGameID
        }
        if let primaryImageURL = opdbMedia?.primaryMediumURL ?? template?.primaryImageUrl {
            row["primary_image_url"] = primaryImageURL
        }
        if let primaryImageLargeURL = opdbMedia?.primaryLargeURL ?? template?.primaryImageLargeUrl {
            row["primary_image_large_url"] = primaryImageLargeURL
        }
        if let playfieldImageURL = template?.playfieldImageUrl {
            row["playfield_image_url"] = playfieldImageURL
        }
        if let template {
            if let sourceLabel = resolvedPlayfieldSourceLabel(for: template) {
                row["playfield_source_label"] = sourceLabel
            }
        }
        if let rulesheetURL = template?.rulesheetUrl {
            row["rulesheet_url"] = rulesheetURL
        }
        if let template, !template.rulesheetLinks.isEmpty {
            row["rulesheet_links"] = template.rulesheetLinks.map { link in
                [
                    "label": link.label,
                    "url": link.url
                ]
            }
        }
        if let template, !template.videos.isEmpty {
            row["videos"] = template.videos.map { video in
                var payload: [String: Any] = [:]
                if let kind = video.kind {
                    payload["kind"] = kind
                }
                if let label = video.label {
                    payload["label"] = label
                }
                if let url = video.url {
                    payload["url"] = url
                }
                return payload
            }
        }
        if let template {
            var assets: [String: Any] = [:]
            if let playfieldLocalPath = template.playfieldLocalOriginal ?? template.playfieldLocal {
                assets["playfield_local_practice"] = playfieldLocalPath
            }
            if let rulesheetLocalPath = template.rulesheetLocal {
                assets["rulesheet_local_practice"] = rulesheetLocalPath
            }
            if let gameinfoLocalPath = template.gameinfoLocal {
                assets["gameinfo_local_practice"] = gameinfoLocalPath
            }
            if !assets.isEmpty {
                row["assets"] = assets
            }
        }

        guard let data = try? JSONSerialization.data(withJSONObject: row),
              let decoded = try? JSONDecoder().decode(PinballGame.self, from: data) else {
            return nil
        }
        return decoded
    }

    return (venueName, gameRecords)
}

private func normalizedGameRoomVenueName(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? GameRoomPersistedState.defaultVenueName : trimmed
}

private func loadGameRoomOPDBMediaIndex() -> [String: [GameRoomOPDBMediaRecord]] {
    guard let data = try? loadBundledPinballData(path: hostedOPDBCatalogPath),
          !data.isEmpty,
          let root = try? JSONDecoder().decode(GameRoomOPDBCatalogRoot.self, from: data) else {
        return [:]
    }

    var index: [String: [GameRoomOPDBMediaRecord]] = [:]
    for machine in root.machines {
        let record = GameRoomOPDBMediaRecord(
            practiceIdentity: machine.practiceIdentity,
            opdbMachineID: machine.opdbMachineID,
            opdbGroupID: machine.opdbGroupID,
            variant: catalogResolvedVariantLabel(title: machine.name, explicitVariant: machine.variant),
            year: machine.year,
            primaryMediumURL: machine.primaryImage?.mediumURL,
            primaryLargeURL: machine.primaryImage?.largeURL
        )
        let keys = Set(
            [
                normalizedGameRoomID(machine.opdbGroupID),
                normalizedGameRoomID(machine.opdbMachineID),
                normalizedGameRoomID(machine.practiceIdentity)
            ]
            .compactMap { $0 }
        )
        for key in keys {
            index[key, default: []].append(record)
        }
    }
    return index
}

private func bestOPDBMediaRecord(
    for machine: OwnedMachine,
    from mediaIndex: [String: [GameRoomOPDBMediaRecord]]
) -> GameRoomOPDBMediaRecord? {
    let keys = Set(
        [
            normalizedGameRoomID(machine.catalogGameID),
            normalizedGroupFromOpdbID(machine.catalogGameID),
            normalizedGameRoomID(machine.canonicalPracticeIdentity)
        ]
        .compactMap { $0 }
    )
    let candidates = keys.flatMap { mediaIndex[$0] ?? [] }
    guard !candidates.isEmpty else { return nil }

    let normalizedMachineVariant = normalizedGameRoomVariant(machine.displayVariant)
    if let normalizedMachineVariant {
        let variantMatches = candidates
            .filter { opdbVariantMatchScore(recordVariant: $0.variant, requestedVariant: normalizedMachineVariant) > 0 }
            .sorted { lhs, rhs in
                let lhsScore = opdbVariantMatchScore(recordVariant: lhs.variant, requestedVariant: normalizedMachineVariant)
                let rhsScore = opdbVariantMatchScore(recordVariant: rhs.variant, requestedVariant: normalizedMachineVariant)
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                let lhsHasPrimary = opdbRecordHasPrimaryImage(lhs)
                let rhsHasPrimary = opdbRecordHasPrimaryImage(rhs)
                if lhsHasPrimary != rhsHasPrimary { return lhsHasPrimary }
                let lhsYear = lhs.year ?? Int.max
                let rhsYear = rhs.year ?? Int.max
                if lhsYear != rhsYear { return lhsYear < rhsYear }
                return lhs.practiceIdentity < rhs.practiceIdentity
            }
        if let withVariantArt = variantMatches.first(where: opdbRecordHasPrimaryImage) {
            return withVariantArt
        }
    }

    // Fallback ladder when variant art is unavailable: machine/group image with art, then best remaining candidate.
    if let withAnyArt = candidates
        .filter(opdbRecordHasPrimaryImage)
        .max(by: { lhs, rhs in
            let lhsScore = opdbMediaScore(lhs, machineVariant: nil)
            let rhsScore = opdbMediaScore(rhs, machineVariant: nil)
            if lhsScore != rhsScore { return lhsScore < rhsScore }
            let lhsYear = lhs.year ?? Int.max
            let rhsYear = rhs.year ?? Int.max
            if lhsYear != rhsYear { return lhsYear > rhsYear }
            return lhs.practiceIdentity > rhs.practiceIdentity
        }) {
        return withAnyArt
    }

    return candidates.max { lhs, rhs in
        let lhsScore = opdbMediaScore(lhs, machineVariant: normalizedMachineVariant)
        let rhsScore = opdbMediaScore(rhs, machineVariant: normalizedMachineVariant)
        if lhsScore != rhsScore { return lhsScore < rhsScore }
        let lhsYear = lhs.year ?? Int.max
        let rhsYear = rhs.year ?? Int.max
        if lhsYear != rhsYear { return lhsYear > rhsYear }
        return lhs.practiceIdentity > rhs.practiceIdentity
    }
}

private func opdbMediaScore(_ record: GameRoomOPDBMediaRecord, machineVariant: String?) -> Int {
    let recordVariant = normalizedGameRoomVariant(record.variant)
    var score = 0

    if let machineVariant {
        score += opdbVariantMatchScore(recordVariant: record.variant, requestedVariant: machineVariant)
    } else if machineVariant == nil && recordVariant == nil {
        score += 140
    } else if machineVariant == nil {
        score += variantPreferenceScore(recordVariant)
    }

    if record.primaryLargeURL != nil || record.primaryMediumURL != nil {
        score += 20
    }

    return score
}

private func opdbVariantMatchScore(recordVariant: String?, requestedVariant: String) -> Int {
    let normalizedRecordVariant = normalizedGameRoomVariant(recordVariant) ?? ""
    guard !normalizedRecordVariant.isEmpty else { return 0 }
    if normalizedRecordVariant == requestedVariant { return 200 }

    let recordTokens = Set(
        normalizedRecordVariant
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    )
    let requestTokens = Set(
        requestedVariant
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    )
    let sharedTokens = recordTokens.intersection(requestTokens)
    if !sharedTokens.isEmpty {
        var score = 100 + (sharedTokens.count * 20)
        if sharedTokens.contains("anniversary") { score += 200 }
        if sharedTokens.contains(where: { $0.hasSuffix("th") || Int($0) != nil }) { score += 120 }
        if sharedTokens.contains("premium") { score += 40 }
        if sharedTokens.contains("le") { score += 40 }
        return score
    }
    if normalizedRecordVariant.contains(requestedVariant) || requestedVariant.contains(normalizedRecordVariant) { return 80 }
    if requestedVariant.contains("premium") && normalizedRecordVariant == "le" { return 70 }
    return 0
}

private func opdbRecordHasPrimaryImage(_ record: GameRoomOPDBMediaRecord) -> Bool {
    record.primaryLargeURL != nil || record.primaryMediumURL != nil
}

private func variantPreferenceScore(_ normalizedVariant: String?) -> Int {
    guard let normalizedVariant else { return 120 }
    if normalizedVariant == "premium" || normalizedVariant.contains("premium") { return 110 }
    if normalizedVariant == "le" || normalizedVariant.contains("limited") { return 100 }
    if normalizedVariant == "pro" || normalizedVariant.contains("pro") { return 90 }
    if normalizedVariant.contains("anniversary") { return 20 }
    return 60
}

private func resolvedPlayfieldSourceLabel(for game: PinballGame) -> String? {
    if game.playfieldLocalOriginal != nil || game.playfieldLocal != nil {
        return "Local"
    }
    if let explicit = game.playfieldSourceLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !explicit.isEmpty {
        return explicit
    }
    guard let sourceURL = game.playfieldImageSourceURL else { return nil }
    let host = sourceURL.host?.lowercased() ?? ""
    if host.contains("img.opdb.org") {
        return "Playfield (OPDB)"
    }
    if host.contains("pillyliu.com") {
        return "Local"
    }
    return "Local"
}

private func bestTemplateGame(for machine: OwnedMachine, from games: [PinballGame]) -> PinballGame? {
    let normalizedCatalogID = normalizedGameRoomID(machine.catalogGameID)
    let normalizedCatalogGroup = normalizedGroupFromOpdbID(machine.catalogGameID)
    let normalizedPracticeIdentity = normalizedGameRoomID(machine.canonicalPracticeIdentity)
    let normalizedMachineTitle = normalizedGameRoomID(machine.displayTitle)
    let normalizedMachineVariant = normalizedGameRoomVariant(machine.displayVariant)

    let candidates = games.compactMap { game -> (PinballGame, Int)? in
        if game.sourceId == LibraryDataLoader.gameRoomLibrarySourceID {
            return nil
        }

        let gameMatchScore = templateMatchScore(
            game,
            catalogID: normalizedCatalogID,
            catalogGroupID: normalizedCatalogGroup,
            canonicalPracticeIdentity: normalizedPracticeIdentity,
            machineTitle: normalizedMachineTitle
        )
        guard gameMatchScore > 0 else { return nil }
        let score = gameMatchScore + templateScore(game, machineVariant: normalizedMachineVariant)
        return (game, score)
    }

    guard !candidates.isEmpty else { return nil }

    return candidates.max(by: { $0.1 < $1.1 })?.0
}

private func templateScore(_ game: PinballGame, machineVariant: String?) -> Int {
    let normalizedTemplateVariant = normalizedGameRoomVariant(game.normalizedVariant)
    var score = 0
    if machineVariant == normalizedTemplateVariant {
        score += 100
    } else if machineVariant == nil && normalizedTemplateVariant == nil {
        score += 80
    } else if machineVariant == nil {
        score += 20
    }
    if game.playfieldImageUrl != nil || game.primaryImageUrl != nil {
        score += 20
    }
    if game.hasRulesheetResource || !game.rulesheetLinks.isEmpty {
        score += 10
    }
    return score
}

private func templateMatchScore(
    _ game: PinballGame,
    catalogID: String?,
    catalogGroupID: String?,
    canonicalPracticeIdentity: String?,
    machineTitle: String?
) -> Int {
    let gameOPDBID = normalizedGameRoomID(game.opdbID)
    let gameOPDBGroupID = normalizedGameRoomID(game.opdbGroupID)
    let gamePracticeIdentity = normalizedGameRoomID(game.practiceIdentity)
    let gameTitle = normalizedGameRoomID(game.name)

    var score = 0

    if let catalogID {
        if gameOPDBID == catalogID { score = max(score, 1200) }
        if gameOPDBGroupID == catalogID { score = max(score, 1150) }
        if gamePracticeIdentity == catalogID { score = max(score, 1100) }
    }

    if let catalogGroupID {
        if gameOPDBGroupID == catalogGroupID { score = max(score, 1125) }
        if gameOPDBID == catalogGroupID { score = max(score, 1075) }
    }

    if let canonicalPracticeIdentity {
        if gamePracticeIdentity == canonicalPracticeIdentity { score = max(score, 1050) }
        if gameOPDBID == canonicalPracticeIdentity { score = max(score, 1000) }
        if gameOPDBGroupID == canonicalPracticeIdentity { score = max(score, 1000) }
    }

    if score == 0, let machineTitle, let gameTitle, machineTitle == gameTitle {
        score = 700
    }

    return score
}

private func normalizedGameRoomVariant(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return trimmed.lowercased()
}

private func normalizedGameRoomID(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return trimmed.lowercased()
}

private func normalizedGroupFromOpdbID(_ raw: String?) -> String? {
    guard let normalized = normalizedGameRoomID(raw), normalized.hasPrefix("g") else {
        return nil
    }
    guard let dashIndex = normalized.firstIndex(of: "-") else {
        return normalized
    }
    let group = String(normalized[..<dashIndex])
    return group.isEmpty ? nil : group
}

private func slugForLibraryGame(title: String, fallback: String) -> String {
    let base = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let slugified = base
        .replacingOccurrences(of: "&", with: "and")
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    if !slugified.isEmpty {
        return slugified
    }
    return fallback
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}
