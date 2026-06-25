import XCTest
@testable import Memories

@MainActor
final class PetCalendarDateTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for suiteName in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testSundayStartingMonthGridIncludesLeadingCells() {
        let calendar = testCalendar
        let month = date(year: 2026, month: 6, day: 1)
        let now = date(year: 2026, month: 6, day: 25)

        let cells = PetCalendarDateRules.monthGrid(for: month, now: now, calendar: calendar)

        XCTAssertEqual(cells.count, 35)
        XCTAssertEqual(cells[0].id, "2026-05-31")
        XCTAssertFalse(cells[0].isInDisplayedMonth)
        XCTAssertEqual(cells[1].id, "2026-06-01")
        XCTAssertTrue(cells[1].isInDisplayedMonth)
        XCTAssertEqual(cells.last?.id, "2026-07-04")
    }

    func testMonthGridSupportsSixWeekMonths() {
        let calendar = testCalendar
        let month = date(year: 2026, month: 8, day: 1)

        let cells = PetCalendarDateRules.monthGrid(for: month, now: date(year: 2026, month: 8, day: 31), calendar: calendar)

        XCTAssertEqual(cells.count, 42)
        XCTAssertEqual(cells[0].id, "2026-07-26")
        XCTAssertEqual(cells[41].id, "2026-09-05")
    }

    func testTodayPastAndFutureRegistrationRulesIgnoreTime() {
        let calendar = testCalendar
        let now = date(year: 2026, month: 6, day: 25, hour: 22)
        let todayMorning = date(year: 2026, month: 6, day: 25, hour: 1)
        let yesterday = date(year: 2026, month: 6, day: 24, hour: 23)
        let tomorrow = date(year: 2026, month: 6, day: 26, hour: 0)

        XCTAssertTrue(PetCalendarDateRules.canRegisterPhoto(for: todayMorning, now: now, calendar: calendar))
        XCTAssertTrue(PetCalendarDateRules.canRegisterPhoto(for: yesterday, now: now, calendar: calendar))
        XCTAssertFalse(PetCalendarDateRules.canRegisterPhoto(for: tomorrow, now: now, calendar: calendar))
    }

    func testJapaneseAndEnglishCalendarLabels() {
        let calendar = testCalendar
        let month = date(year: 2026, month: 6, day: 15)

        XCTAssertEqual(PetCalendarDateRules.monthTitle(for: month, language: .japanese, calendar: calendar), "2026年6月")
        XCTAssertEqual(PetCalendarDateRules.weekdaySymbols(language: .japanese), ["日", "月", "火", "水", "木", "金", "土"])
        XCTAssertEqual(PetCalendarDateRules.monthTitle(for: month, language: .english, calendar: calendar), "June 2026")
        XCTAssertEqual(PetCalendarDateRules.weekdaySymbols(language: .english), ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
    }

    func testCalendarDisplayLanguageIsStoredSeparatelyFromAppLanguage() {
        let defaults = makeDefaults()
        let appState = MemoriesAppState(defaults: defaults)

        appState.appLanguage = .english
        appState.petCalendarDisplayLanguage = .japanese

        let reloaded = MemoriesAppState(defaults: defaults)
        XCTAssertEqual(reloaded.appLanguage, .english)
        XCTAssertEqual(reloaded.petCalendarDisplayLanguage, .japanese)
    }

    func testPhotoPlacementClampsScaleAndOffsets() {
        let placement = PhotoPlacement(scale: 5, offsetX: -2, offsetY: 2).clamped

        XCTAssertEqual(placement.scale, 3)
        XCTAssertEqual(placement.offsetX, -1)
        XCTAssertEqual(placement.offsetY, 1)
    }

    func testWeekModelStartsOnSundayAndIncludesToday() {
        let calendar = testCalendar
        let today = date(year: 2026, month: 6, day: 25)
        let registeredIDs: Set<String> = ["2026-06-21", "2026-06-25"]

        let week = PetCalendarDateRules.week(
            containing: today,
            now: today,
            registeredEntryIDs: registeredIDs,
            calendar: calendar
        )

        XCTAssertEqual(week.map(\.id), [
            "2026-06-21",
            "2026-06-22",
            "2026-06-23",
            "2026-06-24",
            "2026-06-25",
            "2026-06-26",
            "2026-06-27"
        ])
        XCTAssertEqual(week.first?.isRegistered, true)
        XCTAssertEqual(week[4].isToday, true)
        XCTAssertEqual(week[4].isRegistered, true)
        XCTAssertEqual(week[5].isFuture, true)
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

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.myfs716.Memories.calendar.tests.\(UUID().uuidString)"
        suiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
