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
        let expectedExpiry = PurchaseEntitlementRules.sevenDayPassExpiry(from: purchaseDate)

        XCTAssertTrue(
            appState.applyPurchasedProduct(
                id: PurchaseProductID.sevenDayPass.rawValue,
                purchaseDate: purchaseDate
            )
        )

        let actualExpiry = try XCTUnwrap(appState.entitlementState.sevenDayPassExpiresAt)
        XCTAssertEqual(actualExpiry.timeIntervalSince1970, expectedExpiry.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertTrue(appState.entitlementState.grantsUnlimitedWatermarkFreeOutput(on: actualExpiry.addingTimeInterval(-0.001)))
        XCTAssertFalse(appState.entitlementState.grantsUnlimitedWatermarkFreeOutput(on: actualExpiry))
        XCTAssertFalse(appState.entitlementState.grantsUnlimitedWatermarkFreeOutput(on: actualExpiry.addingTimeInterval(0.001)))
    }

    func testSevenDayPassExpiryUsesExactSecondsDuration() throws {
        let purchaseDate = Date(timeIntervalSince1970: 1_800_000_000.25)
        let expiry = PurchaseEntitlementRules.sevenDayPassExpiry(from: purchaseDate)

        XCTAssertEqual(
            expiry.timeIntervalSince(purchaseDate),
            PurchaseEntitlementRules.sevenDayPassDuration,
            accuracy: 0.001
        )
    }

    func testApplyingOlderSevenDayPassDoesNotShortenExistingExpiry() throws {
        let appState = MemoriesAppState(defaults: makeDefaults())
        let newerPurchaseDate = Date(timeIntervalSince1970: 1_800_000_000)
        let olderPurchaseDate = newerPurchaseDate.addingTimeInterval(-2 * 24 * 60 * 60)

        XCTAssertTrue(
            appState.applyPurchasedProduct(
                id: PurchaseProductID.sevenDayPass.rawValue,
                purchaseDate: newerPurchaseDate
            )
        )
        let originalExpiry = try XCTUnwrap(appState.entitlementState.sevenDayPassExpiresAt)

        XCTAssertTrue(
            appState.applyPurchasedProduct(
                id: PurchaseProductID.sevenDayPass.rawValue,
                purchaseDate: olderPurchaseDate
            )
        )
        let actualExpiry = try XCTUnwrap(appState.entitlementState.sevenDayPassExpiresAt)

        XCTAssertEqual(actualExpiry.timeIntervalSince1970, originalExpiry.timeIntervalSince1970, accuracy: 0.001)
    }

    func testApplyingNewerSevenDayPassExtendsExistingExpiry() throws {
        let appState = MemoriesAppState(defaults: makeDefaults())
        let olderPurchaseDate = Date(timeIntervalSince1970: 1_800_000_000)
        let newerPurchaseDate = olderPurchaseDate.addingTimeInterval(3 * 24 * 60 * 60)

        XCTAssertTrue(
            appState.applyPurchasedProduct(
                id: PurchaseProductID.sevenDayPass.rawValue,
                purchaseDate: olderPurchaseDate
            )
        )
        XCTAssertTrue(
            appState.applyPurchasedProduct(
                id: PurchaseProductID.sevenDayPass.rawValue,
                purchaseDate: newerPurchaseDate
            )
        )

        let actualExpiry = try XCTUnwrap(appState.entitlementState.sevenDayPassExpiresAt)
        let expectedExpiry = PurchaseEntitlementRules.sevenDayPassExpiry(from: newerPurchaseDate)
        XCTAssertEqual(actualExpiry.timeIntervalSince1970, expectedExpiry.timeIntervalSince1970, accuracy: 0.001)
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

    func testEntitlementFreshnessRequiresRefreshWhenMissingOldOrFresh() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let oldCheck = now.addingTimeInterval(-(EntitlementFreshnessPolicy.maxTrustedAge + 1))
        let freshCheck = now.addingTimeInterval(-60)

        XCTAssertTrue(EntitlementState.free.needsTransactionCheck(now: now))
        XCTAssertTrue(EntitlementState(
            sevenDayPassExpiresAt: nil,
            hasLifetimePass: true,
            lastTransactionCheckAt: oldCheck
        ).needsTransactionCheck(now: now))
        XCTAssertFalse(EntitlementState(
            sevenDayPassExpiresAt: nil,
            hasLifetimePass: true,
            lastTransactionCheckAt: freshCheck
        ).needsTransactionCheck(now: now))
    }

    func testStoredLocalEntitlementIsNotTrustedUntilFreshlyChecked() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let staleSevenDayPass = EntitlementState(
            sevenDayPassExpiresAt: now.addingTimeInterval(3_600),
            hasLifetimePass: false,
            lastTransactionCheckAt: nil
        )
        let staleLifetimePass = EntitlementState(
            sevenDayPassExpiresAt: nil,
            hasLifetimePass: true,
            lastTransactionCheckAt: now.addingTimeInterval(-(EntitlementFreshnessPolicy.maxTrustedAge + 1))
        )

        XCTAssertTrue(staleSevenDayPass.grantsUnlimitedWatermarkFreeOutput(on: now))
        XCTAssertFalse(staleSevenDayPass.grantsFreshUnlimitedWatermarkFreeOutput(on: now))
        XCTAssertFalse(WatermarkAccessPolicy(entitlementState: staleSevenDayPass, now: now, debugOverride: .none).snapshot.hasUnlimitedAccess)
        XCTAssertFalse(WatermarkAccessPolicy(entitlementState: staleLifetimePass, now: now, debugOverride: .none).snapshot.hasUnlimitedAccess)
    }

    func testFreshSevenDayAndLifetimePassesAreTrustedForWatermarkFreeOutput() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let freshCheck = now.addingTimeInterval(-60)
        let sevenDayPass = EntitlementState(
            sevenDayPassExpiresAt: now.addingTimeInterval(3_600),
            hasLifetimePass: false,
            lastTransactionCheckAt: freshCheck
        )
        let lifetimePass = EntitlementState(
            sevenDayPassExpiresAt: nil,
            hasLifetimePass: true,
            lastTransactionCheckAt: freshCheck
        )

        XCTAssertTrue(WatermarkAccessPolicy(entitlementState: sevenDayPass, now: now, debugOverride: .none).snapshot.hasUnlimitedAccess)
        XCTAssertTrue(WatermarkAccessPolicy(entitlementState: lifetimePass, now: now, debugOverride: .none).snapshot.hasUnlimitedAccess)
    }

    func testRevalidationClearsStoredLocalEntitlementWhenNoTransactionsRemain() {
        let appState = MemoriesAppState(defaults: makeDefaults())
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertTrue(appState.applyPurchasedProduct(
            id: PurchaseProductID.lifetimePass.rawValue,
            purchaseDate: now,
            checkedAt: now
        ))
        XCTAssertTrue(appState.watermarkPolicy(now: now).snapshot.hasUnlimitedAccess)

        appState.replaceEntitlementState(
            sevenDayPassExpiresAt: nil,
            hasLifetimePass: false,
            checkedAt: now.addingTimeInterval(30)
        )

        XCTAssertFalse(appState.watermarkPolicy(now: now.addingTimeInterval(30)).snapshot.hasUnlimitedAccess)
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

    func testReplaceEntitlementStateUsesPassedStateExactly() throws {
        let appState = MemoriesAppState(defaults: makeDefaults())
        let purchaseDate = Date(timeIntervalSince1970: 1_800_000_000)
        let longerPurchaseDate = purchaseDate.addingTimeInterval(3 * 24 * 60 * 60)
        let checkedAt = purchaseDate.addingTimeInterval(120)
        let replacementExpiry = PurchaseEntitlementRules.sevenDayPassExpiry(from: purchaseDate)

        XCTAssertTrue(
            appState.applyPurchasedProduct(
                id: PurchaseProductID.sevenDayPass.rawValue,
                purchaseDate: longerPurchaseDate
            )
        )

        appState.replaceEntitlementState(
            sevenDayPassExpiresAt: replacementExpiry,
            hasLifetimePass: false,
            checkedAt: checkedAt
        )

        let actualExpiry = try XCTUnwrap(appState.entitlementState.sevenDayPassExpiresAt)
        XCTAssertEqual(actualExpiry.timeIntervalSince1970, replacementExpiry.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertFalse(appState.entitlementState.hasLifetimePass)
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
            sevenDayPassExpiresAt: PurchaseEntitlementRules.sevenDayPassExpiry(from: now),
            hasLifetimePass: false,
            lastTransactionCheckAt: now
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
