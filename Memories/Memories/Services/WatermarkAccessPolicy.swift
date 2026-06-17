import Foundation

enum WatermarkExportOption: String, CaseIterable, Identifiable, Hashable {
    case withWatermark
    case withoutWatermark

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .withWatermark:
            return "あり"
        case .withoutWatermark:
            return "なし"
        }
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

    static let free = EntitlementState(
        sevenDayPassExpiresAt: nil,
        hasLifetimePass: false
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
}

struct WatermarkAccessSnapshot: Hashable {
    let canExportWithoutWatermark: Bool
    let remainingFreeExportsToday: Int
    let hasUnlimitedAccess: Bool

    var withoutWatermarkStatusText: String {
        if hasUnlimitedAccess {
            return "無制限"
        }

        if remainingFreeExportsToday > 0 {
            return "本日あと\(remainingFreeExportsToday)回"
        }

        return "本日分を使用済み"
    }
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

    init(
        entitlementState: EntitlementState,
        freeExportStore: DailyWatermarkFreeExportStore = .shared,
        now: Date = Date()
    ) {
        self.entitlementState = entitlementState
        self.freeExportStore = freeExportStore
        self.now = now
    }

    var snapshot: WatermarkAccessSnapshot {
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

        if entitlementState.grantsUnlimitedWatermarkFreeOutput(on: now) {
            return true
        }

        return freeExportStore.consumeExport(on: now)
    }
}
