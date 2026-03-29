import Foundation

extension PinballLibrarySourceStateStore {
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
}
