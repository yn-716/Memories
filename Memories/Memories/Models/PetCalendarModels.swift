import CoreGraphics
import Foundation

enum PetCalendarConstants {
    static let appGroupIdentifier = "group.com.myfs716.Memories"
    static let displayImageMaxLongSide: CGFloat = 1600
    static let displayImageJPEGQuality: CGFloat = 0.82
    static let thumbnailMaxLongSide: CGFloat = 400
    static let thumbnailJPEGQuality: CGFloat = 0.76
}

enum PetCalendarDisplayLanguage: String, Codable, CaseIterable, Identifiable, Hashable {
    case japanese
    case english

    var id: String { rawValue }

    var resolvedAppLanguage: ResolvedAppLanguage {
        switch self {
        case .japanese:
            return .japanese
        case .english:
            return .english
        }
    }

    func displayName(in language: ResolvedAppLanguage) -> String {
        switch self {
        case .japanese:
            return language == .japanese ? "日本語" : "Japanese"
        case .english:
            return "English"
        }
    }
}

enum PetCalendarWeekStart: String, Codable, Hashable {
    case sunday
}

struct PetCalendarSettings: Codable, Hashable {
    var displayLanguage: PetCalendarDisplayLanguage
    var selectedMonth: Date
}

struct PetCalendarDayEntry: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var imageFileName: String
    var thumbnailFileName: String
    var caption: String
    var photoPlacement: PhotoPlacement
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        date: Date,
        imageFileName: String,
        thumbnailFileName: String,
        caption: String = "",
        photoPlacement: PhotoPlacement = .default,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.date = date
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.caption = caption
        self.photoPlacement = photoPlacement.clamped
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case imageFileName
        case thumbnailFileName
        case caption
        case photoPlacement
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        imageFileName = try container.decode(String.self, forKey: .imageFileName)
        thumbnailFileName = try container.decode(String.self, forKey: .thumbnailFileName)
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        photoPlacement = (try container.decodeIfPresent(PhotoPlacement.self, forKey: .photoPlacement) ?? .default).clamped
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

struct PetCalendarMonthCell: Identifiable, Hashable {
    var id: String
    var date: Date
    var dayNumber: Int
    var isInDisplayedMonth: Bool
    var isToday: Bool
    var isFuture: Bool
}

struct PetCalendarMonthSummary: Hashable {
    var registeredCount: Int
    var currentStreak: Int
}

enum PetCalendarDateRules {
    static func gregorianCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 1
        return calendar
    }

    static func startOfDay(for date: Date, calendar: Calendar = gregorianCalendar()) -> Date {
        calendar.startOfDay(for: date)
    }

    static func id(for date: Date, calendar: Calendar = gregorianCalendar()) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func canRegisterPhoto(for date: Date, now: Date = Date(), calendar: Calendar = gregorianCalendar()) -> Bool {
        startOfDay(for: date, calendar: calendar) <= startOfDay(for: now, calendar: calendar)
    }

    static func monthStart(for date: Date, calendar: Calendar = gregorianCalendar()) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    static func monthGrid(
        for month: Date,
        now: Date = Date(),
        calendar: Calendar = gregorianCalendar()
    ) -> [PetCalendarMonthCell] {
        let monthStart = monthStart(for: month, calendar: calendar)
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart
        let displayedMonth = calendar.component(.month, from: monthStart)
        let displayedYear = calendar.component(.year, from: monthStart)
        let todayID = id(for: now, calendar: calendar)

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }

            let components = calendar.dateComponents([.year, .month, .day], from: date)
            let dateID = id(for: date, calendar: calendar)
            return PetCalendarMonthCell(
                id: dateID,
                date: date,
                dayNumber: components.day ?? 0,
                isInDisplayedMonth: components.year == displayedYear && components.month == displayedMonth,
                isToday: dateID == todayID,
                isFuture: !canRegisterPhoto(for: date, now: now, calendar: calendar)
            )
        }
    }

    static func monthTitle(for month: Date, language: PetCalendarDisplayLanguage, calendar: Calendar = gregorianCalendar()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        switch language {
        case .japanese:
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "yyyy年M月"
        case .english:
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "MMMM yyyy"
        }
        return formatter.string(from: monthStart(for: month, calendar: calendar))
    }

    static func shortDateTitle(for date: Date, language: PetCalendarDisplayLanguage, calendar: Calendar = gregorianCalendar()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        switch language {
        case .japanese:
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "M月d日"
        case .english:
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }

    static func weekdaySymbols(language: PetCalendarDisplayLanguage) -> [String] {
        switch language {
        case .japanese:
            return ["日", "月", "火", "水", "木", "金", "土"]
        case .english:
            return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        }
    }

    static func summary(entries: [PetCalendarDayEntry], month: Date, now: Date = Date(), calendar: Calendar = gregorianCalendar()) -> PetCalendarMonthSummary {
        let monthStart = monthStart(for: month, calendar: calendar)
        let monthInterval = calendar.dateInterval(of: .month, for: monthStart)
        let registeredCount = entries.filter { entry in
            guard let monthInterval else {
                return false
            }
            return monthInterval.contains(entry.date)
        }.count
        let entryIDs = Set(entries.map { id(for: $0.date, calendar: calendar) })
        var streak = 0
        var cursor = startOfDay(for: now, calendar: calendar)
        while entryIDs.contains(id(for: cursor, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return PetCalendarMonthSummary(registeredCount: registeredCount, currentStreak: streak)
    }

    static func week(
        containing date: Date,
        now: Date = Date(),
        registeredEntryIDs: Set<String>,
        calendar: Calendar = gregorianCalendar()
    ) -> [PetCalendarWeekDay] {
        let start = startOfWeek(containing: date, calendar: calendar)
        let todayID = id(for: now, calendar: calendar)
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            let dayID = id(for: day, calendar: calendar)
            return PetCalendarWeekDay(
                id: dayID,
                date: day,
                dayNumber: calendar.component(.day, from: day),
                isToday: dayID == todayID,
                isFuture: !canRegisterPhoto(for: day, now: now, calendar: calendar),
                isRegistered: registeredEntryIDs.contains(dayID)
            )
        }
    }

    static func startOfWeek(containing date: Date, calendar: Calendar = gregorianCalendar()) -> Date {
        let start = startOfDay(for: date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: start)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -leadingDays, to: start) ?? start
    }
}

struct PetCalendarWeekDay: Identifiable, Hashable {
    var id: String
    var date: Date
    var dayNumber: Int
    var isToday: Bool
    var isFuture: Bool
    var isRegistered: Bool
}
