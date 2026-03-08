import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import UIKit

struct GameRoomServiceEntrySheet: View {
    let title: String
    let submitLabel: String
    let includesConsumableField: Bool
    let includesPitchFields: Bool
    let onSave: (Date, String?, String?, Double?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt = Date()
    @State private var notes = ""
    @State private var consumable = ""
    @State private var pitchValueText = ""
    @State private var pitchMeasurementPoint = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)

                if includesConsumableField {
                    TextField("Cleaner / Consumable", text: $consumable)
                }

                if includesPitchFields {
                    TextField("Pitch Value", text: $pitchValueText)
                        .keyboardType(.decimalPad)
                    TextField("Measurement Point", text: $pitchMeasurementPoint)
                }

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitLabel) {
                        onSave(
                            occurredAt,
                            normalizedOptional(notes),
                            normalizedOptional(consumable),
                            parsedPitchValue,
                            normalizedOptional(pitchMeasurementPoint)
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private var parsedPitchValue: Double? {
        Double(pitchValueText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct GameRoomPlayCountEntrySheet: View {
    let onSave: (Date, Int, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt = Date()
    @State private var playTotalText = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)
                TextField("Total Plays", text: $playTotalText)
                    .keyboardType(.numberPad)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Log Plays")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let playTotal = parsedPlayTotal else { return }
                        onSave(occurredAt, playTotal, normalizedOptional(notes))
                        dismiss()
                    }
                    .disabled(parsedPlayTotal == nil)
                }
            }
        }
    }

    private var parsedPlayTotal: Int? {
        guard let value = Int(playTotalText.trimmingCharacters(in: .whitespacesAndNewlines)), value >= 0 else {
            return nil
        }
        return value
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct GameRoomIssueAttachmentDraft: Identifiable {
    let id = UUID()
    let kind: MachineAttachmentKind
    let uri: String
    let caption: String?
}

struct GameRoomLogIssueSheet: View {
    let onSave: (Date, String, MachineIssueSeverity, MachineIssueSubsystem, String?, [GameRoomIssueAttachmentDraft]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var openedAt = Date()
    @State private var symptom = ""
    @State private var severity: MachineIssueSeverity = .medium
    @State private var subsystem: MachineIssueSubsystem = .flipper
    @State private var diagnosis = ""
    @State private var selectedMediaItem: PhotosPickerItem?
    @State private var pickerKind: MachineAttachmentKind = .photo
    @State private var showMediaPicker = false
    @State private var isImportingAsset = false
    @State private var importErrorMessage: String?
    @State private var attachments: [GameRoomIssueAttachmentDraft] = []

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Opened", selection: $openedAt)
                TextField("Symptom", text: $symptom)

                Picker("Severity", selection: $severity) {
                    ForEach(MachineIssueSeverity.allCases) { level in
                        Text(level.rawValue.capitalized).tag(level)
                    }
                }
                .pickerStyle(.menu)

                Picker("Subsystem", selection: $subsystem) {
                    ForEach(MachineIssueSubsystem.allCases) { value in
                        Text(value.displayTitle).tag(value)
                    }
                }
                .pickerStyle(.menu)

                TextField("Diagnosis / Notes", text: $diagnosis, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)

                HStack(spacing: 10) {
                    Button {
                        pickerKind = .photo
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            showMediaPicker = true
                        }
                    } label: {
                        Label("Add Photo", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)

                    Button {
                        pickerKind = .video
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            showMediaPicker = true
                        }
                    } label: {
                        Label("Add Video", systemImage: "video")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }

                if isImportingAsset {
                    AppInlineTaskStatus(text: "Importing media…", showsProgress: true)
                }

                if let importErrorMessage {
                    AppInlineStatusMessage(text: importErrorMessage, isError: true)
                }

                if attachments.isEmpty {
                    AppPanelEmptyCard(text: "No media selected.")
                } else {
                    ForEach(attachments) { attachment in
                        HStack(spacing: 10) {
                            Image(systemName: attachment.kind == .photo ? "photo" : "video")
                                .foregroundStyle(.secondary)
                            Text(attachment.caption ?? attachment.uri)
                                .font(.footnote)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button(role: .destructive) {
                                attachments.removeAll { $0.id == attachment.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("Log Issue")
            .navigationBarTitleDisplayMode(.inline)
            .photosPicker(
                isPresented: $showMediaPicker,
                selection: $selectedMediaItem,
                matching: pickerKind == .photo ? .images : .videos,
                photoLibrary: .shared()
            )
            .onChange(of: selectedMediaItem) { _, item in
                guard let item else { return }
                if pickerKind == .photo {
                    importPhoto(item)
                } else {
                    importVideo(item)
                }
                selectedMediaItem = nil
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedSymptom = symptom.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedSymptom.isEmpty else { return }
                        onSave(
                            openedAt,
                            trimmedSymptom,
                            severity,
                            subsystem,
                            normalizedOptional(diagnosis),
                            attachments
                        )
                        dismiss()
                    }
                    .disabled(symptom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        importErrorMessage = nil
        isImportingAsset = true
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw URLError(.cannotDecodeRawData)
                }
                let url = try saveImportedMedia(data: data, preferredExtension: "jpg")
                await MainActor.run {
                    let caption = url.lastPathComponent
                    attachments.append(
                        GameRoomIssueAttachmentDraft(
                            kind: .photo,
                            uri: url.path,
                            caption: caption.isEmpty ? nil : caption
                        )
                    )
                    isImportingAsset = false
                }
            } catch {
                await MainActor.run {
                    importErrorMessage = "Could not import selected photo."
                    isImportingAsset = false
                }
            }
        }
    }

    private func importVideo(_ item: PhotosPickerItem) {
        importErrorMessage = nil
        isImportingAsset = true
        Task {
            do {
                guard let movie = try await item.loadTransferable(type: MovieTransferable.self) else {
                    throw URLError(.cannotDecodeRawData)
                }
                let copiedURL = try copyImportedMediaFile(from: movie.url)
                await MainActor.run {
                    let caption = copiedURL.lastPathComponent
                    attachments.append(
                        GameRoomIssueAttachmentDraft(
                            kind: .video,
                            uri: copiedURL.path,
                            caption: caption.isEmpty ? nil : caption
                        )
                    )
                    isImportingAsset = false
                }
            } catch {
                await MainActor.run {
                    importErrorMessage = "Could not import selected video."
                    isImportingAsset = false
                }
            }
        }
    }

    private func saveImportedMedia(data: Data, preferredExtension: String) throws -> URL {
        let directory = try mediaStorageDirectory()
        let targetURL = directory.appendingPathComponent("\(UUID().uuidString).\(preferredExtension)")
        try data.write(to: targetURL, options: [.atomic])
        return targetURL
    }

    private func copyImportedMediaFile(from sourceURL: URL) throws -> URL {
        let directory = try mediaStorageDirectory()
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let targetURL = directory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: targetURL)
        return targetURL
    }

    private func mediaStorageDirectory() throws -> URL {
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
}

struct GameRoomResolveIssueSheet: View {
    let openIssues: [MachineIssue]
    let onSave: (UUID, Date, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIssueID: UUID?
    @State private var resolvedAt = Date()
    @State private var resolution = ""

    var body: some View {
        NavigationStack {
            Form {
                if openIssues.isEmpty {
                    Text("No open issues.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Issue", selection: $selectedIssueID) {
                        ForEach(openIssues) { issue in
                            Text(issue.symptom).tag(Optional(issue.id))
                        }
                    }
                    .pickerStyle(.menu)

                    DatePicker("Resolved", selection: $resolvedAt)

                    TextField("Resolution Notes", text: $resolution, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Resolve Issue")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedIssueID == nil {
                    selectedIssueID = openIssues.first?.id
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let selectedIssueID else { return }
                        onSave(selectedIssueID, resolvedAt, normalizedOptional(resolution))
                        dismiss()
                    }
                    .disabled(selectedIssueID == nil)
                }
            }
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct GameRoomOwnershipEntrySheet: View {
    private let ownershipTypes: [MachineEventType] = [
        .purchased,
        .moved,
        .loanedOut,
        .returned,
        .listedForSale,
        .sold,
        .traded,
        .reacquired
    ]

    let onSave: (Date, MachineEventType, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt = Date()
    @State private var eventType: MachineEventType = .moved
    @State private var summary = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)
                Picker("Event", selection: $eventType) {
                    ForEach(ownershipTypes) { type in
                        Text(type.displayTitle).tag(type)
                    }
                }
                .pickerStyle(.menu)

                TextField("Summary", text: $summary)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Ownership Update")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    summary = eventType.displayTitle
                }
            }
            .onChange(of: eventType) { _, next in
                if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ownershipTypes.contains(where: { $0.displayTitle == summary }) {
                    summary = next.displayTitle
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedSummary.isEmpty else { return }
                        onSave(occurredAt, eventType, trimmedSummary, normalizedOptional(notes))
                        dismiss()
                    }
                    .disabled(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct GameRoomMediaEntrySheet: View {
    private enum MediaField: Hashable {
        case uri
        case caption
        case notes
    }

    let onSave: (MachineAttachmentKind, String, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: MachineAttachmentKind = .photo
    @State private var selectedMediaItem: PhotosPickerItem?
    @State private var pickerKind: MachineAttachmentKind = .photo
    @State private var showMediaPicker = false
    @State private var isImportingAsset = false
    @State private var importErrorMessage: String?
    @State private var uri = ""
    @State private var caption = ""
    @State private var notes = ""
    @FocusState private var focusedField: MediaField?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Photo").tag(MachineAttachmentKind.photo)
                    Text("Video").tag(MachineAttachmentKind.video)
                }
                .pickerStyle(.segmented)

                if kind == .photo {
                    Button {
                        focusedField = nil
                        pickerKind = .photo
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            showMediaPicker = true
                        }
                    } label: {
                        Label("Pick Photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderless)
                    .contentShape(Rectangle())
                } else {
                    Button {
                        focusedField = nil
                        pickerKind = .video
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            showMediaPicker = true
                        }
                    } label: {
                        Label("Pick Video", systemImage: "video")
                    }
                    .buttonStyle(.borderless)
                    .contentShape(Rectangle())
                }

                if isImportingAsset {
                    AppInlineTaskStatus(text: "Importing media…", showsProgress: true)
                }

                if let importErrorMessage {
                    AppInlineStatusMessage(text: importErrorMessage, isError: true)
                }

                if kind == .photo, let previewURL = resolvedMediaURL {
                    ConstrainedAsyncImagePreview(
                        candidates: [previewURL],
                        emptyMessage: "No image",
                        maxAspectRatio: 4.0 / 3.0,
                        imagePadding: 0
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                TextField("Media URL / URI", text: $uri)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .uri)
                TextField("Caption", text: $caption)
                    .focused($focusedField, equals: .caption)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .focused($focusedField, equals: .notes)
            }
            .navigationTitle("Add Photo/Video")
            .navigationBarTitleDisplayMode(.inline)
            .photosPicker(
                isPresented: $showMediaPicker,
                selection: $selectedMediaItem,
                matching: pickerKind == .photo ? .images : .videos,
                photoLibrary: .shared()
            )
            .onChange(of: selectedMediaItem) { _, item in
                guard let item else { return }
                if pickerKind == .photo {
                    importPhoto(item)
                } else {
                    importVideo(item)
                }
                selectedMediaItem = nil
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedURI = uri.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedURI.isEmpty else { return }
                        onSave(kind, trimmedURI, normalizedOptional(caption), normalizedOptional(notes))
                        dismiss()
                    }
                    .disabled(uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        importErrorMessage = nil
        isImportingAsset = true
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw URLError(.cannotDecodeRawData)
                }
                let url = try saveImportedMedia(data: data, preferredExtension: "jpg")
                await MainActor.run {
                    uri = url.path
                    isImportingAsset = false
                }
            } catch {
                await MainActor.run {
                    importErrorMessage = "Could not import selected photo."
                    isImportingAsset = false
                }
            }
        }
    }

    private func importVideo(_ item: PhotosPickerItem) {
        importErrorMessage = nil
        isImportingAsset = true
        Task {
            do {
                guard let movie = try await item.loadTransferable(type: MovieTransferable.self) else {
                    throw URLError(.cannotDecodeRawData)
                }
                let copiedURL = try copyImportedMediaFile(from: movie.url)
                await MainActor.run {
                    uri = copiedURL.path
                    isImportingAsset = false
                }
            } catch {
                await MainActor.run {
                    importErrorMessage = "Could not import selected video."
                    isImportingAsset = false
                }
            }
        }
    }

    private func saveImportedMedia(data: Data, preferredExtension: String) throws -> URL {
        let directory = try mediaStorageDirectory()
        let targetURL = directory.appendingPathComponent("\(UUID().uuidString).\(preferredExtension)")
        try data.write(to: targetURL, options: [.atomic])
        return targetURL
    }

    private func copyImportedMediaFile(from sourceURL: URL) throws -> URL {
        let directory = try mediaStorageDirectory()
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let targetURL = directory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: targetURL)
        return targetURL
    }

    private func mediaStorageDirectory() throws -> URL {
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

    private var resolvedMediaURL: URL? {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }
        return URL(fileURLWithPath: trimmed)
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct MovieTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            Self(url: received.file)
        }
    }
}

struct GameRoomAttachmentSquareTile: View {
    let attachment: MachineAttachment
    let resolvedURL: URL?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.82))

                if attachment.kind == .video {
                    GameRoomVideoThumbnailView(url: resolvedURL)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    Image(systemName: "play.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)
                } else {
                    GameRoomImageThumbnailView(url: resolvedURL)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.controlBorder, lineWidth: 1)
        )
    }
}

private struct GameRoomImageThumbnailView: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                PinballMediaPreviewPlaceholder(showsProgress: true)
            }
        }
        .task(id: url?.absoluteString ?? "") {
            image = await loadImage(from: url)
        }
    }

    private func loadImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        if url.isFileURL {
            return UIImage(contentsOfFile: url.path)
        }
        do {
            let data = try await PinballDataCache.shared.loadData(url: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

private struct GameRoomVideoThumbnailView: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                PinballMediaPreviewPlaceholder(showsProgress: true)
            }
        }
        .task(id: url?.absoluteString ?? "") {
            image = await loadVideoThumbnail(from: url)
        }
    }

    private func loadVideoThumbnail(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        return await withCheckedContinuation { continuation in
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 600, height: 600)
            let times = [NSValue(time: .zero)]
            var resumed = false
            generator.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, _, result, _ in
                guard !resumed else { return }
                switch result {
                case .succeeded:
                    resumed = true
                    if let cgImage {
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } else {
                        continuation.resume(returning: nil)
                    }
                case .failed, .cancelled:
                    resumed = true
                    continuation.resume(returning: nil)
                @unknown default:
                    resumed = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

struct GameRoomAttachmentPreviewSheet: View {
    let attachment: MachineAttachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if attachment.kind == .photo, let url = resolvedURL {
                    HostedImageView(imageCandidates: [url])
                } else if attachment.kind == .video, let url = resolvedURL {
                    VideoPlayer(player: AVPlayer(url: url))
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                } else {
                    AppFullscreenStatusOverlay(text: "Media unavailable")
                }
            }
            .padding(14)
            .navigationTitle(attachment.kind == .photo ? "Photo" : "Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var resolvedURL: URL? {
        let trimmed = attachment.uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }
        return URL(fileURLWithPath: trimmed)
    }
}

