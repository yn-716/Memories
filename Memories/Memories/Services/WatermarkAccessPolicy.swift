import Foundation

enum WatermarkExportOption: String, CaseIterable, Identifiable, Hashable {
    case withWatermark
    case withoutWatermark

    var id: String {
        rawValue
    }

    var watermarkMode: WatermarkMode {
        switch self {
        case .withWatermark:
            return .visible
        case .withoutWatermark:
            return .hidden
        }
    }
}

struct EntitlementState: Codable, Hashable {
    var sevenDayPassExpiresAt: Date?
    var hasLifetimePass: Bool
    var lastTransactionCheckAt: Date?

    static let free = EntitlementState(
        sevenDayPassExpiresAt: nil,
        hasLifetimePass: false,
        lastTransactionCheckAt: nil
    )

    func grantsUnlimitedWatermarkFreeOutput(on date: Date = Date()) -> Bool {
        if hasLifetimePass {
            return true
        }

        if let sevenDayPassExpiresAt, sevenDayPassExpiresAt > date {
            return true
        }

        return false
    }

    func isSevenDayPassActive(on date: Date = Date()) -> Bool {
        guard let sevenDayPassExpiresAt else {
            return false
        }

        return sevenDayPassExpiresAt > date
    }
}

struct WatermarkAccessSnapshot: Hashable {
    let canExportWithoutWatermark: Bool
    let remainingFreeExportsToday: Int
    let hasUnlimitedAccess: Bool
}

struct DailyWatermarkFreeExportStore {
    static let shared = DailyWatermarkFreeExportStore()

    private let dailyLimit = 1
    private let defaults: UserDefaults
    private let dayKey = "memories.watermarkFreeExport.day"
    private let countKey = "memories.watermarkFreeExport.count"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func remainingExports(on date: Date = Date(), calendar: Calendar = .current) -> Int {
        max(0, dailyLimit - usedCount(on: date, calendar: calendar))
    }

    func consumeExport(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let usedCount = usedCount(on: date, calendar: calendar)
        guard usedCount < dailyLimit else {
            return false
        }

        defaults.set(dayIdentifier(for: date, calendar: calendar), forKey: dayKey)
        defaults.set(usedCount + 1, forKey: countKey)
        return true
    }

    #if DEBUG
    func resetTodayUsage() {
        defaults.removeObject(forKey: dayKey)
        defaults.removeObject(forKey: countKey)
    }
    #endif

    private func usedCount(on date: Date, calendar: Calendar) -> Int {
        let today = dayIdentifier(for: date, calendar: calendar)
        guard defaults.string(forKey: dayKey) == today else {
            return 0
        }

        return defaults.integer(forKey: countKey)
    }

    private func dayIdentifier(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

struct WatermarkAccessPolicy {
    var entitlementState: EntitlementState
    var freeExportStore: DailyWatermarkFreeExportStore
    var now: Date
    #if DEBUG
    var debugOverride: DebugEntitlementOverride
    #endif

    #if DEBUG
    init(
        entitlementState: EntitlementState,
        freeExportStore: DailyWatermarkFreeExportStore = .shared,
        now: Date = Date(),
        debugOverride: DebugEntitlementOverride = .none
    ) {
        self.entitlementState = entitlementState
        self.freeExportStore = freeExportStore
        self.now = now
        self.debugOverride = debugOverride
    }
    #else
    init(
        entitlementState: EntitlementState,
        freeExportStore: DailyWatermarkFreeExportStore = .shared,
        now: Date = Date()
    ) {
        self.entitlementState = entitlementState
        self.freeExportStore = freeExportStore
        self.now = now
    }
    #endif

    var snapshot: WatermarkAccessSnapshot {
        #if DEBUG
        switch debugOverride {
        case .none, .sevenDayExpired:
            break
        case .free:
            return WatermarkAccessSnapshot(
                canExportWithoutWatermark: true,
                remainingFreeExportsToday: 1,
                hasUnlimitedAccess: false
            )
        case .freeUsedToday:
            return WatermarkAccessSnapshot(
                canExportWithoutWatermark: false,
                remainingFreeExportsToday: 0,
                hasUnlimitedAccess: false
            )
        case .sevenDayActive, .lifetime:
            return WatermarkAccessSnapshot(
                canExportWithoutWatermark: true,
                remainingFreeExportsToday: 0,
                hasUnlimitedAccess: true
            )
        }
        #endif

        let hasUnlimitedAccess = entitlementState.grantsUnlimitedWatermarkFreeOutput(on: now)
        let remaining = hasUnlimitedAccess ? Int.max : freeExportStore.remainingExports(on: now)

        return WatermarkAccessSnapshot(
            canExportWithoutWatermark: hasUnlimitedAccess || remaining > 0,
            remainingFreeExportsToday: hasUnlimitedAccess ? 0 : remaining,
            hasUnlimitedAccess: hasUnlimitedAccess
        )
    }

    func canExport(option: WatermarkExportOption) -> Bool {
        switch option {
        case .withWatermark:
            return true
        case .withoutWatermark:
            return snapshot.canExportWithoutWatermark
        }
    }

    func consumeIfNeeded(for option: WatermarkExportOption) -> Bool {
        guard option == .withoutWatermark else {
            return true
        }

        #if DEBUG
        switch debugOverride {
        case .none, .sevenDayExpired:
            break
        case .free:
            return true
        case .freeUsedToday:
            return false
        case .sevenDayActive, .lifetime:
            return true
        }
        #endif

        if entitlementState.grantsUnlimitedWatermarkFreeOutput(on: now) {
            return true
        }

        return freeExportStore.consumeExport(on: now)
    }
}
