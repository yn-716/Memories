import XCTest
@testable import Memories

@MainActor
final class PetCalendarWatermarkTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for suiteName in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testFreeUserCalendarDefaultsToWatermarkAndCanAlwaysSelectWatermark() {
        let snapshot = WatermarkAccessSnapshot(
            canExportWithoutWatermark: true,
            remainingFreeExportsToday: 1,
            hasUnlimitedAccess: false
        )

        XCTAssertEqual(CalendarWatermarkExportRules.initialOption(for: snapshot), .withWatermark)
        XCTAssertTrue(CalendarWatermarkExportRules.canSelect(.withWatermark, snapshot: snapshot))
        XCTAssertTrue(CalendarWatermarkExportRules.canSelect(.withoutWatermark, snapshot: snapshot))
        XCTAssertTrue(CalendarWatermarkExportRules.shouldConsumeAllowance(afterSuccessfulOutput: .withoutWatermark, snapshot: snapshot))
        XCTAssertFalse(CalendarWatermarkExportRules.shouldConsumeAllowance(afterSuccessfulOutput: .withWatermark, snapshot: snapshot))
    }

    func testFreeUserCannotSelectWatermarkFreeAfterDailyAllowanceIsUsed() {
        let snapshot = WatermarkAccessSnapshot(
            canExportWithoutWatermark: false,
            remainingFreeExportsToday: 0,
            hasUnlimitedAccess: false
        )

        XCTAssertEqual(CalendarWatermarkExportRules.initialOption(for: snapshot), .withWatermark)
        XCTAssertTrue(CalendarWatermarkExportRules.canSelect(.withWatermark, snapshot: snapshot))
        XCTAssertFalse(CalendarWatermarkExportRules.canSelect(.withoutWatermark, snapshot: snapshot))
    }

    func testSevenDayAndLifetimePassDefaultToWatermarkFreeWithoutConsumingAllowance() {
        let snapshot = WatermarkAccessSnapshot(
            canExportWithoutWatermark: true,
            remainingFreeExportsToday: 0,
            hasUnlimitedAccess: true
        )

        XCTAssertEqual(CalendarWatermarkExportRules.initialOption(for: snapshot), .withoutWatermark)
        XCTAssertTrue(CalendarWatermarkExportRules.canSelect(.withWatermark, snapshot: snapshot))
        XCTAssertTrue(CalendarWatermarkExportRules.canSelect(.withoutWatermark, snapshot: snapshot))
        XCTAssertFalse(CalendarWatermarkExportRules.shouldConsumeAllowance(afterSuccessfulOutput: .withoutWatermark, snapshot: snapshot))
    }

    func testCalendarAndImageEditorShareDailyFreeAllowance() {
        let defaults = makeDefaults()
        let store = DailyWatermarkFreeExportStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let imageEditorPolicy = WatermarkAccessPolicy(
            entitlementState: .free,
            freeExportStore: store,
            now: now,
            debugOverride: .none
        )

        XCTAssertTrue(imageEditorPolicy.consumeIfNeeded(for: .withoutWatermark))

        let calendarPolicy = WatermarkAccessPolicy(
            entitlementState: .free,
            freeExportStore: store,
            now: now,
            debugOverride: .none
        )

        XCTAssertFalse(calendarPolicy.snapshot.canExportWithoutWatermark)
        XCTAssertFalse(CalendarWatermarkExportRules.canSelect(.withoutWatermark, snapshot: calendarPolicy.snapshot))

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
        let tomorrowPolicy = WatermarkAccessPolicy(
            entitlementState: .free,
            freeExportStore: store,
            now: tomorrow,
            debugOverride: .none
        )
        XCTAssertTrue(tomorrowPolicy.snapshot.canExportWithoutWatermark)
    }

    func testCalendarConsumptionMakesImageEditorUnavailableSameDay() {
        let defaults = makeDefaults()
        let store = DailyWatermarkFreeExportStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendarPolicy = WatermarkAccessPolicy(
            entitlementState: .free,
            freeExportStore: store,
            now: now,
            debugOverride: .none
        )

        XCTAssertTrue(calendarPolicy.consumeIfNeeded(for: .withoutWatermark))

        let imageEditorPolicy = WatermarkAccessPolicy(
            entitlementState: .free,
            freeExportStore: store,
            now: now,
            debugOverride: .none
        )

        XCTAssertFalse(imageEditorPolicy.canExport(option: .withoutWatermark))
    }

    func testCancelledOrFailedCalendarOutputDoesNotConsumeAllowanceWhenPolicyIsNotCalled() {
        let defaults = makeDefaults()
        let store = DailyWatermarkFreeExportStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let policy = WatermarkAccessPolicy(
            entitlementState: .free,
            freeExportStore: store,
            now: now,
            debugOverride: .none
        )
        let snapshot = policy.snapshot

        XCTAssertTrue(CalendarWatermarkExportRules.shouldConsumeAllowance(afterSuccessfulOutput: .withoutWatermark, snapshot: snapshot))
        XCTAssertEqual(store.remainingExports(on: now), 1)
    }

    func testWidgetDisplayDoesNotConsumeWatermarkAllowance() {
        let defaults = makeDefaults()
        let store = DailyWatermarkFreeExportStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        _ = WatermarkAccessPolicy(entitlementState: .free, freeExportStore: store, now: now, debugOverride: .none).snapshot

        XCTAssertEqual(store.remainingExports(on: now), 1)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.myfs716.Memories.calendar.watermark.tests.\(UUID().uuidString)"
        suiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
