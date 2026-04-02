import Foundation

extension PinballGame {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let parsedType = libraryParseSourceType(
            try container.decodeIfPresent(String.self, forKey: .libraryType) ??
                (try container.decodeIfPresent(String.self, forKey: .libraryTypeV2)) ??
                (try container.decodeIfPresent(String.self, forKey: .sourceType))
        )
        sourceType = parsedType
        let sourceNameLibrary = try container.decodeIfPresent(String.self, forKey: .libraryName)
        let sourceNameLibraryV2 = try container.decodeIfPresent(String.self, forKey: .libraryNameV2)
        let sourceNameSource = try container.decodeIfPresent(String.self, forKey: .sourceName)
        let sourceNameVenueName = try container.decodeIfPresent(String.self, forKey: .venueName)
        let sourceNameVenue = try container.decodeIfPresent(String.self, forKey: .venue)
        let decodedSourceName = libraryNormalizedOptionalString(
            sourceNameLibrary ??
                sourceNameLibraryV2 ??
                sourceNameSource ??
                sourceNameVenueName ??
                sourceNameVenue
        )
        // Intentional fallback for malformed legacy payloads; keep until source data is guaranteed.
        sourceName = decodedSourceName ?? "Unknown Source"
        sourceId = libraryCanonicalSourceID(
            libraryNormalizedOptionalString(
                try container.decodeIfPresent(String.self, forKey: .libraryId) ??
                    (try container.decodeIfPresent(String.self, forKey: .libraryIdV2)) ??
                    (try container.decodeIfPresent(String.self, forKey: .sourceId))
            )
        ) ?? librarySlugifySourceID(sourceName)
        area = (
            try container.decodeIfPresent(String.self, forKey: .area) ??
                (try container.decodeIfPresent(String.self, forKey: .location))
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
        areaOrder = try container.decodeIfPresent(Int.self, forKey: .areaOrder)
            ?? (try container.decodeIfPresent(Int.self, forKey: .areaOrderV2))
        group = try container.decodeIfPresent(Int.self, forKey: .group)
        pos = try container.decodeIfPresent(Int.self, forKey: .position)
        bank = try container.decodeIfPresent(Int.self, forKey: .bank)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? (try container.decodeIfPresent(String.self, forKey: .game))
            ?? ""
        variant = try container.decodeIfPresent(String.self, forKey: .variant)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
            ?? (try container.decodeIfPresent(String.self, forKey: .practiceIdentity))
            ?? (try container.decodeIfPresent(String.self, forKey: .opdbId))
            ?? ""
        libraryEntryID = try container.decodeIfPresent(String.self, forKey: .libraryEntryId)
        opdbID = try container.decodeIfPresent(String.self, forKey: .opdbId)
        opdbMachineID = try container.decodeIfPresent(String.self, forKey: .opdbMachineID)
        practiceIdentity = try container.decodeIfPresent(String.self, forKey: .practiceIdentity)
        opdbName = try container.decodeIfPresent(String.self, forKey: .opdbName)
        opdbCommonName = try container.decodeIfPresent(String.self, forKey: .opdbCommonName)
        opdbShortname = try container.decodeIfPresent(String.self, forKey: .opdbShortname)
        opdbDescription = try container.decodeIfPresent(String.self, forKey: .opdbDescription)
        opdbType = try container.decodeIfPresent(String.self, forKey: .opdbType)
        opdbDisplay = try container.decodeIfPresent(String.self, forKey: .opdbDisplay)
        opdbPlayerCount = try container.decodeIfPresent(Int.self, forKey: .opdbPlayerCount)
        opdbManufactureDate = try container.decodeIfPresent(String.self, forKey: .opdbManufactureDate)
        opdbIpdbID = try container.decodeIfPresent(Int.self, forKey: .opdbIpdbID)
        opdbGroupShortname = try container.decodeIfPresent(String.self, forKey: .opdbGroupShortname)
        opdbGroupDescription = try container.decodeIfPresent(String.self, forKey: .opdbGroupDescription)
        primaryImageUrl = try container.decodeIfPresent(String.self, forKey: .primaryImageUrl)
        primaryImageLargeUrl = try container.decodeIfPresent(String.self, forKey: .primaryImageLargeUrl)
        let assets = try container.decodeIfPresent(Assets.self, forKey: .assets)
        playfieldImageUrl = try container.decodeIfPresent(String.self, forKey: .playfieldImageUrl)
            ?? (try container.decodeIfPresent(String.self, forKey: .playfieldImageUrlV2))
        alternatePlayfieldImageUrl = try container.decodeIfPresent(String.self, forKey: .alternatePlayfieldImageUrl)
        let rawPlayfieldLocal = try container.decodeIfPresent(String.self, forKey: .playfieldLocal)
            ?? assets?.playfieldLocalPractice
        let normalizedPlayfieldLocalPath = normalizeLibraryPlayfieldLocalPath(rawPlayfieldLocal)
        playfieldLocalOriginal = normalizedPlayfieldLocalPath
        playfieldLocal = normalizedPlayfieldLocalPath
        gameinfoLocal = assets?.gameinfoLocalPractice
        rulesheetLocal = assets?.rulesheetLocalPractice
        rulesheetUrl = try container.decodeIfPresent(String.self, forKey: .rulesheetUrl)
            ?? (try container.decodeIfPresent(String.self, forKey: .rulesheetUrlV2))
        playfieldSourceLabel = try container.decodeIfPresent(String.self, forKey: .playfieldSourceLabel)
        let decodedRulesheetLinks = try container.decodeIfPresent([ReferenceLink].self, forKey: .rulesheetLinks)
        if let decodedRulesheetLinks {
            rulesheetLinks = decodedRulesheetLinks
        } else if let rulesheetUrl {
            rulesheetLinks = [ReferenceLink(label: "Rulesheet (source)", url: rulesheetUrl)]
        } else {
            rulesheetLinks = []
        }
        videos = try container.decodeIfPresent([Video].self, forKey: .videos) ?? []
    }
}
