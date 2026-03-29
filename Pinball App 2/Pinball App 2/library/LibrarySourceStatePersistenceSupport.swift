import Foundation

extension PinballLibrarySourceStateStore {
    static func hasPersistedState() -> Bool {
        UserDefaults.standard.data(forKey: defaultsKey) != nil
    }

    static func load() -> PinballLibrarySourceState {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return .empty
        }
        if let state = try? JSONDecoder().decode(PinballLibrarySourceState.self, from: data) {
            let migrated = normalized(state)
            if migrated != state {
                save(migrated)
            }
            return migrated
        }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .empty
        }
        let migrated = normalized(
            PinballLibrarySourceState(
                enabledSourceIDs: (root["enabledSourceIDs"] as? [Any])?.compactMap { canonicalLibrarySourceID(String(describing: $0)) } ?? [],
                pinnedSourceIDs: (root["pinnedSourceIDs"] as? [Any])?.compactMap { canonicalLibrarySourceID(String(describing: $0)) } ?? [],
                selectedSourceID: canonicalLibrarySourceID(root["selectedSourceID"] as? String),
                selectedSortBySource: normalizeStringMap(root["selectedSortBySource"] as? [String: Any]),
                selectedBankBySource: normalizeIntMap(root["selectedBankBySource"] as? [String: Any])
            )
        )
        save(migrated)
        return migrated
    }

    static func save(_ state: PinballLibrarySourceState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func synchronize(with payloadSources: [PinballLibrarySource]) -> PinballLibrarySourceState {
        let validIDs = Set(payloadSources.map(\.id))
        var state = load()
        state.enabledSourceIDs = filteredKnownIDs(state.enabledSourceIDs, validIDs: validIDs)
        state.pinnedSourceIDs = Array(filteredKnownIDs(state.pinnedSourceIDs, validIDs: validIDs).prefix(maxPinnedSources))
        if !hasPersistedState() {
            let seededIDs = defaultSeededLibrarySourceIDs.filter { validIDs.contains($0) }
            if !seededIDs.isEmpty {
                state.enabledSourceIDs = seededIDs
                state.pinnedSourceIDs = Array(seededIDs.prefix(maxPinnedSources))
                state.selectedSourceID = seededIDs.first
            }
        }

        if let selectedSourceID = canonicalLibrarySourceID(state.selectedSourceID), validIDs.contains(selectedSourceID) {
            state.selectedSourceID = selectedSourceID
        } else {
            state.selectedSourceID = nil
        }

        state.selectedSortBySource = Dictionary(
            uniqueKeysWithValues: dedupedPairs(state.selectedSortBySource.compactMap { key, value in
                guard let canonicalKey = canonicalLibrarySourceID(key), validIDs.contains(canonicalKey) else { return nil }
                return (canonicalKey, value)
            })
        )
        state.selectedBankBySource = Dictionary(
            uniqueKeysWithValues: dedupedPairs(state.selectedBankBySource.compactMap { key, value in
                guard let canonicalKey = canonicalLibrarySourceID(key), validIDs.contains(canonicalKey) else { return nil }
                return (canonicalKey, value)
            })
        )
        save(state)
        return state
    }
}
