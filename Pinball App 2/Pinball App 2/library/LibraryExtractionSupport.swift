import Foundation

private func filterPayload(_ payload: PinballLibraryPayload, using state: PinballLibrarySourceState) -> PinballLibraryPayload {
    let enabled = Set(state.enabledSourceIDs)
    let hasGameRoomGames = payload.games.contains { $0.sourceId == gameRoomLibrarySourceID }
    let filteredSources = payload.sources.filter { source in
        enabled.contains(source.id) || (source.id == gameRoomLibrarySourceID && hasGameRoomGames)
    }
    let sourceIDs = Set(filteredSources.map(\.id))
    let filteredGames = payload.games.filter { sourceIDs.contains($0.sourceId) }
    return PinballLibraryPayload(games: filteredGames, sources: filteredSources)
}

func libraryExtraction(
    payload: PinballLibraryPayload,
    state: PinballLibrarySourceState,
    filterBySourceState: Bool
) -> LibraryExtraction {
    LibraryExtraction(
        payload: filterBySourceState ? filterPayload(payload, using: state) : payload,
        state: state
    )
}
