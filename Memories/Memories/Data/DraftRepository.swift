import Foundation
import UIKit

struct DraftRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let templateID: String
    var editState: CardEditState
    var imageFileName: String
    var thumbnailFileName: String
    let createdAt: Date
    var updatedAt: Date

    var title: String {
        let trimmed = editState.mainText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "無題" : trimmed
    }
}

enum DraftRepositoryError: LocalizedError {
    case imageMissing
    case limitReached
    case imageWriteFailed

    var errorDescription: String? {
        switch self {
        case .imageMissing:
            return "下書きに保存する写真を読み込めませんでした。"
        case .limitReached:
            return "下書きは100件まで保存できます。"
        case .imageWriteFailed:
            return "下書き画像を保存できませんでした。"
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
        photoImage: UIImage?,
        existingDraftID: UUID?,
        draftLimit: Int = Self.draftLimit
    ) throws -> DraftRecord {
        guard let photoImage else {
            throw DraftRepositoryError.imageMissing
        }

        try ensureDirectories()

        var records = loadDrafts()
        let now = Date()
        let id = existingDraftID ?? UUID()
        let isUpdating = records.contains { $0.id == id }

        if !isUpdating && records.count >= draftLimit {
            throw DraftRepositoryError.limitReached
        }

        let imageFileName = "\(id.uuidString)-work.jpg"
        let thumbnailFileName = "\(id.uuidString)-thumb.jpg"
        try writeImage(photoImage, maxLongSide: 2600, quality: 0.88, to: imagesDirectory.appendingPathComponent(imageFileName))
        try writeImage(photoImage, maxLongSide: 420, quality: 0.78, to: thumbnailsDirectory.appendingPathComponent(thumbnailFileName))

        let createdAt = records.first(where: { $0.id == id })?.createdAt ?? now
        let record = DraftRecord(
            id: id,
            templateID: template.id,
            editState: editState,
            imageFileName: imageFileName,
            thumbnailFileName: thumbnailFileName,
            createdAt: createdAt,
            updatedAt: now
        )

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

        try? fileManager.removeItem(at: imagesDirectory.appendingPathComponent(record.imageFileName))
        try? fileManager.removeItem(at: thumbnailsDirectory.appendingPathComponent(record.thumbnailFileName))
    }

    func image(for record: DraftRecord) -> UIImage? {
        UIImage(contentsOfFile: imagesDirectory.appendingPathComponent(record.imageFileName).path)
    }

    func thumbnail(for record: DraftRecord) -> UIImage? {
        UIImage(contentsOfFile: thumbnailsDirectory.appendingPathComponent(record.thumbnailFileName).path)
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
    }

    private func ensureDirectories() throws {
        try createProtectedDirectory(at: draftsDirectory)
        try createProtectedDirectory(at: imagesDirectory)
        try createProtectedDirectory(at: thumbnailsDirectory)
        protectItemIfPossible(at: indexURL)
        protectExistingItemsIfPossible(in: imagesDirectory)
        protectExistingItemsIfPossible(in: thumbnailsDirectory)
    }

    private func createProtectedDirectory(at url: URL) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: protectedFileAttributes
        )
        protectItemIfPossible(at: url)
    }

    private func protectExistingItemsIfPossible(in directory: URL) {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        urls.forEach { protectItemIfPossible(at: $0) }
    }

    private func protectItemIfPossible(at url: URL) {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try? fileManager.setAttributes(protectedFileAttributes, ofItemAtPath: url.path)
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
