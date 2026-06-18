import Foundation
import Combine

#if DEBUG
enum DebugEntitlementOverride: String, CaseIterable, Identifiable {
    case none
    case free
    case freeUsedToday
    case sevenDayActive
    case sevenDayExpired
    case lifetime

    var id: String { rawValue }

    func displayName(language: ResolvedAppLanguage) -> String {
        switch self {
        case .none:
            return MemoriesLocalization.text("debug.real", language: language)
        case .free:
            return MemoriesLocalization.text("debug.free", language: language)
        case .freeUsedToday:
            return MemoriesLocalization.text("debug.freeUsedToday", language: language)
        case .sevenDayActive:
            return MemoriesLocalization.text("debug.sevenDayActive", language: language)
        case .sevenDayExpired:
            return MemoriesLocalization.text("debug.sevenDayExpired", language: language)
        case .lifetime:
            return MemoriesLocalization.text("debug.lifetime", language: language)
        }
    }
}

enum DebugDraftLimitOverride: String, CaseIterable, Identifiable {
    case none
    case one
    case two
    case five
    case ten
    case hundred

    var id: String { rawValue }

    var limit: Int? {
        switch self {
        case .none:
            return nil
        case .one:
            return 1
        case .two:
            return 2
        case .five:
            return 5
        case .ten:
            return 10
        case .hundred:
            return DraftRepository.draftLimit
        }
    }

    func displayName(language: ResolvedAppLanguage) -> String {
        switch self {
        case .none:
            return MemoriesLocalization.text("debug.draftLimit.real", language: language)
        case .one:
            return MemoriesLocalization.text("debug.draftLimit.one", language: language)
        case .two:
            return MemoriesLocalization.text("debug.draftLimit.two", language: language)
        case .five:
            return MemoriesLocalization.text("debug.draftLimit.five", language: language)
        case .ten:
            return MemoriesLocalization.text("debug.draftLimit.ten", language: language)
        case .hundred:
            return MemoriesLocalization.text("debug.draftLimit.hundred", language: language)
        }
    }
}
#endif

enum PurchaseProductID: String, CaseIterable {
    case sevenDayPass = "memories.7day.pass"
    case lifetimePass = "memories.lifetime.pass"

    static var allStoreProductIDs: [String] {
        allCases.map(\.rawValue)
    }

    static func matching(productID: String) -> PurchaseProductID? {
        allCases.first { $0.rawValue == productID }
    }
}

