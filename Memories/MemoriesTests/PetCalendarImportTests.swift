import XCTest
import UIKit
@testable import Memories

@MainActor
final class PetCalendarImportTests: XCTestCase {
    func testMetadataReaderUsesNoLocationSuggestionForCalendarImports() async {
        var receivedFlags: [Bool] = []
        let reader = PetCalendarImportPlanner.makeMetadataReader { _, allowsLocationSuggestion in
            receivedFlags.append(allowsLocationSuggestion)
            return PhotoMetadata(capturedAt: nil, locationText: "ignored")
        }

        _ = await reader(Data([1, 2, 3]))

        XCTAssertEqual(receivedFlags, [false])
    }

    func testPhotoCaptureDatesCreateCandidates() async {
        let capturedAt = date(year: 2026, month: 6, day: 20, hour: 10)
        let planner = PetCalendarImportPlanner(calendar: testCalendar)
        let payloads = [(data: Data([1]), image: makeImage())]

        let candidates = await planner.makeCandidates(from: payloads) { _ in
            PhotoMetadata(capturedAt: capturedAt, locationText: nil)
        }

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.capturedAt, capturedAt)
    }

    func testUndatedPhotosNeedManualDate() {
        let planner = PetCalendarImportPlanner(calendar: testCalendar)
        let candidate = PetCalendarImportCandidate(image: makeImage(), imageData: Data([1]), capturedAt: nil, sourceIndex: 0)

        let groups = planner.groups(for: [candidate], now: date(year: 2026, month: 6, day: 25))

        XCTAssertEqual(groups.count, 1)
        XCTAssertNil(groups.first?.date)
        XCTAssertTrue(groups.first?.requiresUserDecision == true)
        XCTAssertTrue(planner.plannedEntries(from: groups).isEmpty)
    }

    func testFuturePhotosAreMarkedUnavailable() {
        let planner = PetCalendarImportPlanner(calendar: testCalendar)
        let now = date(year: 2026, month: 6, day: 25)
        let future = date(year: 2026, month: 6, day: 26)
        let candidate = PetCalendarImportCandidate(image: makeImage(), imageData: Data([1]), capturedAt: future, sourceIndex: 0)

        let groups = planner.groups(for: [candidate], now: now)

        XCTAssertEqual(groups.first?.id, "2026-06-26")
        XCTAssertTrue(groups.first?.isFutureDate == true)
        XCTAssertTrue(planner.plannedEntries(from: groups, now: now).isEmpty)
    }

    func testMultiplePhotosOnSameDateAreGroupedAndLatestIsSelected() throws {
        let planner = PetCalendarImportPlanner(calendar: testCalendar)
        let older = PetCalendarImportCandidate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            image: makeImage(color: .red),
            imageData: Data([1]),
            capturedAt: date(year: 2026, month: 6, day: 20, hour: 8),
            sourceIndex: 0
        )
        let newer = PetCalendarImportCandidate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
            image: makeImage(color: .blue),
            imageData: Data([2]),
            capturedAt: date(year: 2026, month: 6, day: 20, hour: 20),
            sourceIndex: 1
        )

        let groups = planner.groups(for: [older, newer], now: date(year: 2026, month: 6, day: 25))

        let group = try XCTUnwrap(groups.first)
        XCTAssertEqual(group.id, "2026-06-20")
        XCTAssertEqual(group.candidates.count, 2)
        XCTAssertTrue(group.requiresUserDecision)
        XCTAssertEqual(group.selectedCandidateID, newer.id)
    }

    func testExistingEntriesAreKeptUntilUserChoosesReplacement() throws {
        let planner = PetCalendarImportPlanner(calendar: testCalendar)
        let targetDate = date(year: 2026, month: 6, day: 20)
        let candidate = PetCalendarImportCandidate(image: makeImage(), imageData: Data([1]), capturedAt: targetDate, sourceIndex: 0)
        let existing = PetCalendarDayEntry(
            id: "2026-06-20",
            date: targetDate,
            imageFileName: "old-image.jpg",
            thumbnailFileName: "old-thumb.jpg",
            caption: "old",
            createdAt: targetDate,
            updatedAt: targetDate
        )

        var groups = planner.groups(for: [candidate], existingEntries: [existing], now: date(year: 2026, month: 6, day: 25))

        XCTAssertEqual(groups.first?.action, .keepExisting)
        XCTAssertTrue(planner.plannedEntries(from: groups).isEmpty)

        groups[0].action = .replaceExisting
        let plans = planner.plannedEntries(from: groups, now: date(year: 2026, month: 6, day: 25))
        XCTAssertEqual(plans.count, 1)
        XCTAssertTrue(plans[0].replacesExisting)
    }

    func testPlannedEntriesAreOnePerDate() {
        let planner = PetCalendarImportPlanner(calendar: testCalendar)
        let day = date(year: 2026, month: 6, day: 20)
        let candidates = [
            PetCalendarImportCandidate(image: makeImage(color: .red), imageData: Data([1]), capturedAt: day, sourceIndex: 0),
            PetCalendarImportCandidate(image: makeImage(color: .blue), imageData: Data([2]), capturedAt: day.addingTimeInterval(60), sourceIndex: 1)
        ]

        let groups = planner.groups(for: candidates, now: date(year: 2026, month: 6, day: 25))
        let plans = planner.plannedEntries(from: groups, now: date(year: 2026, month: 6, day: 25))

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.id, "2026-06-20")
    }

    private var testCalendar: Calendar {
        PetCalendarDateRules.gregorianCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.calendar = testCalendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date ?? Date(timeIntervalSince1970: 0)
    }

    private func makeImage(color: UIColor = .red) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
    }
}
