import XCTest
@testable import Memories

@MainActor
final class BillingLogicTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for suiteName in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testSevenDayPassExpiresSevenDaysAfterPurchaseAndHonorsBoundary() throws {
        let appState = MemoriesAppState(defaults: makeDefaults())
        let purchaseDate = Date(timeIntervalSince1970: 1_800_000_000)
        let expectedExpiry = Calendar.current.date(byAdding: .day, value: 7, to: purchaseDate)

        XCTAssertTrue(
            appState.applyPurchasedProduct(
                id: PurchaseProductID.sevenDayPass.rawValue,
                purchaseDate: purchaseDate
            )
        )

        let actualExpiry = try XCTUnwrap(appState.entitlementState.sevenDayPassExpiresAt)
        XCTAssertEqual(actualExpiry.timeIntervalSince1970, try XCTUnwrap(expectedExpiry).timeIntervalSince1970, accuracy: 0.001)
        XCTAssertTrue(appState.entitlementState.grantsUnlimitedWatermarkFreeOutput(on: actualExpiry.addingTimeInterval(-0.001)))
        XCTAssertFalse(appState.entitlementState.grantsUnlimitedWatermarkFreeOutput(on: actualExpiry))
        XCTAssertFalse(appState.entitlementState.grantsUnlimitedWatermarkFreeOutput(on: actualExpiry.addingTimeInterval(0.001)))
    }

    func testLifetimePassGrantsUnlimitedAccessEvenWhenSevenDayPassIsExpired() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expiredSevenDayPass = now.addingTimeInterval(-1)
        let state = EntitlementState(
            sevenDayPassExpiresAt: expiredSevenDayPass,
            hasLifetimePass: true,
            lastTransactionCheckAt: nil
        )

        XCTAssertTrue(state.grantsUnlimitedWatermarkFreeOutput(on: now))
        XCTAssertFalse(state.isSevenDayPassActive(on: now))
    }

    func testReplacingEntitlementsClearsStaleLocalPasses() throws {
        let appState = MemoriesAppState(defaults: makeDefaults())
        let purchaseDate = Date(timeIntervalSince1970: 1_800_000_000)
        let checkedAt = purchaseDate.addingTimeInterval(60)

        appState.grantSevenDayPass(from: purchaseDate)
        appState.grantLifetimePass()
        XCTAssertTrue(appState.entitlementState.grantsUnlimitedWatermarkFreeOutput(on: checkedAt))

        appState.replaceEntitlementState(
            sevenDayPassExpiresAt: nil,
            hasLifetimePass: false,
            checkedAt: checkedAt
        )

        XCTAssertNil(appState.entitlementState.sevenDayPassExpiresAt)
        XCTAssertFalse(appState.entitlementState.hasLifetimePass)
        XCTAssertFalse(appState.entitlementState.grantsUnlimitedWatermarkFreeOutput(on: checkedAt))
        XCTAssertEqual(
            try XCTUnwrap(appState.entitlementState.lastTransactionCheckAt).timeIntervalSince1970,
            checkedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testFreeWatermarkFreeExportCanBeConsumedOncePerCalendarDay() {
        let defaults = makeDefaults()
        let freeExportStore = DailyWatermarkFreeExportStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let policy = WatermarkAccessPolicy(
            entitlementState: .free,
            freeExportStore: freeExportStore,
            now: now,
            debugOverride: .none
        )

        XCTAssertEqual(policy.snapshot.remainingFreeExportsToday, 1)
        XCTAssertTrue(policy.canExport(option: .withoutWatermark))
        XCTAssertTrue(policy.consumeIfNeeded(for: .withoutWatermark))
        XCTAssertFalse(policy.consumeIfNeeded(for: .withoutWatermark))
        XCTAssertFalse(policy.snapshot.canExportWithoutWatermark)
        XCTAssertEqual(policy.snapshot.remainingFreeExportsToday, 0)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
        let tomorrowPolicy = WatermarkAccessPolicy(
            entitlementState: .free,
            freeExportStore: freeExportStore,
            now: tomorrow,
            debugOverride: .none
        )

        XCTAssertEqual(tomorrowPolicy.snapshot.remainingFreeExportsToday, 1)
        XCTAssertTrue(tomorrowPolicy.canExport(option: .withoutWatermark))
    }

    func testUnlimitedPassDoesNotConsumeDailyFreeExport() {
        let defaults = makeDefaults()
        let freeExportStore = DailyWatermarkFreeExportStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = EntitlementState(
            sevenDayPassExpiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now),
            hasLifetimePass: false,
            lastTransactionCheckAt: nil
        )
        let policy = WatermarkAccessPolicy(
            entitlementState: state,
            freeExportStore: freeExportStore,
            now: now,
            debugOverride: .none
        )

        XCTAssertTrue(policy.snapshot.hasUnlimitedAccess)
        XCTAssertTrue(policy.consumeIfNeeded(for: .withoutWatermark))
        XCTAssertEqual(freeExportStore.remainingExports(on: now), 1)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.myfs716.Memories.tests.\(UUID().uuidString)"
        suiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
