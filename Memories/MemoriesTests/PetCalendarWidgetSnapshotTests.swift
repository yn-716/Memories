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
        let entry = try repository.save(image: makeImage(), caption: "hi", for: now, now: now)

        try repository.writeWidgetSnapshot(entries: repository.loadEntries(), selectedMonth: now)

        let snapshotURL = repository.widgetDirectoryURL.appendingPathComponent(PetCalendarWidgetSnapshot.fileName)
        let data = try Data(contentsOf: snapshotURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(PetCalendarWidgetSnapshot.self, from: data)

        XCTAssertEqual(snapshot.entries.first?.id, "2026-06-25")
        XCTAssertEqual(snapshot.entries.first?.thumbnailFileName, entry.thumbnailFileName)
        XCTAssertNotEqual(snapshot.entries.first?.thumbnailFileName, entry.imageFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: repository.thumbnailURL(for: entry).path))
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
