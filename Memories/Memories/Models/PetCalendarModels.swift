import CoreGraphics
import Foundation

enum PetCalendarConstants {
    static let appGroupIdentifier = "group.com.myfs716.Memories"
    static let displayImageMaxLongSide: CGFloat = 1600
    static let displayImageJPEGQuality: CGFloat = 0.82
    static let thumbnailMaxLongSide: CGFloat = 400
    static let thumbnailJPEGQuality: CGFloat = 0.76
}

enum PetCalendarGridMetrics {
    static let defaultCellAspectRatio: CGFloat = 0.78

    static func cellAspectRatio(forRowCount rowCount: Int) -> CGFloat {
        if rowCount <= 4 {
            return 0.60
        }
        if rowCount == 5 {
            return 0.68
        }
        return defaultCellAspectRatio
    }
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

enum PetCalendarOverlayCorner: String, Codable, CaseIterable, Identifiable, Hashable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    func displayName(language: ResolvedAppLanguage) -> String {
        switch (self, language) {
        case (.topLeft, .japanese):
            return "左上"
        case (.topRight, .japanese):
            return "右上"
        case (.bottomLeft, .japanese):
            return "左下"
        case (.bottomRight, .japanese):
            return "右下"
        case (.topLeft, .english):
            return "Top Left"
        case (.topRight, .english):
            return "Top Right"
        case (.bottomLeft, .english):
            return "Bottom Left"
        case (.bottomRight, .english):
            return "Bottom Right"
        }
    }
}

enum PetCalendarThemeIcon: String, Codable, CaseIterable, Identifiable, Hashable {
    case walk
    case outing
    case meal
    case nap
    case hospital
    case shampoo
    case cafe
    case home
    case birthday

    var id: String { rawValue }

    func displayName(language: ResolvedAppLanguage) -> String {
        switch (self, language) {
        case (.walk, .japanese):
            return "散歩"
        case (.outing, .japanese):
            return "お出かけ"
        case (.meal, .japanese):
            return "ごはん"
        case (.nap, .japanese):
            return "お昼寝"
        case (.hospital, .japanese):
            return "病院"
        case (.shampoo, .japanese):
            return "シャンプー"
        case (.cafe, .japanese):
            return "カフェ"
        case (.home, .japanese):
            return "おうち"
        case (.birthday, .japanese):
            return "誕生日"
        case (.walk, .english):
            return "Walk"
        case (.outing, .english):
            return "Outing"
        case (.meal, .english):
            return "Meal"
        case (.nap, .english):
            return "Nap"
        case (.hospital, .english):
            return "Vet"
        case (.shampoo, .english):
            return "Bath"
        case (.cafe, .english):
            return "Cafe"
        case (.home, .english):
            return "Home"
        case (.birthday, .english):
            return "Birthday"
        }
    }

    var symbolName: String {
        switch self {
        case .walk:
            return "figure.walk"
        case .outing:
            return "suitcase"
        case .meal:
            return "fork.knife"
        case .nap:
            return "moon.zzz"
        case .hospital:
            return "cross.case"
        case .shampoo:
            return "sparkles"
        case .cafe:
            return "cup.and.saucer"
        case .home:
            return "house"
        case .birthday:
            return "birthday.cake"
        }
    }

    var assetName: String {
        switch self {
        case .walk:
            return "theme_walk"
        case .outing:
            return "theme_travel"
        case .meal:
            return "theme_food"
        case .nap:
            return "theme_nap_dog"
        case .hospital:
            return "theme_hospital"
        case .shampoo:
            return "theme_bath"
        case .cafe:
            return "theme_cafe"
        case .home:
            return "theme_home"
        case .birthday:
            return "theme_birthday"
        }
    }
}

enum PetCalendarWeatherIcon: String, Codable, CaseIterable, Identifiable, Hashable {
    case sunny
    case cloudy
    case rainy
    case snowy

    var id: String { rawValue }

