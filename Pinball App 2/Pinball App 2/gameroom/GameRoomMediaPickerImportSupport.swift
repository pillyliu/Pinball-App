import Foundation
import SwiftUI
import PhotosUI

struct GameRoomMediaImportState {
    var selectedMediaItem: PhotosPickerItem?
    var pickerKind: MachineAttachmentKind = .photo
    var showMediaPicker = false
    var isImportingAsset = false
    var importErrorMessage: String?

    mutating func preparePicker(for kind: MachineAttachmentKind) {
        pickerKind = kind
        importErrorMessage = nil
    }

    mutating func beginImport() {
        importErrorMessage = nil
        isImportingAsset = true
    }

    mutating func finishImport() {
        isImportingAsset = false
    }

    mutating func failImport(for kind: MachineAttachmentKind) {
        importErrorMessage = gameRoomMediaImportErrorMessage(for: kind)
        isImportingAsset = false
    }

    mutating func clearSelection() {
        selectedMediaItem = nil
    }
}

func gameRoomMediaImportErrorMessage(for kind: MachineAttachmentKind) -> String {
    kind == .photo ? "Could not import selected photo." : "Could not import selected video."
}

func gameRoomImportedMediaURL(
    from item: PhotosPickerItem,
    kind: MachineAttachmentKind
) async throws -> URL {
    switch kind {
    case .photo:
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw URLError(.cannotDecodeRawData)
        }
        return try gameRoomSaveImportedMedia(data: data, preferredExtension: "jpg")
    case .video:
        guard let movie = try await item.loadTransferable(type: MovieTransferable.self) else {
            throw URLError(.cannotDecodeRawData)
        }
        return try gameRoomCopyImportedMediaFile(from: movie.url)
    }
}

func gameRoomImportedMediaCaption(for url: URL) -> String? {
    let caption = url.lastPathComponent
    return caption.isEmpty ? nil : caption
}
