import Foundation
import UIKit

enum DraftMediaType: String, Codable, Hashable {
    case image
    case video
}

struct DraftRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let templateID: String
    var editState: CardEditState
    var mediaType: DraftMediaType
    var imageFileName: String?
    var videoFileName: String?
    var thumbnailFileName: String
    let createdAt: Date
    var updatedAt: Date

    var title: String {
        let trimmed = editState.mainText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "無題" : trimmed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case templateID
        case editState
        case mediaType
        case imageFileName
        case videoFileName
        case thumbnailFileName
        case createdAt
        case updatedAt
    }

    init(
        id: UUID,
        templateID: String,
        editState: CardEditState,
        mediaType: DraftMediaType,
        imageFileName: String?,
        videoFileName: String?,
        thumbnailFileName: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.templateID = templateID
        self.editState = editState
        self.mediaType = mediaType
        self.imageFileName = imageFileName
        self.videoFileName = videoFileName
        self.thumbnailFileName = thumbnailFileName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        templateID = try container.decode(String.self, forKey: .templateID)
        editState = try container.decode(CardEditState.self, forKey: .editState)
        mediaType = try container.decodeIfPresent(DraftMediaType.self, forKey: .mediaType) ?? .image
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        videoFileName = try container.decodeIfPresent(String.self, forKey: .videoFileName)
        thumbnailFileName = try container.decode(String.self, forKey: .thumbnailFileName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

enum DraftRepositoryError: LocalizedError {
    case mediaMissing
    case limitReached
    case imageWriteFailed
    case videoCopyFailed

    var errorDescription: String? {
        switch self {
        case .mediaMissing:
            return "下書きに保存するメディアを読み込めませんでした。"
        case .limitReached:
            return "下書きは100件まで保存できます。"
        case .imageWriteFailed:
            return "下書き画像を保存できませんでした。"
        case .videoCopyFailed:
            return "下書き動画を保存できませんでした。"
        }
    }
}

struct DraftRepository {
    static let shared = DraftRepository()
    static let draftLimit = 100

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func loadDrafts() -> [DraftRecord] {
        guard let data = try? Data(contentsOf: indexURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = (try? decoder.decode([DraftRecord].self, from: data)) ?? []
        return records.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(
        template: Template,
        editState: CardEditState,
        media: EditableMedia?,
        existingDraftID: UUID?,
        draftLimit: Int = Self.draftLimit
    ) throws -> DraftRecord {
        guard let media else {
            throw DraftRepositoryError.mediaMissing
        }

        try ensureDirectories()

        var records = loadDrafts()
        let now = Date()
        let id = existingDraftID ?? UUID()
        let isUpdating = records.contains { $0.id == id }

        if !isUpdating && records.count >= draftLimit {
            throw DraftRepositoryError.limitReached
        }

        let existingRecord = records.first(where: { $0.id == id })
        let thumbnailFileName = "\(id.uuidString)-thumb.jpg"
        let imageFileName: String?
        let videoFileName: String?

        switch media.kind {
        case .image:
            guard let image = media.image else {
                throw DraftRepositoryError.mediaMissing
            }
            imageFileName = "\(id.uuidString)-work.jpg"
            videoFileName = nil
            try writeImage(image, maxLongSide: 2600, quality: 0.88, to: imagesDirectory.appendingPathComponent(imageFileName!))
            try writeImage(media.thumbnailImage, maxLongSide: 420, quality: 0.78, to: thumbnailsDirectory.appendingPathComponent(thumbnailFileName))
        case .video:
            guard let sourceURL = media.videoURL else {
                throw DraftRepositoryError.mediaMissing
            }
            imageFileName = nil
            videoFileName = "\(id.uuidString)-video.\(sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)"
            try copyVideo(from: sourceURL, to: videosDirectory.appendingPathComponent(videoFileName!))
            try writeImage(media.thumbnailImage, maxLongSide: 420, quality: 0.78, to: thumbnailsDirectory.appendingPathComponent(thumbnailFileName))
        }

        let createdAt = existingRecord?.createdAt ?? now
        let record = DraftRecord(
            id: id,
            templateID: template.id,
            editState: editState,
            mediaType: DraftMediaType(rawValue: media.kind.rawValue) ?? .image,
            imageFileName: imageFileName,
            videoFileName: videoFileName,
            thumbnailFileName: thumbnailFileName,
            createdAt: createdAt,
            updatedAt: now
        )

        if let existingRecord {
            removeMediaFiles(for: existingRecord, preserving: record)
        }
        records.removeAll { $0.id == id }
        records.append(record)
        records.sort { $0.updatedAt > $1.updatedAt }
        try writeIndex(records)

        return record
    }

    func deleteDraft(id: UUID) throws {
        var records = loadDrafts()
        guard let record = records.first(where: { $0.id == id }) else {
            return
        }

        records.removeAll { $0.id == id }
        try writeIndex(records)

        removeMediaFiles(for: record)
    }

    func image(for record: DraftRecord) -> UIImage? {
        guard let imageFileName = record.imageFileName else {
            return nil
        }

        return UIImage(contentsOfFile: imagesDirectory.appendingPathComponent(imageFileName).path)
    }

    func videoURL(for record: DraftRecord) -> URL? {
        guard let videoFileName = record.videoFileName else {
            return nil
        }

        let url = videosDirectory.appendingPathComponent(videoFileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func thumbnail(for record: DraftRecord) -> UIImage? {
        UIImage(contentsOfFile: thumbnailsDirectory.appendingPathComponent(record.thumbnailFileName).path)
    }

    func editableMedia(for record: DraftRecord) -> EditableMedia? {
        guard let thumbnail = thumbnail(for: record) else {
            return nil
        }

        switch record.mediaType {
        case .image:
            guard let image = image(for: record) else {
                return nil
            }
            return .image(image)
        case .video:
            guard let videoURL = videoURL(for: record) else {
                return nil
            }
            return .video(
                url: videoURL,
                thumbnailImage: thumbnail,
                naturalSize: thumbnail.size,
                duration: nil
            )
        }
    }

    func cleanupOrphanedFiles() {
        let records = loadDrafts()
        let imageNames = Set(records.compactMap(\.imageFileName))
        let videoNames = Set(records.compactMap(\.videoFileName))
        let thumbnailNames = Set(records.map(\.thumbnailFileName))

        removeOrphanedFiles(in: imagesDirectory, keeping: imageNames)
        removeOrphanedFiles(in: videosDirectory, keeping: videoNames)
        removeOrphanedFiles(in: thumbnailsDirectory, keeping: thumbnailNames)
    }

    private func writeIndex(_ records: [DraftRecord]) throws {
        try ensureDirectories()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: indexURL, options: protectedWriteOptions)
        protectItemIfPossible(at: indexURL)
    }

    private func writeImage(_ image: UIImage, maxLongSide: CGFloat, quality: CGFloat, to url: URL) throws {
        let resized = image.resizedForDraft(maxLongSide: maxLongSide)
        guard let data = resized.jpegData(compressionQuality: quality) else {
            throw DraftRepositoryError.imageWriteFailed
        }

        try data.write(to: url, options: protectedWriteOptions)
        protectItemIfPossible(at: url)
        excludeFromBackupIfPossible(url)
    }

    private func copyVideo(from sourceURL: URL, to destinationURL: URL) throws {
        if sourceURL.isSameFile(as: destinationURL) {
            protectItemIfPossible(at: destinationURL)
            excludeFromBackupIfPossible(destinationURL)
            return
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            protectItemIfPossible(at: destinationURL)
            excludeFromBackupIfPossible(destinationURL)
        } catch {
            throw DraftRepositoryError.videoCopyFailed
        }
    }

    private func removeMediaFiles(for record: DraftRecord, preserving preservedRecord: DraftRecord? = nil) {
        if let imageFileName = record.imageFileName,
           imageFileName != preservedRecord?.imageFileName {
            try? fileManager.removeItem(at: imagesDirectory.appendingPathComponent(imageFileName))
        }
        if let videoFileName = record.videoFileName,
           videoFileName != preservedRecord?.videoFileName {
            try? fileManager.removeItem(at: videosDirectory.appendingPathComponent(videoFileName))
        }
        if record.thumbnailFileName != preservedRecord?.thumbnailFileName {
            try? fileManager.removeItem(at: thumbnailsDirectory.appendingPathComponent(record.thumbnailFileName))
        }
    }

    private func removeOrphanedFiles(in directory: URL, keeping allowedNames: Set<String>) {
        guard let urls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }

        for url in urls where !allowedNames.contains(url.lastPathComponent) {
            try? fileManager.removeItem(at: url)
        }
    }

    private func ensureDirectories() throws {
        try createProtectedDirectory(at: draftsDirectory)
        try createProtectedDirectory(at: imagesDirectory)
        try createProtectedDirectory(at: videosDirectory)
        try createProtectedDirectory(at: thumbnailsDirectory)
        protectItemIfPossible(at: indexURL)
        protectExistingItemsIfPossible(in: imagesDirectory)
        protectExistingItemsIfPossible(in: videosDirectory)
        protectExistingItemsIfPossible(in: thumbnailsDirectory)
        excludeFromBackupIfPossible(draftsDirectory)
        excludeFromBackupIfPossible(imagesDirectory)
        excludeFromBackupIfPossible(videosDirectory)
        excludeFromBackupIfPossible(thumbnailsDirectory)
    }

    private func createProtectedDirectory(at url: URL) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: protectedFileAttributes
        )
        protectItemIfPossible(at: url)
        excludeFromBackupIfPossible(url)
    }

    private func protectExistingItemsIfPossible(in directory: URL) {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        urls.forEach { protectItemIfPossible(at: $0) }
        urls.forEach { excludeFromBackupIfPossible($0) }
    }

    private func protectItemIfPossible(at url: URL) {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try? fileManager.setAttributes(protectedFileAttributes, ofItemAtPath: url.path)
    }

    private func excludeFromBackupIfPossible(_ url: URL) {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(values)
    }

    private var applicationSupportDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private var draftsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("MemoriesDrafts", isDirectory: true)
    }

    private var imagesDirectory: URL {
        draftsDirectory.appendingPathComponent("Images", isDirectory: true)
    }

    private var videosDirectory: URL {
        draftsDirectory.appendingPathComponent("Videos", isDirectory: true)
    }

    private var thumbnailsDirectory: URL {
        draftsDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    private var indexURL: URL {
        draftsDirectory.appendingPathComponent("drafts.json")
    }

    private var protectedWriteOptions: Data.WritingOptions {
        [.atomic, .completeFileProtection]
    }

    private var protectedFileAttributes: [FileAttributeKey: Any] {
        [.protectionKey: FileProtectionType.complete]
    }
}

private extension URL {
    func isSameFile(as other: URL) -> Bool {
        standardizedFileURL.resolvingSymlinksInPath().path == other.standardizedFileURL.resolvingSymlinksInPath().path
    }
}

private extension UIImage {
    func resizedForDraft(maxLongSide: CGFloat) -> UIImage {
        guard size.width > 0, size.height > 0 else {
            return self
        }

        let longSide = max(size.width, size.height)
        guard longSide > maxLongSide else {
            return self
        }

        let scale = maxLongSide / longSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
