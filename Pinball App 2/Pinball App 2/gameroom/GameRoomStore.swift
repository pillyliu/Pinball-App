import Foundation
import Combine
import SwiftUI

@MainActor
final class GameRoomStore: ObservableObject {
    @Published var state = GameRoomPersistedState.empty
    @Published var snapshots: [UUID: OwnedMachineSnapshot] = [:]
    @Published var lastErrorMessage: String?

    static let storageKey = "gameroom-state-json"
    static let legacyStorageKey = "gameroom-state-v1"

    private(set) var didLoad = false

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        loadState()
    }

    func loadState() {
        let defaults = UserDefaults.standard
        switch GameRoomStateCodec.loadFromDefaults(
            defaults,
            storageKey: Self.storageKey,
            legacyStorageKey: Self.legacyStorageKey
        ) {
        case .missing:
            lastErrorMessage = nil
            state = .empty
            recomputeSnapshots()
        case let .loaded(loaded, needsResave, noticeMessage):
            state = loaded
            recomputeSnapshots()

            if needsResave {
                saveState()
            }

            lastErrorMessage = noticeMessage
        case let .failed(message):
            state = .empty
            recomputeSnapshots()
            lastErrorMessage = message
        }
    }

    func saveState() {
        do {
            state.schemaVersion = GameRoomPersistedState.currentSchemaVersion
            let data = try GameRoomStateCodec.canonicalEncoder().encode(state)
            let defaults = UserDefaults.standard
            defaults.set(data, forKey: Self.storageKey)
            defaults.removeObject(forKey: Self.legacyStorageKey)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Failed to save GameRoom data: \(error.localizedDescription)"
        }
    }

    var venueName: String {
        let trimmed = state.venueName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? GameRoomPersistedState.defaultVenueName : trimmed
    }

    func saveAndRecompute() {
        recomputeSnapshots()
        saveState()
        postPinballLibrarySourcesDidChange()
    }

    func normalizedOptionalString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