struct GameRoomMediaEditSheet: View {
    let attachment: MachineAttachment
    let initialNotes: String?
    let onSave: (String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Caption", text: $caption)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Edit Media")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                caption = attachment.caption ?? ""
                notes = initialNotes ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(normalizedOptional(caption), normalizedOptional(notes))
                        dismiss()
                    }
                }
            }
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct GameRoomPartOrModEntrySheet: View {
    let title: String
    let detailsLabel: String
    let detailsPrompt: String
    let submitLabel: String
    let onSave: (Date, String, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt = Date()
    @State private var summary = ""
    @State private var details = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)
                TextField("Summary", text: $summary)
                TextField(detailsLabel, text: $details, prompt: Text(detailsPrompt))
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    summary = title
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitLabel) {
                        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedSummary.isEmpty else { return }
                        onSave(
                            occurredAt,
                            trimmedSummary,
                            normalizedOptional(details),
                            normalizedOptional(notes)
                        )
                        dismiss()
                    }
                    .disabled(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct GameRoomLogDetailCard: View {
    let event: MachineEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selected Log Entry")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.summary)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Type: \(event.type.displayTitle) • Category: \(event.category.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let notes = normalized(event.notes) {
                        detailLine("Notes", notes)
                    }
                    if let playTotal = event.playCountAtEvent, playTotal >= 0 {
                        detailLine("Total Plays", "\(playTotal)")
                    }
                    if let consumables = normalized(event.consumablesUsed) {
                        detailLine("Consumables", consumables)
                    }
                    if let parts = normalized(event.partsUsed) {
                        detailLine("Parts / Mod", parts)
                    }
                    if event.pitchValue != nil || normalized(event.pitchMeasurementPoint) != nil {
                        let pitchValue = event.pitchValue.map { String(format: "%.1f", $0) } ?? "—"
                        let pitchPoint = normalized(event.pitchMeasurementPoint) ?? "—"
                        detailLine("Pitch", "\(pitchValue) @ \(pitchPoint)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 164)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.controlBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.controlBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func detailLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension MachineIssueSubsystem {
    var displayTitle: String {
        switch self {
        case .popBumper: return "Pop Bumper"
        case .shooterLane: return "Shooter Lane"
        case .switchMatrix: return "Switch Matrix"
        case .toyMech: return "Toy Mech"
        default:
            return rawValue
                .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .capitalized
        }
    }
}

extension MachineEventType {
    var displayTitle: String {
        switch self {
        case .loanedOut: return "Loaned Out"
        case .listedForSale: return "Listed For Sale"
        default:
            return rawValue
                .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .capitalized
        }
    }
}

extension View {
    func gameRoomEntrySheetStyle() -> some View {
        appSheetChrome(detents: [.medium, .large], background: .clear)
    }

    func gameRoomMediaSheetStyle() -> some View {
        appSheetChrome(detents: [.medium, .large], background: .clear)
    }
}

struct GameRoomEventEditSheet: View {
    let event: MachineEvent
    let onSave: (Date, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt: Date
    @State private var summary: String
    @State private var notes: String

    init(event: MachineEvent, onSave: @escaping (Date, String, String?) -> Void) {
        self.event = event
        self.onSave = onSave
        _occurredAt = State(initialValue: event.occurredAt)
        _summary = State(initialValue: event.summary)
        _notes = State(initialValue: event.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)
                TextField("Summary", text: $summary)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Edit Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(occurredAt, summary, notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes)
                        dismiss()
                    }
                    .disabled(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
