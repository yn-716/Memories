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

    func testWidgetSnapshotCanUseInjectedWidgetDirectoryAndOnlyReferencesRenderedImages() throws {
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

    func testWidgetSnapshotDecodesLegacyJSONByIgnoringEntryPayload() throws {
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
        XCTAssertTrue(snapshot.renderedImageSets.isEmpty)
    }

    func testWidgetSnapshotStoresBrandingFromFreshEntitlementPolicy() throws {
        let now = date(year: 2026, month: 6, day: 25)
        let staleLifetime = EntitlementState(
            sevenDayPassExpiresAt: nil,
            hasLifetimePass: true,
            lastTransactionCheckAt: now.addingTimeInterval(-(EntitlementFreshnessPolicy.maxTrustedAge + 10))
        )
        let freshLifetime = EntitlementState(
            sevenDayPassExpiresAt: nil,
            hasLifetimePass: true,
            lastTransactionCheckAt: now
        )

        XCTAssertTrue(WatermarkAccessPolicy(entitlementState: staleLifetime, now: now, debugOverride: .none).snapshot.hasUnlimitedAccess == false)
        XCTAssertFalse(widgetShowsBranding(for: freshLifetime, now: now))
        XCTAssertTrue(widgetShowsBranding(for: .free, now: now))
    }

    private func widgetShowsBranding(for state: EntitlementState, now: Date) -> Bool {
        !WatermarkAccessPolicy(entitlementState: state, now: now, debugOverride: .none).snapshot.hasUnlimitedAccess
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

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60)).image { context in
            UIColor.purple.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        }
    }
}
