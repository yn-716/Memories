import XCTest
import UIKit
@testable import Memories

@MainActor
final class PetCalendarRenderingTests: XCTestCase {
    func testRendererReturnsImage() {
        let renderer = PetCalendarRenderer(calendar: testCalendar)
        let image = renderer.render(
            configuration: PetCalendarRenderConfiguration(
                month: date(year: 2026, month: 6, day: 1),
                entries: [],
                displayLanguage: .english,
                watermarkMode: .hidden,
                now: date(year: 2026, month: 6, day: 25),
                size: CGSize(width: 700, height: 900)
            )
        )

        XCTAssertEqual(image.size.width, 700)
        XCTAssertEqual(image.size.height, 900)
    }

    func testRegisteredDaysProvideThumbnailsAndUnregisteredDaysUseDefaultDrawingPath() {
        let entry = PetCalendarRenderEntry(
            date: date(year: 2026, month: 6, day: 20),
            caption: "cute",
            thumbnail: makeImage(color: .blue)
        )
        let renderer = PetCalendarRenderer(calendar: testCalendar)

        let image = renderer.render(
            configuration: PetCalendarRenderConfiguration(
                month: date(year: 2026, month: 6, day: 1),
                entries: [entry],
                displayLanguage: .japanese,
                watermarkMode: .hidden,
                now: date(year: 2026, month: 6, day: 25),
                size: CGSize(width: 700, height: 900)
            )
        )

        XCTAssertEqual(image.size, CGSize(width: 700, height: 900))
    }

    func testMonthGridMarksOutsideMonthSeparatelyFromUnregisteredDays() {
        let cells = PetCalendarDateRules.monthGrid(
            for: date(year: 2026, month: 6, day: 1),
            now: date(year: 2026, month: 6, day: 25),
            calendar: testCalendar
        )

        XCTAssertEqual(cells.first?.id, "2026-05-31")
        XCTAssertFalse(cells.first?.isInDisplayedMonth == true)
    }

    func testWatermarkDrawerIsCalledOnceForVisibleCalendarWatermark() {
        let spy = SpyCalendarWatermarkDrawer()
        let renderer = PetCalendarRenderer(calendar: testCalendar, watermarkDrawer: spy)

        _ = renderer.render(
            configuration: PetCalendarRenderConfiguration(
                month: date(year: 2026, month: 6, day: 1),
                entries: [],
                displayLanguage: .english,
                watermarkMode: .visible,
                now: date(year: 2026, month: 6, day: 25),
                size: CGSize(width: 700, height: 900)
            )
        )

        XCTAssertEqual(spy.callCount, 1)
    }

    func testWatermarkDrawerIsNotCalledWhenHidden() {
        let spy = SpyCalendarWatermarkDrawer()
        let renderer = PetCalendarRenderer(calendar: testCalendar, watermarkDrawer: spy)

        _ = renderer.render(
            configuration: PetCalendarRenderConfiguration(
                month: date(year: 2026, month: 6, day: 1),
                entries: [],
                displayLanguage: .english,
                watermarkMode: .hidden,
                now: date(year: 2026, month: 6, day: 25),
                size: CGSize(width: 700, height: 900)
            )
        )

        XCTAssertEqual(spy.callCount, 0)
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

    private func makeImage(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }
}

private final class SpyCalendarWatermarkDrawer: CalendarWatermarkDrawing {
    var callCount = 0

    func drawCalendarWatermark(mode: WatermarkMode, in context: CGContext, size: CGSize, bounds: CGRect) {
        callCount += 1
    }
}