@MainActor
final class MemoriesAppState: ObservableObject {
    @Published var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
        }
    }

    @Published private(set) var entitlementState: EntitlementState {
        didSet {
            persistEntitlementState()
        }
    }

    @Published var entitlementRefreshID = UUID()

    #if DEBUG
    @Published var debugEntitlementOverride: DebugEntitlementOverride {
        didSet {
            defaults.set(debugEntitlementOverride.rawValue, forKey: Keys.debugEntitlementOverride)
            entitlementRefreshID = UUID()
        }
    }

    @Published var debugDraftLimitOverride: DebugDraftLimitOverride {
        didSet {
            defaults.set(debugDraftLimitOverride.rawValue, forKey: Keys.debugDraftLimitOverride)
        }
    }
    #endif

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appLanguage = AppLanguage(rawValue: defaults.string(forKey: Keys.appLanguage) ?? "") ?? .system
        self.entitlementState = Self.loadEntitlementState(from: defaults)

        #if DEBUG
        self.debugEntitlementOverride = DebugEntitlementOverride(
            rawValue: defaults.string(forKey: Keys.debugEntitlementOverride) ?? ""
        ) ?? .none
        self.debugDraftLimitOverride = DebugDraftLimitOverride(
            rawValue: defaults.string(forKey: Keys.debugDraftLimitOverride) ?? ""
        ) ?? .none
        #endif
    }

    var resolvedLanguage: ResolvedAppLanguage {
        appLanguage.resolvedLanguage
    }

    var localeIdentifier: String {
        resolvedLanguage.localeIdentifier
    }

    var effectiveEntitlementState: EntitlementState {
        #if DEBUG
        switch debugEntitlementOverride {
        case .none, .free, .freeUsedToday, .sevenDayExpired:
            return debugEntitlementOverride == .none ? entitlementState : .free
        case .sevenDayActive:
            return EntitlementState(
                sevenDayPassExpiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                hasLifetimePass: false,
                lastTransactionCheckAt: entitlementState.lastTransactionCheckAt
            )
        case .lifetime:
            return EntitlementState(
                sevenDayPassExpiresAt: nil,
                hasLifetimePass: true,
                lastTransactionCheckAt: entitlementState.lastTransactionCheckAt
            )
        }
        #else
        return entitlementState
        #endif
    }

    var draftLimit: Int {
        #if DEBUG
        return debugDraftLimitOverride.limit ?? DraftRepository.draftLimit
        #else
        return DraftRepository.draftLimit
        #endif
    }

    func t(_ key: String) -> String {
        MemoriesLocalization.text(key, language: resolvedLanguage)
    }

    func watermarkPolicy(now: Date = Date()) -> WatermarkAccessPolicy {
        #if DEBUG
        WatermarkAccessPolicy(
            entitlementState: effectiveEntitlementState,
            now: now,
            debugOverride: debugEntitlementOverride
        )
        #else
        WatermarkAccessPolicy(entitlementState: effectiveEntitlementState, now: now)
        #endif
    }

    func grantSevenDayPass(from date: Date = Date()) {
        entitlementState = EntitlementState(
            sevenDayPassExpiresAt: Calendar.current.date(byAdding: .day, value: 7, to: date),
            hasLifetimePass: entitlementState.hasLifetimePass,
            lastTransactionCheckAt: entitlementState.lastTransactionCheckAt
        )
        entitlementRefreshID = UUID()
    }

    func grantLifetimePass() {
        entitlementState = EntitlementState(
            sevenDayPassExpiresAt: entitlementState.sevenDayPassExpiresAt,
            hasLifetimePass: true,
            lastTransactionCheckAt: entitlementState.lastTransactionCheckAt
        )
        entitlementRefreshID = UUID()
    }

    @discardableResult
    func applyPurchasedProduct(id: String, purchaseDate: Date = Date()) -> Bool {
        switch PurchaseProductID.matching(productID: id) {
        case .sevenDayPass:
            grantSevenDayPass(from: purchaseDate)
            return true
        case .lifetimePass:
            grantLifetimePass()
            return true
        case nil:
            return false
        }
    }

    func revokePurchasedProduct(id: String) {
        switch PurchaseProductID.matching(productID: id) {
        case .sevenDayPass:
            entitlementState = EntitlementState(
                sevenDayPassExpiresAt: nil,
                hasLifetimePass: entitlementState.hasLifetimePass,
                lastTransactionCheckAt: entitlementState.lastTransactionCheckAt
            )
            entitlementRefreshID = UUID()
        case .lifetimePass:
            entitlementState = EntitlementState(
                sevenDayPassExpiresAt: entitlementState.sevenDayPassExpiresAt,
                hasLifetimePass: false,
                lastTransactionCheckAt: entitlementState.lastTransactionCheckAt
            )
            entitlementRefreshID = UUID()
        case nil:
            break
        }
    }

    func markTransactionCheck(at date: Date = Date()) {
        entitlementState = EntitlementState(
            sevenDayPassExpiresAt: entitlementState.sevenDayPassExpiresAt,
            hasLifetimePass: entitlementState.hasLifetimePass,
            lastTransactionCheckAt: date
        )
        entitlementRefreshID = UUID()
    }

    func resetDailyWatermarkFreeUseForDebug() {
        #if DEBUG
        DailyWatermarkFreeExportStore.shared.resetTodayUsage()
        entitlementRefreshID = UUID()
        #endif
    }

    func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: date)
    }

    private func persistEntitlementState() {
        if let data = try? JSONEncoder().encode(entitlementState) {
            defaults.set(data, forKey: Keys.entitlementState)
        }
    }

    private static func loadEntitlementState(from defaults: UserDefaults) -> EntitlementState {
        guard
            let data = defaults.data(forKey: Keys.entitlementState),
            let state = try? JSONDecoder().decode(EntitlementState.self, from: data)
        else {
            return .free
        }

        return state
    }

    private enum Keys {
        static let appLanguage = "memories.appLanguage"
        static let entitlementState = "memories.entitlementState"
        static let debugEntitlementOverride = "memories.debugEntitlementOverride"
        static let debugDraftLimitOverride = "memories.debugDraftLimitOverride"
    }
}