    func displayName(language: ResolvedAppLanguage) -> String {
        switch (self, language) {
        case (.sunny, .japanese):
            return "晴れ"
        case (.cloudy, .japanese):
            return "くもり"
        case (.rainy, .japanese):
            return "雨"
        case (.snowy, .japanese):
            return "雪"
        case (.sunny, .english):
            return "Sunny"
        case (.cloudy, .english):
            return "Cloudy"
        case (.rainy, .english):
            return "Rain"
        case (.snowy, .english):
            return "Snow"
        }
    }

    var symbolName: String {
        switch self {
        case .sunny:
            return "sun.max"
        case .cloudy:
            return "cloud"
        case .rainy:
            return "cloud.rain"
        case .snowy:
            return "snowflake"
        }
    }

    var assetName: String {
        switch self {
        case .sunny:
            return "weather_sunny"
        case .cloudy:
            return "weather_cloudy"
        case .rainy:
            return "weather_rain"
        case .snowy:
            return "weather_snow"
        }
    }
}

enum PetCalendarOverlayColorStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case white
    case black
    case navy
    case blue
    case softGray

    var id: String { rawValue }

    var hex: String {
        switch self {
        case .white:
            return "#FFFFFF"
        case .black:
            return "#1F1F1F"
        case .navy:
            return "#20364F"
        case .blue:
            return "#4F7FA3"
        case .softGray:
            return "#DCE4EA"
        }
    }

    func displayName(language: ResolvedAppLanguage) -> String {
        switch (self, language) {
        case (.white, .japanese):
            return "白"
        case (.black, .japanese):
            return "黒"
        case (.navy, .japanese):
            return "ネイビー"
        case (.blue, .japanese):
            return "ブルー"
        case (.softGray, .japanese):
            return "ソフトグレー"
        case (.white, .english):
            return "White"
        case (.black, .english):
            return "Black"
        case (.navy, .english):
            return "Navy"
        case (.blue, .english):
            return "Blue"
        case (.softGray, .english):
            return "Soft Gray"
        }
    }
}

enum PetCalendarOverlayFontStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case rounded
    case regular
    case bold

    var id: String { rawValue }

    func displayName(language: ResolvedAppLanguage) -> String {
        switch (self, language) {
        case (.rounded, .japanese):
            return "丸ゴシック"
        case (.regular, .japanese):
            return "標準"
        case (.bold, .japanese):
            return "太字"
        case (.rounded, .english):
            return "Rounded"
        case (.regular, .english):
            return "Regular"
        case (.bold, .english):
            return "Bold"
        }
    }
}

struct PetCalendarOverlayStyle: Codable, Hashable {
    var isThemeIconVisible: Bool
    var themeIcon: PetCalendarThemeIcon?
    var themeIconCorner: PetCalendarOverlayCorner
    var isWeatherIconVisible: Bool
    var weatherIcon: PetCalendarWeatherIcon?
    var weatherIconCorner: PetCalendarOverlayCorner
    var textColor: PetCalendarOverlayColorStyle
    var accentColor: PetCalendarOverlayColorStyle
    var fontStyle: PetCalendarOverlayFontStyle

    static let `default` = PetCalendarOverlayStyle(
        isThemeIconVisible: false,
        themeIcon: nil,
        themeIconCorner: .topRight,
        isWeatherIconVisible: false,
        weatherIcon: nil,
        weatherIconCorner: .bottomRight,
        textColor: .white,
        accentColor: .white,
        fontStyle: .rounded
    )

    private enum CodingKeys: String, CodingKey {
        case isThemeIconVisible
        case themeIcon
        case themeIconCorner
        case isWeatherIconVisible
        case weatherIcon
        case weatherIconCorner
        case textColor
        case accentColor
        case fontStyle
    }

    init(
        isThemeIconVisible: Bool,
        themeIcon: PetCalendarThemeIcon?,
        themeIconCorner: PetCalendarOverlayCorner,
        isWeatherIconVisible: Bool,
        weatherIcon: PetCalendarWeatherIcon?,
        weatherIconCorner: PetCalendarOverlayCorner,
        textColor: PetCalendarOverlayColorStyle,
        accentColor: PetCalendarOverlayColorStyle,
        fontStyle: PetCalendarOverlayFontStyle
    ) {
        self.isThemeIconVisible = isThemeIconVisible
        self.themeIcon = themeIcon
        self.themeIconCorner = themeIconCorner
        self.isWeatherIconVisible = isWeatherIconVisible
        self.weatherIcon = weatherIcon
        self.weatherIconCorner = weatherIconCorner
        self.textColor = textColor
        self.accentColor = accentColor
        self.fontStyle = fontStyle
    }

