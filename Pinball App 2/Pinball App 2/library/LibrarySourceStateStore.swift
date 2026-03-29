import Foundation

struct PinballLibrarySourceState: Codable, Equatable {
    var enabledSourceIDs: [String]
    var pinnedSourceIDs: [String]
    var selectedSourceID: String?
    var selectedSortBySource: [String: String]
    var selectedBankBySource: [String: Int]

    static let empty = PinballLibrarySourceState(
        enabledSourceIDs: [],
        pinnedSourceIDs: [],
        selectedSourceID: nil,
        selectedSortBySource: [:],
        selectedBankBySource: [:]
    )
}

enum PinballLibrarySourceStateStore {
    private static let defaultsKey = "pinball-library-source-state-v1"
    static let maxPinnedSources = 10

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

    static func upsertSource(id: String, enable: Bool = true, pinIfPossible: Bool = true) {
        guard let id = canonicalLibrarySourceID(id) else { return }
        var state = load()
        if enable, !state.enabledSourceIDs.contains(id) {
            state.enabledSourceIDs.append(id)
        }
        if pinIfPossible, !state.pinnedSourceIDs.contains(id), state.pinnedSourceIDs.count < maxPinnedSources {
            state.pinnedSourceIDs.append(id)
        }
        save(state)
    }

    static func setEnabled(sourceID: String, isEnabled: Bool) {
        guard let sourceID = canonicalLibrarySourceID(sourceID) else { return }
        var state = load()
        if isEnabled {
            if !state.enabledSourceIDs.contains(sourceID) {
                state.enabledSourceIDs.append(sourceID)
            }
        } else {
            state.enabledSourceIDs.removeAll { $0 == sourceID }
            state.pinnedSourceIDs.removeAll { $0 == sourceID }
            if state.selectedSourceID == sourceID {
                state.selectedSourceID = nil
            }
        }
        save(state)
    }

    static func setPinned(sourceID: String, isPinned: Bool) -> Bool {
        guard let sourceID = canonicalLibrarySourceID(sourceID) else { return false }
        var state = load()
        if isPinned {
            if state.pinnedSourceIDs.contains(sourceID) {
                return true
            }
            guard state.pinnedSourceIDs.count < maxPinnedSources else {
                return false
            }
            if !state.enabledSourceIDs.contains(sourceID) {
                state.enabledSourceIDs.append(sourceID)
            }
            state.pinnedSourceIDs.append(sourceID)
        } else {
            state.pinnedSourceIDs.removeAll { $0 == sourceID }
        }
        save(state)
        return true
    }

    static func setSelectedSourceID(_ sourceID: String?) {
        var state = load()
        state.selectedSourceID = canonicalLibrarySourceID(sourceID)
        save(state)
    }

    static func setSelectedSort(sourceID: String, sortName: String) {
        guard let sourceID = canonicalLibrarySourceID(sourceID) else { return }
        var state = load()
        state.selectedSortBySource[sourceID] = sortName
        save(state)
    }

    static func setSelectedBank(sourceID: String, bank: Int?) {
        guard let sourceID = canonicalLibrarySourceID(sourceID) else { return }
        var state = load()
        if let bank {
            state.selectedBankBySource[sourceID] = bank
        } else {
            state.selectedBankBySource.removeValue(forKey: sourceID)
        }
        save(state)
    }

    static func removeSourcePreferences(sourceID: String) {
        guard let sourceID = canonicalLibrarySourceID(sourceID) else { return }
        var state = load()
        state.enabledSourceIDs.removeAll { $0 == sourceID }
        state.pinnedSourceIDs.removeAll { $0 == sourceID }
        if state.selectedSourceID == sourceID {
            state.selectedSourceID = nil
        }
        state.selectedSortBySource.removeValue(forKey: sourceID)
        state.selectedBankBySource.removeValue(forKey: sourceID)
        save(state)
    }

    private static func filteredKnownIDs(_ ids: [String], validIDs: Set<String>) -> [String] {
        var seen = Set<String>()
        return ids.compactMap(canonicalLibrarySourceID).filter { id in
            validIDs.contains(id) && seen.insert(id).inserted
        }
    }

    private static func normalized(_ state: PinballLibrarySourceState) -> PinballLibrarySourceState {
        PinballLibrarySourceState(
            enabledSourceIDs: Array(NSOrderedSet(array: state.enabledSourceIDs.compactMap(canonicalLibrarySourceID))) as? [String] ?? [],
            pinnedSourceIDs: Array(NSOrderedSet(array: state.pinnedSourceIDs.compactMap(canonicalLibrarySourceID))) as? [String] ?? [],
            selectedSourceID: canonicalLibrarySourceID(state.selectedSourceID),
            selectedSortBySource: dictionaryPreservingLastValue(
                state.selectedSortBySource.compactMap { key, value in
                    canonicalLibrarySourceID(key).map { ($0, value) }
                }
            ),
            selectedBankBySource: dictionaryPreservingLastValue(
                state.selectedBankBySource.compactMap { key, value in
                    canonicalLibrarySourceID(key).map { ($0, value) }
                }
            )
        )
    }
}

extension Notification.Name {
    static let pinballLibrarySourcesDidChange = Notification.Name("pinballLibrarySourcesDidChange")
}

func postPinballLibrarySourcesDidChange() {
    NotificationCenter.default.post(name: .pinballLibrarySourcesDidChange, object: nil)
}

func normalizeStringMap(_ raw: [String: Any]?) -> [String: String] {
    dictionaryPreservingLastValue((raw ?? [:]).compactMap { key, value in
        guard let canonicalKey = canonicalLibrarySourceID(key), let stringValue = value as? String else { return nil }
        return (canonicalKey, stringValue)
    })
}

func normalizeIntMap(_ raw: [String: Any]?) -> [String: Int] {
    dictionaryPreservingLastValue((raw ?? [:]).compactMap { key, value in
        guard let canonicalKey = canonicalLibrarySourceID(key) else { return nil }
        if let intValue = value as? Int { return (canonicalKey, intValue) }
        if let numberValue = value as? NSNumber { return (canonicalKey, numberValue.intValue) }
        return nil
    })
}

func dedupedPairs<Key: Hashable, Value>(_ pairs: [(Key, Value)]) -> [(Key, Value)] {
    Array(dictionaryPreservingLastValue(pairs))
}

func dictionaryPreservingLastValue<Key: Hashable, Value>(_ pairs: [(Key, Value)]) -> [Key: Value] {
    var out: [Key: Value] = [:]
    for (key, value) in pairs {
        out[key] = value
    }
    return out
}
