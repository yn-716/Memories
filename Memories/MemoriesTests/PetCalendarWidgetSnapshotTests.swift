import XCTest
import UIKit
@testable import Memories

@MainActor
final class PetCalendarWidgetSnapshotTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDown() {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        super.tearDown()
    }

    func testWidgetSnapshotCanUseInjectedDirectoryAndReferencesThumbnails() throws {
        let rootURL = makeTemporaryDirectory()
        let repository = try PetCalendarRepository(rootURL: rootURL, calendar: testCalendar)
        let now = date(year: 2026, month: 6, day: 25)
        let placement = PhotoPlacement(scale: 2, offsetX: 0.2, offsetY: -0.3)
        let entry = try repository.save(
            image: makeImage(),
            caption: "hi",
            photoPlacement: placement,
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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(PetCalendarWidgetSnapshot.self, from: data)

        XCTAssertEqual(snapshot.entries.first?.id, "2026-06-25")
        XCTAssertEqual(snapshot.entries.first?.thumbnailFileName, entry.thumbnailFileName)
        XCTAssertEqual(snapshot.entries.first?.caption, "")
        XCTAssertEqual(snapshot.entries.first?.photoPlacement, placement)
        XCTAssertEqual(snapshot.entries.first?.overlayStyle, .default)
        XCTAssertEqual(snapshot.displayLanguage, .english)
        XCTAssertFalse(snapshot.showsBranding)
        XCTAssertNotEqual(snapshot.entries.first?.thumbnailFileName, entry.imageFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: repository.thumbnailURL(for: entry).path))
    }

    func testWidgetSnapshotDecodesLegacyJSONWithoutLanguageBrandingOrOverlayStyle() throws {
        let json = """
        {
          "updatedAt": "2026-06-25T00:00:00Z",
          "selectedMonth": "2026-06-01T00:00:00Z",
          "entries": [
            {
              "id": "2026-06-25",
              "date": "2026-06-25T00:00:00Z",
              "thumbnailFileName": "thumb.jpg",
              "caption": "legacy"
            }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snapshot = try decoder.decode(PetCalendarWidgetSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(snapshot.displayLanguage, .japanese)
        XCTAssertTrue(snapshot.showsBranding)
        XCTAssertEqual(snapshot.entries.first?.photoPlacement, .default)
        XCTAssertEqual(snapshot.entries.first?.overlayStyle, .default)
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

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60)).image { context in
            UIColor.purple.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        }
    }
}