    init(from decoder: Decoder) throws {
        let fallback = Self.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isThemeIconVisible = (try? container.decodeIfPresent(Bool.self, forKey: .isThemeIconVisible)) ?? fallback.isThemeIconVisible
        themeIcon = (try? container.decodeIfPresent(PetCalendarThemeIcon.self, forKey: .themeIcon)) ?? fallback.themeIcon
        themeIconCorner = (try? container.decodeIfPresent(PetCalendarOverlayCorner.self, forKey: .themeIconCorner)) ?? fallback.themeIconCorner
        isWeatherIconVisible = (try? container.decodeIfPresent(Bool.self, forKey: .isWeatherIconVisible)) ?? fallback.isWeatherIconVisible
        weatherIcon = (try? container.decodeIfPresent(PetCalendarWeatherIcon.self, forKey: .weatherIcon)) ?? fallback.weatherIcon
        weatherIconCorner = (try? container.decodeIfPresent(PetCalendarOverlayCorner.self, forKey: .weatherIconCorner)) ?? fallback.weatherIconCorner
        textColor = (try? container.decodeIfPresent(PetCalendarOverlayColorStyle.self, forKey: .textColor)) ?? fallback.textColor
        accentColor = (try? container.decodeIfPresent(PetCalendarOverlayColorStyle.self, forKey: .accentColor)) ?? fallback.accentColor
        fontStyle = (try? container.decodeIfPresent(PetCalendarOverlayFontStyle.self, forKey: .fontStyle)) ?? fallback.fontStyle
    }

    var effectiveThemeIcon: PetCalendarThemeIcon? {
        isThemeIconVisible ? (themeIcon ?? .walk) : nil
    }

    var effectiveWeatherIcon: PetCalendarWeatherIcon? {
        isWeatherIconVisible ? (weatherIcon ?? .sunny) : nil
    }

    mutating func selectWeatherIcon(_ icon: PetCalendarWeatherIcon) {
        isWeatherIconVisible = true
        weatherIcon = icon
    }
}

struct PetCalendarDayEntry: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var imageFileName: String?
    var thumbnailFileName: String?
    var caption: String
    var photoPlacement: PhotoPlacement
    var overlayStyle: PetCalendarOverlayStyle
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        date: Date,
        imageFileName: String?,
        thumbnailFileName: String?,
        caption: String = "",
        photoPlacement: PhotoPlacement = .default,
        overlayStyle: PetCalendarOverlayStyle = .default,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.date = date
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.caption = caption
        self.photoPlacement = photoPlacement.clamped
        self.overlayStyle = overlayStyle
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
        case overlayStyle
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        thumbnailFileName = try container.decodeIfPresent(String.self, forKey: .thumbnailFileName)
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        photoPlacement = (try container.decodeIfPresent(PhotoPlacement.self, forKey: .photoPlacement) ?? .default).clamped
        overlayStyle = try container.decodeIfPresent(PetCalendarOverlayStyle.self, forKey: .overlayStyle) ?? .default
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
        let monthInterval = calendar.dateInterval(of: .month, for: monthStart)
        let lastMonthDate = monthInterval
            .flatMap { calendar.date(byAdding: .day, value: -1, to: $0.end) }
            ?? monthStart
        let trailingDays = (calendar.firstWeekday + 6 - calendar.component(.weekday, from: lastMonthDate) + 7) % 7
        let gridEnd = calendar.date(byAdding: .day, value: trailingDays + 1, to: lastMonthDate) ?? lastMonthDate
        let dayCount = max(28, calendar.dateComponents([.day], from: gridStart, to: gridEnd).day ?? 42)
        let displayedMonth = calendar.component(.month, from: monthStart)
        let displayedYear = calendar.component(.year, from: monthStart)
        let todayID = id(for: now, calendar: calendar)

        return (0..<dayCount).compactMap { offset in
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
