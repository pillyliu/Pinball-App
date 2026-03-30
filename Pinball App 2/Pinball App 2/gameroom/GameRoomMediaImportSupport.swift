import Foundation
import SwiftUI
import UniformTypeIdentifiers

func gameRoomResolvedMediaURL(from rawURI: String) -> URL? {
    let trimmed = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let direct = URL(string: trimmed), direct.scheme != nil {
        return direct
    }
    return URL(fileURLWithPath: trimmed)
}

func gameRoomSaveImportedMedia(data: Data, preferredExtension: String) throws -> URL {
    let directory = try gameRoomMediaStorageDirectory()
    let targetURL = directory.appendingPathComponent("\(UUID().uuidString).\(preferredExtension)")
    try data.write(to: targetURL, options: [.atomic])
    return targetURL
}

func gameRoomCopyImportedMediaFile(from sourceURL: URL) throws -> URL {
    let directory = try gameRoomMediaStorageDirectory()
    let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
    let targetURL = directory.appendingPathComponent("\(UUID().uuidString).\(ext)")
    if FileManager.default.fileExists(atPath: targetURL.path) {
        try FileManager.default.removeItem(at: targetURL)
    }
    try FileManager.default.copyItem(at: sourceURL, to: targetURL)
    return targetURL
}

private func gameRoomMediaStorageDirectory() throws -> URL {
    let base = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let directory = base.appendingPathComponent("GameRoomMedia", isDirectory: true)
    if !FileManager.default.fileExists(atPath: directory.path) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    return directory
}

struct MovieTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            Self(url: received.file)
        }
    }
}
