import Foundation

extension PinballLibraryViewModel {
    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await loadGames()
    }

    func refresh() async {
        await loadGames()
    }
}
