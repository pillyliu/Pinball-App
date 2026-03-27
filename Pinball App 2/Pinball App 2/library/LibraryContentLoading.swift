import Combine
import Foundation
import SwiftUI

private func libraryLoadFirstAvailableText(pathCandidates: [String]) async throws -> (text: String?, sawMissing: Bool) {
    var sawMissing = false

    for path in pathCandidates {
        let cached = try await PinballDataCache.shared.loadText(path: path, allowMissing: true)
        if cached.isMissing {
            sawMissing = true
            continue
        }
        guard let text = cached.text, !text.isEmpty else {
            sawMissing = true
            continue
        }
        return (text, sawMissing)
    }

    return (nil, sawMissing)
}

enum LoadStatus {
    case idle
    case loading
    case loaded
    case missing
    case error
}

@MainActor
final class PinballGameInfoViewModel: ObservableObject {
    @Published private(set) var status: LoadStatus = .idle
    @Published private(set) var markdownText: String?

    private let pathCandidates: [String]
    private var didLoad = false

    init(pathCandidates: [String]) {
        self.pathCandidates = pathCandidates.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await load()
    }

    private func load() async {
        status = .loading
        markdownText = nil

        do {
            let loaded = try await libraryLoadFirstAvailableText(pathCandidates: pathCandidates)
            if let text = loaded.text {
                markdownText = text
                status = .loaded
                return
            }
            status = loaded.sawMissing ? .missing : .error
        } catch {
            status = .error
        }
    }
}

@MainActor
final class RulesheetScreenModel: ObservableObject {
    @Published private(set) var status: LoadStatus = .idle
    @Published private(set) var content: RulesheetRenderContent?
    @Published private(set) var webFallbackURL: URL?

    private let pathCandidates: [String]
    private let externalSource: RulesheetRemoteSource?
    private var didLoad = false

    init(pathCandidates: [String], externalSource: RulesheetRemoteSource? = nil) {
        self.pathCandidates = pathCandidates.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.externalSource = externalSource
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await load()
    }

    private func load() async {
        status = .loading
        content = nil
        webFallbackURL = nil

        do {
            let loaded = try await libraryLoadFirstAvailableText(pathCandidates: pathCandidates)
            if let text = loaded.text {
                content = RulesheetRenderContent(
                    kind: .markdown,
                    body: Self.normalizeRulesheet(text),
                    baseURL: URL(string: "https://pillyliu.com")
                )
                status = .loaded
                return
            }

            if await loadExternalFallbackIfNeeded() {
                return
            }

            status = loaded.sawMissing ? .missing : .error
        } catch {
            if await loadExternalFallbackIfNeeded() {
                return
            }

            status = .error
        }
    }

    private func loadExternalFallbackIfNeeded() async -> Bool {
        guard let externalSource else { return false }

        do {
            content = try await RemoteRulesheetLoader.load(from: externalSource)
            status = .loaded
        } catch {
            webFallbackURL = externalSource.url
            status = webFallbackURL == nil ? .error : .loaded
        }

        return true
    }

    private static func normalizeRulesheet(_ input: String) -> String {
        var text = input.replacingOccurrences(of: "\r\n", with: "\n")

        if text.hasPrefix("---\n") {
            let start = text.index(text.startIndex, offsetBy: 4)
            if let endRange = text.range(of: "\n---", range: start..<text.endIndex),
               let after = text[endRange.upperBound...].firstIndex(of: "\n") {
                text = String(text[text.index(after, offsetBy: 1)...])
            }
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Match Android behavior: add two rendered dummy lines at the end so
        // final content can scroll clear of the tab switcher.
        return text + "\n\n\u{00A0}\n\n\u{00A0}\n"
    }
}
