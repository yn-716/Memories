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

    func testRepositoryStoresAndRestoresPhotoPlacement() throws {
        let repository = try makeRepository()
        let now = date(year: 2026, month: 6, day: 25)
        let placement = PhotoPlacement(scale: 2.25, offsetX: 0.42, offsetY: -0.38)

        let entry = try repository.save(
            image: makeImage(),
            photoPlacement: placement,
            for: now,
            now: now
        )

        XCTAssertEqual(entry.photoPlacement, placement)
        XCTAssertEqual(repository.entry(for: now)?.photoPlacement, placement)
    }

    func testRepositoryDefaultsOverlayStyleOnNewSaves() throws {
        let repository = try makeRepository()
        let now = date(year: 2026, month: 6, day: 25)

        let entry = try repository.save(
            image: makeImage(),
            for: now,
            now: now
        )

        XCTAssertEqual(entry.overlayStyle, .default)
        XCTAssertEqual(repository.entry(for: now)?.overlayStyle, .default)
    }

    func testRepositorySavesWeatherOnlyCalendarEntry() throws {
        let rootURL = makeTemporaryDirectory()
        let repository = try PetCalendarRepository(rootURL: rootURL, calendar: testCalendar)
        let now = date(year: 2026, month: 6, day: 25)
        var overlayStyle = PetCalendarOverlayStyle.default
        overlayStyle.isWeatherIconVisible = true
        overlayStyle.weatherIcon = .rainy
        overlayStyle.weatherIconCorner = .topRight
        overlayStyle.accentColor = .blue

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

        let snapshotURL = rootURL
            .appendingPathComponent("PetCalendar/Widget", isDirectory: true)
            .appendingPathComponent(PetCalendarWidgetSnapshot.fileName)
        let data = try Data(contentsOf: snapshotURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(PetCalendarWidgetSnapshot.self, from: data)

        XCTAssertNil(snapshot.entries.first?.thumbnailFileName)
        XCTAssertNil(snapshot.entries.first?.imageFileName)
        XCTAssertEqual(snapshot.entries.first?.overlayStyle, overlayStyle)
    }

    func testRepositoryClampsSavedPhotoPlacement() throws {
        let repository = try makeRepository()
        let now = date(year: 2026, month: 6, day: 25)

        let entry = try repository.save(
            image: makeImage(),
            photoPlacement: PhotoPlacement(scale: 8, offsetX: -4, offsetY: 3),
            for: now,
            now: now
        )

        XCTAssertEqual(entry.photoPlacement.scale, 3)
        XCTAssertEqual(entry.photoPlacement.offsetX, -1)
        XCTAssertEqual(entry.photoPlacement.offsetY, 1)
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

    func testRepositoryStoresResizedDisplayImageThumbnailAndStorageSize() throws {
        let repository = try makeRepository()
        let now = date(year: 2026, month: 6, day: 25)
        let sourceImage = makeImage(size: CGSize(width: 2400, height: 1200), color: .green)

        let entry = try repository.save(image: sourceImage, caption: "", for: now, now: now)
        let displayImage = try XCTUnwrap(repository.image(for: entry))
        let thumbnail = try XCTUnwrap(repository.thumbnail(for: entry))

        XCTAssertLessThanOrEqual(max(displayImage.size.width, displayImage.size.height), PetCalendarConstants.displayImageMaxLongSide)
        XCTAssertLessThanOrEqual(max(thumbnail.size.width, thumbnail.size.height), PetCalendarConstants.thumbnailMaxLongSide)
        XCTAssertGreaterThan(repository.storageSize(), 0)
    }

    func testWidgetSnapshotIsSavedWithThumbnailReferences() throws {
        let rootURL = makeTemporaryDirectory()
        let repository = try PetCalendarRepository(rootURL: rootURL, calendar: testCalendar)
        let now = date(year: 2026, month: 6, day: 25)
        let entry = try repository.save(image: makeImage(), caption: "today", for: now, now: now)

        let snapshotURL = rootURL
            .appendingPathComponent("PetCalendar/Widget", isDirectory: true)
            .appendingPathComponent(PetCalendarWidgetSnapshot.fileName)
        let data = try Data(contentsOf: snapshotURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(PetCalendarWidgetSnapshot.self, from: data)

        XCTAssertEqual(snapshot.entries.count, 1)
        XCTAssertEqual(snapshot.entries.first?.imageFileName, entry.imageFileName)
        XCTAssertEqual(snapshot.entries.first?.thumbnailFileName, entry.thumbnailFileName)
        XCTAssertEqual(snapshot.entries.first?.caption, "")
        XCTAssertEqual(snapshot.entries.first?.photoPlacement, .default)
        XCTAssertEqual(snapshot.entries.first?.overlayStyle, .default)
        XCTAssertEqual(snapshot.displayLanguage, .japanese)
        XCTAssertTrue(snapshot.showsBranding)
        XCTAssertFalse(snapshot.entries.first?.thumbnailFileName == entry.imageFileName)
    }

    func testWidgetSnapshotStoresDisplayLanguageBrandingAndDefaultOverlayStyle() throws {
        let rootURL = makeTemporaryDirectory()
        let repository = try PetCalendarRepository(rootURL: rootURL, calendar: testCalendar)
        let now = date(year: 2026, month: 6, day: 25)
        _ = try repository.save(image: makeImage(), for: now, now: now)

        try repository.writeWidgetSnapshot(
            entries: repository.loadEntries(),
            selectedMonth: now,
            displayLanguage: .english,
            showsBranding: false
        )

        let snapshotURL = rootURL
            .appendingPathComponent("PetCalendar/Widget", isDirectory: true)
            .appendingPathComponent(PetCalendarWidgetSnapshot.fileName)
        let data = try Data(contentsOf: snapshotURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(PetCalendarWidgetSnapshot.self, from: data)

        XCTAssertEqual(snapshot.displayLanguage, .english)
        XCTAssertFalse(snapshot.showsBranding)
        XCTAssertEqual(snapshot.entries.first?.overlayStyle, .default)
    }

    private func makeRepository() throws -> PetCalendarRepository {
        try PetCalendarRepository(rootURL: makeTemporaryDirectory(), calendar: testCalendar)
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
}
