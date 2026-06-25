import XCTest
@testable import Memories

final class DeepLinkTests: XCTestCase {
    func testCalendarDeepLinkRoutesToPetCalendar() throws {
        let url = try XCTUnwrap(URL(string: "memories://calendar"))

        XCTAssertEqual(MemoriesDeepLinkRouter.route(for: url), .petCalendar)
    }

    func testCalendarTodayDeepLinkRoutesToTodayFlow() throws {
        let url = try XCTUnwrap(URL(string: "memories://calendar/today"))

        XCTAssertEqual(MemoriesDeepLinkRouter.route(for: url), .petCalendarToday)
    }

    func testInvalidDeepLinksReturnNilWithoutCrashing() throws {
        XCTAssertNil(MemoriesDeepLinkRouter.route(for: try XCTUnwrap(URL(string: "memories://settings"))))
        XCTAssertNil(MemoriesDeepLinkRouter.route(for: try XCTUnwrap(URL(string: "https://example.com/calendar"))))
    }
}
