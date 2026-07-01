import XCTest
import UIKit
@testable import Memories

@MainActor
final class DraftRepositoryTests: XCTestCase {
    private let fileManager = FileManager.default
    private var temporaryFiles: [URL] = []

    override func setUpWithError() throws {
        try? fileManager.removeItem(at: draftsDirectory)
        try? fileManager.removeItem(at: temporaryMediaDirectory)
        try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? fileManager.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try? fileManager.removeItem(at: draftsDirectory)
        try? fileManager.removeItem(at: temporaryMediaDirectory)
    }

    func testLegacyDraftRecordDecodesMissingMediaTypeAsImage() throws {
        let record = DraftRecord(
            id: UUID(),
            templateID: Template.previewPetLifelog.id,
            editState: Template.previewPetLifelog.previewEditState,
            mediaType: .image,
            imageFileName: "legacy-work.jpg",
            videoFileName: nil,
            thumbnailFileName: "legacy-thumb.jpg",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )

        let encoded = try JSONEncoder().encode(record)
        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "mediaType")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)

        let decoded = try JSONDecoder().decode(DraftRecord.self, from: legacyData)

        XCTAssertEqual(decoded.mediaType, .image)
        XCTAssertEqual(decoded.imageFileName, "legacy-work.jpg")
        XCTAssertNil(decoded.videoFileName)
    }

    func testDeletingImageAndVideoDraftsRemovesMediaFiles() throws {
        let repository = DraftRepository()
        let template = Template.previewPetLifelog

        let imageRecord = try repository.save(
            template: template,
            editState: template.previewEditState,
            media: .image(makeImage(color: .red)),
            existingDraftID: nil
        )
        let imageFileName = try XCTUnwrap(imageRecord.imageFileName)
        let imageURL = imagesDirectory.appendingPathComponent(imageFileName)
        let imageThumbnailURL = thumbnailsDirectory.appendingPathComponent(imageRecord.thumbnailFileName)

        XCTAssertTrue(fileManager.fileExists(atPath: imageURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: imageThumbnailURL.path))

        try repository.deleteDraft(id: imageRecord.id)

        XCTAssertFalse(fileManager.fileExists(atPath: imageURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: imageThumbnailURL.path))

        let sourceVideoURL = try makeTemporaryVideoFile()
        let videoRecord = try repository.save(
            template: template,
            editState: template.previewEditState,
            media: .video(
                url: sourceVideoURL,
                thumbnailImage: makeImage(color: .blue),
                naturalSize: CGSize(width: 1920, height: 1080),
                duration: 12
            ),
            existingDraftID: nil
        )
        let videoFileName = try XCTUnwrap(videoRecord.videoFileName)
        let videoURL = videosDirectory.appendingPathComponent(videoFileName)
        let videoThumbnailURL = thumbnailsDirectory.appendingPathComponent(videoRecord.thumbnailFileName)

        XCTAssertTrue(fileManager.fileExists(atPath: videoURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: videoThumbnailURL.path))

        try repository.deleteDraft(id: videoRecord.id)

        XCTAssertFalse(fileManager.fileExists(atPath: videoURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: videoThumbnailURL.path))
    }

    func testUpdatingImageDraftKeepsCurrentMediaFiles() throws {
        let repository = DraftRepository()
        let template = Template.previewPetLifelog
        let original = try repository.save(
            template: template,
            editState: template.previewEditState,
            media: .image(makeImage(color: .red)),
            existingDraftID: nil
        )
        let storedMedia = try XCTUnwrap(repository.editableMedia(for: original))

        let updated = try repository.save(
            template: template,
            editState: template.previewEditState,
            media: storedMedia,
            existingDraftID: original.id
        )
        let imageFileName = try XCTUnwrap(updated.imageFileName)
        let imageURL = imagesDirectory.appendingPathComponent(imageFileName)
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(updated.thumbnailFileName)

        XCTAssertEqual(original.id, updated.id)
        XCTAssertTrue(fileManager.fileExists(atPath: imageURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: thumbnailURL.path))
        XCTAssertNotNil(repository.editableMedia(for: updated))
    }

    func testUpdatingVideoDraftFromStoredMediaKeepsCurrentMediaFiles() throws {
        let repository = DraftRepository()
        let template = Template.previewPetLifelog
        let sourceVideoURL = try makeTemporaryVideoFile()
        let original = try repository.save(
            template: template,
            editState: template.previewEditState,
            media: .video(
                url: sourceVideoURL,
                thumbnailImage: makeImage(color: .blue),
                naturalSize: CGSize(width: 1920, height: 1080),
                duration: 12
            ),
            existingDraftID: nil
        )
        let storedMedia = try XCTUnwrap(repository.editableMedia(for: original))

        let updated = try repository.save(
            template: template,
            editState: template.previewEditState,
            media: storedMedia,
            existingDraftID: original.id
        )
        let videoFileName = try XCTUnwrap(updated.videoFileName)
        let videoURL = videosDirectory.appendingPathComponent(videoFileName)
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(updated.thumbnailFileName)

        XCTAssertEqual(original.id, updated.id)
        XCTAssertEqual(original.videoFileName, updated.videoFileName)
        XCTAssertTrue(fileManager.fileExists(atPath: videoURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: thumbnailURL.path))
        XCTAssertNotNil(repository.editableMedia(for: updated))
    }

    func testCleanupOrphanedFilesKeepsIndexedDraftMedia() throws {
        let repository = DraftRepository()
        let template = Template.previewPetLifelog
        let record = try repository.save(
            template: template,
            editState: template.previewEditState,
            media: .image(makeImage(color: .green)),
            existingDraftID: nil
        )
        let keptImageFileName = try XCTUnwrap(record.imageFileName)
        let keptImageURL = imagesDirectory.appendingPathComponent(keptImageFileName)
        let keptThumbnailURL = thumbnailsDirectory.appendingPathComponent(record.thumbnailFileName)
        let orphanImageURL = imagesDirectory.appendingPathComponent("orphan.jpg")
        let orphanVideoURL = videosDirectory.appendingPathComponent("orphan.mov")
        let orphanThumbnailURL = thumbnailsDirectory.appendingPathComponent("orphan-thumb.jpg")

        try Data([1]).write(to: orphanImageURL)
        try Data([2]).write(to: orphanVideoURL)
        try Data([3]).write(to: orphanThumbnailURL)

        repository.cleanupOrphanedFiles()

        XCTAssertTrue(fileManager.fileExists(atPath: keptImageURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: keptThumbnailURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: orphanImageURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: orphanVideoURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: orphanThumbnailURL.path))
    }

    func testTemporaryCleanupDoesNotDeleteDrafts() throws {
        let repository = DraftRepository()
        let template = Template.previewPetLifelog
        let record = try repository.save(
            template: template,
            editState: template.previewEditState,
            media: .image(makeImage(color: .purple)),
            existingDraftID: nil
        )
        let draftImageFileName = try XCTUnwrap(record.imageFileName)
        let draftImageURL = imagesDirectory.appendingPathComponent(draftImageFileName)
        let draftThumbnailURL = thumbnailsDirectory.appendingPathComponent(record.thumbnailFileName)
        let importDirectory = temporaryMediaDirectory.appendingPathComponent("Imports", isDirectory: true)
        let temporaryImportURL = importDirectory.appendingPathComponent("old-import.mov")

        try fileManager.createDirectory(at: importDirectory, withIntermediateDirectories: true)
        try Data([4]).write(to: temporaryImportURL)
        try fileManager.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1)],
            ofItemAtPath: temporaryImportURL.path
        )

        let removedCount = try MediaFileManager.shared.cleanupTemporaryFiles(olderThan: Date())

        XCTAssertEqual(removedCount, 1)
        XCTAssertFalse(fileManager.fileExists(atPath: temporaryImportURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: draftImageURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: draftThumbnailURL.path))
    }

    private func makeImage(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 48, height: 36)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 48, height: 36))
        }
    }

    private func makeTemporaryVideoFile() throws -> URL {
        let url = fileManager.temporaryDirectory.appendingPathComponent("draft-test-\(UUID().uuidString).mov")
        try Data([0, 1, 2, 3, 4]).write(to: url)
        temporaryFiles.append(url)
        return url
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

    private var temporaryMediaDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MemoriesTemporaryMedia", isDirectory: true)
    }
}
