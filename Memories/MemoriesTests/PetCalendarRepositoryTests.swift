import XCTest
import UIKit
@testable import Memories

@MainActor
final class PetCalendarRepositoryTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDown() {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        super.tearDown()
    }

    func testRepositorySavesLoadsAndDeletesDayEntry() throws {
        let repository = try makeRepository()
        let now = date(year: 2026, month: 6, day: 25)
        let targetDate = date(year: 2026, month: 6, day: 20)

        let entry = try repository.save(
            image: makeImage(size: CGSize(width: 320, height: 240), color: .red),
            caption: "happy",
            for: targetDate,
            now: now
        )

        XCTAssertEqual(entry.id, "2026-06-20")
        XCTAssertEqual(entry.caption, "")
        XCTAssertEqual(entry.photoPlacement, .default)
        XCTAssertEqual(repository.loadEntries().count, 1)
        XCTAssertNotNil(repository.image(for: entry))
        XCTAssertNotNil(repository.thumbnail(for: entry))

        try repository.deleteEntry(for: targetDate)
        XCTAssertTrue(repository.loadEntries().isEmpty)
        XCTAssertNil(repository.image(for: entry))
        XCTAssertNil(repository.thumbnail(for: entry))
    }

    func testRepositoryRejectsFutureDatesAndIgnoresCaptionText() throws {
        let repository = try makeRepository()
        let now = date(year: 2026, month: 6, day: 25)
        let future = date(year: 2026, month: 6, day: 26)
        let image = makeImage()

        XCTAssertThrowsError(try repository.save(image: image, caption: "", for: future, now: now)) { error in
            XCTAssertEqual(error as? PetCalendarRepositoryError, .futureDateNotAllowed)
        }

        let entry = try repository.save(image: image, caption: "existing caption is not rendered", for: now, now: now)
        XCTAssertEqual(entry.caption, "")
        XCTAssertEqual(repository.entry(for: now)?.caption, "")
    }

    func testRepositoryRequiresExplicitReplacement() throws {
        let repository = try makeRepository()
        let now = date(year: 2026, month: 6, day: 25)
        let targetDate = date(year: 2026, month: 6, day: 20)

        let first = try repository.save(image: makeImage(color: .red), caption: "first", for: targetDate, now: now)

        XCTAssertThrowsError(try repository.save(image: makeImage(color: .blue), caption: "second", for: targetDate, now: now)) { error in
            XCTAssertEqual(error as? PetCalendarRepositoryError, .replacementRequiresConfirmation)
        }

        let second = try repository.save(
            image: makeImage(color: .blue),
            caption: "second",
            for: targetDate,
            allowReplace: true,
            now: now.addingTimeInterval(1)
        )

        XCTAssertEqual(repository.loadEntries().count, 1)
        XCTAssertEqual(repository.entry(for: targetDate)?.caption, "")
        XCTAssertEqual(second.createdAt, first.createdAt)
        XCTAssertNotEqual(second.imageFileName, first.imageFileName)
    }

    func testRepositoryStoresAndClampsPhotoPlacementAndOverlayStyle() throws {
        let repository = try makeRepository()
        let now = date(year: 2026, month: 6, day: 25)
        var overlayStyle = PetCalendarOverlayStyle.default
        overlayStyle.isWeatherIconVisible = true
        overlayStyle.weatherIcon = .rainy
        overlayStyle.weatherIconCorner = .topRight
        overlayStyle.accentColor = .blue

        let entry = try repository.save(
            image: makeImage(),
            photoPlacement: PhotoPlacement(scale: 8, offsetX: -4, offsetY: 3),
            overlayStyle: overlayStyle,
            for: now,
            now: now
        )

        XCTAssertEqual(entry.photoPlacement.scale, 3)
        XCTAssertEqual(entry.photoPlacement.offsetX, -1)
        XCTAssertEqual(entry.photoPlacement.offsetY, 1)
        XCTAssertEqual(repository.entry(for: now)?.overlayStyle, overlayStyle)
    }

    func testRepositorySavesWeatherOnlyCalendarEntry() throws {
        let repository = try makeRepository()
        let now = date(year: 2026, month: 6, day: 25)
        var overlayStyle = PetCalendarOverlayStyle.default
        overlayStyle.isWeatherIconVisible = true
        overlayStyle.weatherIcon = .rainy

        let entry = try repository.save(
            image: nil,
            overlayStyle: overlayStyle,
            for: now,
            now: now
        )

        XCTAssertNil(entry.imageFileName)
        XCTAssertNil(entry.thumbnailFileName)
        XCTAssertNil(repository.image(for: entry))
        XCTAssertNil(repository.thumbnail(for: entry))
        XCTAssertEqual(repository.entry(for: now)?.overlayStyle, overlayStyle)
    }

    func testDayEntryDecodesLegacyJSONWithoutPhotoPlacementOrOverlayStyle() throws {
        let json = """
        {
          "id": "2026-06-25",
          "date": "2026-06-25T00:00:00Z",
          "imageFileName": "image.jpg",
          "thumbnailFileName": "thumb.jpg",
          "caption": "legacy caption",
          "createdAt": "2026-06-25T00:00:00Z",
          "updatedAt": "2026-06-25T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let entry = try decoder.decode(PetCalendarDayEntry.self, from: Data(json.utf8))

        XCTAssertEqual(entry.caption, "legacy caption")
        XCTAssertEqual(entry.photoPlacement, .default)
        XCTAssertEqual(entry.overlayStyle, .default)
    }

    func testRepositoryStoresAppDataSeparatelyFromWidgetData() throws {
        let appRoot = makeTemporaryDirectory()
        let widgetRoot = makeTemporaryDirectory()
        let repository = try PetCalendarRepository(appRootURL: appRoot, widgetRootURL: widgetRoot, calendar: testCalendar)
        let now = date(year: 2026, month: 6, day: 25)
        let entry = try repository.save(image: makeImage(), caption: "today", for: now, now: now)

        let appIndexURL = appRoot.appendingPathComponent("PetCalendar/index.json")
        let appImageURL = appRoot.appendingPathComponent("PetCalendar/Images/\(try XCTUnwrap(entry.imageFileName))")
        let appThumbnailURL = appRoot.appendingPathComponent("PetCalendar/Thumbnails/\(try XCTUnwrap(entry.thumbnailFileName))")
        let widgetSnapshotURL = widgetRoot.appendingPathComponent("PetCalendarWidget/\(PetCalendarWidgetSnapshot.fileName)")

        XCTAssertTrue(FileManager.default.fileExists(atPath: appIndexURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: appImageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: appThumbnailURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: widgetSnapshotURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: widgetRoot.appendingPathComponent("PetCalendar/index.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: widgetRoot.appendingPathComponent("PetCalendar/Images").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: widgetRoot.appendingPathComponent("PetCalendar/Thumbnails").path))
    }

    func testWidgetSnapshotIsMinimalAndRenderedImagesAreInWidgetDirectory() throws {
        let repository = try makeRepository()
        let now = date(year: 2026, month: 6, day: 25)
        _ = try repository.save(
            image: makeImage(),
            photoPlacement: PhotoPlacement(scale: 2, offsetX: 0.2, offsetY: -0.3),
            for: now,
            now: now
        )

        try repository.writeWidgetSnapshot(
            entries: repository.loadEntries(),
            selectedMonth: now,
            displayLanguage: .english,
            showsBranding: false
        )

        let snapshotURL = repository.widgetDirectoryURL.appendingPathComponent(PetCalendarWidgetSnapshot.fileName)
        let data = try Data(contentsOf: snapshotURL)
        let json = String(decoding: data, as: UTF8.self)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(PetCalendarWidgetSnapshot.self, from: data)

        XCTAssertEqual(snapshot.displayLanguage, .english)
        XCTAssertFalse(snapshot.showsBranding)
        XCTAssertEqual(snapshot.renderedImageSets.count, 2)
        XCTAssertFalse(json.contains("imageFileName"))
        XCTAssertFalse(json.contains("thumbnailFileName"))
        XCTAssertFalse(json.contains("caption"))
        XCTAssertFalse(json.contains("photoPlacement"))
        XCTAssertFalse(json.contains("overlayStyle"))

        for fileName in snapshot.renderedImageSets.flatMap(\.fileNames) {
            let url = repository.widgetDirectoryURL.appendingPathComponent(fileName)
            XCTAssertTrue(fileName.hasPrefix("pet-calendar-widget-"))
            XCTAssertTrue(fileName.hasSuffix(".jpg"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertGreaterThan((try? Data(contentsOf: url).count) ?? 0, 1_000)
        }
    }

    func testWidgetRenderedImagesArePrunedWhenSnapshotIsRegenerated() throws {
        let repository = try makeRepository()
        let now = date(year: 2026, month: 6, day: 25)
        _ = try repository.save(image: makeImage(), for: now, now: now)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshotURL = repository.widgetDirectoryURL.appendingPathComponent(PetCalendarWidgetSnapshot.fileName)
        let firstSnapshot = try decoder.decode(PetCalendarWidgetSnapshot.self, from: Data(contentsOf: snapshotURL))
        let firstFileNames = firstSnapshot.renderedImageSets.flatMap(\.fileNames)

        try repository.writeWidgetSnapshot(entries: repository.loadEntries(), selectedMonth: now)
        let secondSnapshot = try decoder.decode(PetCalendarWidgetSnapshot.self, from: Data(contentsOf: snapshotURL))
        let secondFileNames = secondSnapshot.renderedImageSets.flatMap(\.fileNames)
        let remainingWidgetImageNames = try widgetRenderedImageNames(in: repository.widgetDirectoryURL)

        XCTAssertNotEqual(firstFileNames, secondFileNames)
        for fileName in firstFileNames {
            XCTAssertFalse(FileManager.default.fileExists(atPath: repository.widgetDirectoryURL.appendingPathComponent(fileName).path))
        }
        for fileName in secondFileNames {
            XCTAssertTrue(FileManager.default.fileExists(atPath: repository.widgetDirectoryURL.appendingPathComponent(fileName).path))
        }
        XCTAssertEqual(Set(remainingWidgetImageNames), Set(secondFileNames))
    }

    func testLegacyAppGroupDataMigratesToApplicationSupportAndDeletesOldPrivateFiles() throws {
        let appRoot = makeTemporaryDirectory()
        let widgetRoot = makeTemporaryDirectory()
        let legacyRoot = makeTemporaryDirectory()
        let legacyCalendar = legacyRoot.appendingPathComponent("PetCalendar", isDirectory: true)
        let legacyImages = legacyCalendar.appendingPathComponent("Images", isDirectory: true)
        let legacyThumbnails = legacyCalendar.appendingPathComponent("Thumbnails", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyImages, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyThumbnails, withIntermediateDirectories: true)
        let entry = PetCalendarDayEntry(
            id: "2026-06-25",
            date: date(year: 2026, month: 6, day: 25),
            imageFileName: "legacy-image.jpg",
            thumbnailFileName: "legacy-thumb.jpg",
            caption: "",
            photoPlacement: .default,
            overlayStyle: .default,
            createdAt: date(year: 2026, month: 6, day: 25),
            updatedAt: date(year: 2026, month: 6, day: 25)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([entry]).write(to: legacyCalendar.appendingPathComponent("index.json"))
        try Data("image".utf8).write(to: legacyImages.appendingPathComponent("legacy-image.jpg"))
        try Data("thumb".utf8).write(to: legacyThumbnails.appendingPathComponent("legacy-thumb.jpg"))

        let repository = try PetCalendarRepository(
            appRootURL: appRoot,
            widgetRootURL: widgetRoot,
            legacyAppGroupRootURL: legacyRoot,
            calendar: testCalendar
        )

        XCTAssertEqual(repository.loadEntries().map(\.id), ["2026-06-25"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: appRoot.appendingPathComponent("PetCalendar/index.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: appRoot.appendingPathComponent("PetCalendar/Images/legacy-image.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: appRoot.appendingPathComponent("PetCalendar/Thumbnails/legacy-thumb.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: widgetRoot.appendingPathComponent("PetCalendarWidget/\(PetCalendarWidgetSnapshot.fileName)").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyCalendar.appendingPathComponent("index.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyImages.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyThumbnails.path))
    }

    func testLegacyMigrationFailureKeepsOldData() throws {
        let appRoot = makeTemporaryDirectory()
        let widgetRoot = makeTemporaryDirectory()
        let legacyRoot = makeTemporaryDirectory()
        let legacyCalendar = legacyRoot.appendingPathComponent("PetCalendar", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyCalendar, withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: legacyCalendar.appendingPathComponent("index.json"))
        try FileManager.default.createDirectory(at: appRoot, withIntermediateDirectories: true)
        try Data("not a directory".utf8).write(to: appRoot.appendingPathComponent("PetCalendar"))

        _ = try PetCalendarRepository(
            appRootURL: appRoot,
            widgetRootURL: widgetRoot,
            legacyAppGroupRootURL: legacyRoot,
            calendar: testCalendar
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyCalendar.appendingPathComponent("index.json").path))
    }

    func testFileProtectionPoliciesAreAppliedToAppAndWidgetData() throws {
        let repository = try makeRepository()
        let now = date(year: 2026, month: 6, day: 25)
        let entry = try repository.save(image: makeImage(), for: now, now: now)

        let imageURL = repository.appCalendarDirectoryURL
            .appendingPathComponent("Images", isDirectory: true)
            .appendingPathComponent(try XCTUnwrap(entry.imageFileName))
        let snapshotURL = repository.widgetDirectoryURL.appendingPathComponent(PetCalendarWidgetSnapshot.fileName)

        XCTAssertEqual(PetCalendarRepository.appDataFileProtection, FileProtectionType.complete)
        XCTAssertEqual(
            PetCalendarRepository.widgetDataFileProtection,
            FileProtectionType.completeUntilFirstUserAuthentication
        )

        if let imageProtection = fileProtection(at: imageURL) {
            XCTAssertEqual(imageProtection, PetCalendarRepository.appDataFileProtection)
        }
        if let snapshotProtection = fileProtection(at: snapshotURL) {
            XCTAssertEqual(snapshotProtection, PetCalendarRepository.widgetDataFileProtection)
        }
    }

    private func makeRepository() throws -> PetCalendarRepository {
        try PetCalendarRepository(
            appRootURL: makeTemporaryDirectory(),
            widgetRootURL: makeTemporaryDirectory(),
            calendar: testCalendar
        )
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectories.append(directory)
        return directory
    }

    private var testCalendar: Calendar {
        PetCalendarDateRules.gregorianCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = testCalendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return components.date ?? Date(timeIntervalSince1970: 0)
    }

    private func makeImage(size: CGSize = CGSize(width: 640, height: 480), color: UIColor = .red) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func fileProtection(at url: URL) -> FileProtectionType? {
        let value = try? FileManager.default.attributesOfItem(atPath: url.path)[.protectionKey]
        if let protection = value as? FileProtectionType {
            return protection
        }
        if let rawValue = value as? String {
            return FileProtectionType(rawValue: rawValue)
        }
        if let rawValue = value as? NSString {
            return FileProtectionType(rawValue: rawValue as String)
        }
        return nil
    }

    private func widgetRenderedImageNames(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix("pet-calendar-widget-") && $0.hasSuffix(".jpg") }
            .sorted()
    }
}
