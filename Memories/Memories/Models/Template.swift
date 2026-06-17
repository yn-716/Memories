import SwiftUI
import UIKit
import Foundation

struct Template: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let category: String
    let supportedAspectRatios: [CardAspectRatio]
    let defaultLayout: OverlayPosition
    let overlayStyle: OverlayStyle
    let textFieldDefinitions: [CardTextFieldDefinition]

    var categoryDisplayName: String {
        switch category {
        case "petLifelog":
            return "Pet Lifelog"
        default:
            return category
        }
    }

    var defaultAspectRatio: CardAspectRatio {
        supportedAspectRatios.first ?? .fourByFive
    }

    var previewEditState: CardEditState {
        CardEditState(
            selectedThemeIcon: .walk,
            selectedWeather: .sunny,
            locationText: "Park",
            dateMode: .single,
            selectedDate: CardEditState.date(year: 2026, month: 6, day: 17),
            startDate: CardEditState.date(year: 2026, month: 6, day: 17),
            endDate: CardEditState.date(year: 2026, month: 6, day: 19),
            customDateText: "",
            mainText: "My Pet",
            subText: "Happy day",
            selectedPosition: defaultLayout,
            selectedFontRole: overlayStyle.defaultFontRole,
            selectedTextColor: overlayStyle.defaultTextColor,
            visibilitySettings: .allVisible
        )
    }
}

struct OverlayStyle: Codable, Hashable {
    let name: String
    let defaultTextColor: TextColorOption
    let defaultFontRole: FontRole
    let photoPlaceholderStartColor: String
    let photoPlaceholderEndColor: String
    let addsSoftShadow: Bool

    var displayName: String {
        name
    }
}

struct CardTextFieldDefinition: Codable, Hashable, Identifiable {
    let id: String
    let role: CardTextRole
    let defaultText: String
    let editable: Bool
}

enum CardTextRole: String, Codable, CaseIterable, Hashable, Identifiable {
    case location
    case date
    case mainText
    case subText

    var id: String { rawValue }
}

enum CardDateMode: String, Codable, CaseIterable, Hashable, Identifiable {
    case single
    case range
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .single:
            return "1日"
        case .range:
            return "期間"
        case .custom:
            return "自由入力"
        }
    }
}

struct CardEditState: Hashable {
    var selectedThemeIcon: ThemeIconType
    var selectedWeather: WeatherType
    var locationText: String
    var dateMode: CardDateMode
    var selectedDate: Date
    var startDate: Date
    var endDate: Date
    var customDateText: String
    var mainText: String
    var subText: String
    var selectedPosition: OverlayPosition
    var selectedFontRole: FontRole
    var selectedTextColor: TextColorOption
    var visibilitySettings: VisibilitySettings

    var dateText: String {
        displayDateText
    }

    var displayDateText: String {
        switch dateMode {
        case .single:
            return Self.formatted(selectedDate)
        case .range:
            return "\(Self.formatted(startDate)) - \(Self.formatted(max(startDate, endDate)))"
        case .custom:
            return customDateText
        }
    }

    static func newCard(
        defaultLayout: OverlayPosition,
        fontRole: FontRole,
        textColor: TextColorOption,
        date: Date = Date()
    ) -> CardEditState {
        CardEditState(
            selectedThemeIcon: .walk,
            selectedWeather: .none,
            locationText: "",
            dateMode: .single,
            selectedDate: normalizedDate(date),
            startDate: normalizedDate(date),
            endDate: normalizedDate(date),
            customDateText: "",
            mainText: "",
            subText: "",
            selectedPosition: defaultLayout,
            selectedFontRole: fontRole,
            selectedTextColor: textColor,
            visibilitySettings: .newCardDefault
        )
    }

    static func formatted(_ date: Date) -> String {
        dateFormatter.string(from: normalizedDate(date))
    }

    static func normalizedDate(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? normalizedDate(Date())
    }

    private static let calendar = Calendar(identifier: .gregorian)

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}

struct VisibilitySettings: Codable, Hashable {
    var showThemeIcon: Bool
    var showLocation: Bool
    var showDate: Bool
    var showWeather: Bool
    var showMainText: Bool
    var showSubText: Bool

    static let allVisible = VisibilitySettings(
        showThemeIcon: true,
        showLocation: true,
        showDate: true,
        showWeather: true,
        showMainText: true,
        showSubText: true
    )

    static let newCardDefault = VisibilitySettings(
        showThemeIcon: true,
        showLocation: true,
        showDate: true,
        showWeather: false,
        showMainText: true,
        showSubText: true
    )
}

enum OverlayPosition: String, Codable, CaseIterable, Hashable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topLeft:
            return "左上"
        case .topRight:
            return "右上"
        case .bottomLeft:
            return "左下"
        case .bottomRight:
            return "右下"
        }
    }

    var alignment: Alignment {
        switch self {
        case .topLeft:
            return .topLeading
        case .topRight:
            return .topTrailing
        case .bottomLeft:
            return .bottomLeading
        case .bottomRight:
            return .bottomTrailing
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .topLeft, .bottomLeft:
            return .leading
        case .topRight, .bottomRight:
            return .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .topLeft, .bottomLeft:
            return .leading
        case .topRight, .bottomRight:
            return .trailing
        }
    }

    var isTrailing: Bool {
        self == .topRight || self == .bottomRight
    }

    var isBottom: Bool {
        self == .bottomLeft || self == .bottomRight
    }
}

enum ThemeIconType: String, Codable, CaseIterable, Hashable, Identifiable {
    case meal
    case walk
    case napDog
    case napCat
    case travel
    case hospital
    case shampoo
    case cafe
    case home
    case birthday

    var id: String { rawValue }

    var displayName: LocalizedDisplayName {
        switch self {
        case .meal:
            return LocalizedDisplayName(ja: "ごはん", en: "Meal")
        case .walk:
            return LocalizedDisplayName(ja: "散歩", en: "Walk")
        case .napDog:
            return LocalizedDisplayName(ja: "お昼寝 犬", en: "Dog Nap")
        case .napCat:
            return LocalizedDisplayName(ja: "お昼寝 猫", en: "Cat Nap")
        case .travel:
            return LocalizedDisplayName(ja: "旅行", en: "Travel")
        case .hospital:
            return LocalizedDisplayName(ja: "病院", en: "Hospital")
        case .shampoo:
            return LocalizedDisplayName(ja: "シャンプー", en: "Shampoo")
        case .cafe:
            return LocalizedDisplayName(ja: "カフェ", en: "Cafe")
        case .home:
            return LocalizedDisplayName(ja: "おうち時間", en: "Home")
        case .birthday:
            return LocalizedDisplayName(ja: "誕生日", en: "Birthday")
        }
    }

    var symbolName: String {
        switch self {
        case .meal:
            return "fork.knife"
        case .walk:
            return "figure.walk"
        case .napDog:
            return "moon.zzz"
        case .napCat:
            return "cat"
        case .travel:
            return "suitcase"
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
}

enum WeatherType: String, Codable, CaseIterable, Hashable, Identifiable {
    case none
    case sunny
    case cloudy
    case rainy
    case snowy

    var id: String { rawValue }

    var displayName: LocalizedDisplayName {
        switch self {
        case .none:
            return LocalizedDisplayName(ja: "未選択", en: "None")
        case .sunny:
            return LocalizedDisplayName(ja: "晴れ", en: "Sunny")
        case .cloudy:
            return LocalizedDisplayName(ja: "くもり", en: "Cloudy")
        case .rainy:
            return LocalizedDisplayName(ja: "雨", en: "Rainy")
        case .snowy:
            return LocalizedDisplayName(ja: "雪", en: "Snowy")
        }
    }

    var symbolName: String? {
        switch self {
        case .none:
            return nil
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
}

enum TextColorOption: String, Codable, CaseIterable, Hashable, Identifiable {
    case black
    case white
    case gray
    case beige
    case navy
    case brown
    case deepGreen
    case dustyBlue
    case paleBlue

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .black:
            return "Black"
        case .white:
            return "White"
        case .gray:
            return "Gray"
        case .beige:
            return "Beige"
        case .navy:
            return "Navy"
        case .brown:
            return "Brown"
        case .deepGreen:
            return "Deep Green"
        case .dustyBlue:
            return "Dusty Blue"
        case .paleBlue:
            return "Pale Blue"
        }
    }

    var color: Color {
        Color(hex: hex)
    }

    var uiColor: UIColor {
        UIColor(hex: hex)
    }

    var hex: String {
        switch self {
        case .black:
            return "#1F1F1F"
        case .white:
            return "#FFFFFF"
        case .gray:
            return "#6B7D8C"
        case .beige:
            return "#EFE3D0"
        case .navy:
            return "#20364F"
        case .brown:
            return "#6A4A3A"
        case .deepGreen:
            return "#2F5A47"
        case .dustyBlue:
            return "#7EA6C2"
        case .paleBlue:
            return "#DCEFFF"
        }
    }
}

enum FontRole: String, Codable, CaseIterable, Hashable, Identifiable {
    case clean
    case elegant
    case soft
    case modern
    case journal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .clean:
            return "Clean"
        case .elegant:
            return "Elegant"
        case .soft:
            return "Soft"
        case .modern:
            return "Modern"
        case .journal:
            return "Journal"
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .clean:
            return .system(size: size, weight: weight, design: .default)
        case .elegant:
            return .system(size: size, weight: weight, design: .serif)
        case .soft:
            return .system(size: size, weight: weight, design: .rounded)
        case .modern:
            return .system(size: size, weight: weight == .regular ? .medium : weight, design: .default)
        case .journal:
            return .system(size: size, weight: weight, design: .serif).italic()
        }
    }

    func uiFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        switch self {
        case .clean:
            return .systemFont(ofSize: size, weight: weight)
        case .elegant:
            return UIFontDescriptor
                .preferredFontDescriptor(withTextStyle: .body)
                .withDesign(.serif)
                .map { UIFont(descriptor: $0, size: size) } ?? .systemFont(ofSize: size, weight: weight)
        case .soft:
            return UIFontDescriptor
                .preferredFontDescriptor(withTextStyle: .body)
                .withDesign(.rounded)
                .map { UIFont(descriptor: $0, size: size) } ?? .systemFont(ofSize: size, weight: weight)
        case .modern:
            return .systemFont(ofSize: size, weight: weight == .regular ? .medium : weight)
        case .journal:
            let descriptor = UIFontDescriptor
                .preferredFontDescriptor(withTextStyle: .body)
                .withDesign(.serif)?
                .withSymbolicTraits(.traitItalic)
            return descriptor.map { UIFont(descriptor: $0, size: size) } ?? .italicSystemFont(ofSize: size)
        }
    }
}

enum CardAspectRatio: String, Codable, CaseIterable, Hashable, Identifiable {
    case fourByFive = "4:5"
    case square = "1:1"
    case nineBySixteen = "9:16"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }

    var value: CGFloat {
        switch self {
        case .fourByFive:
            return 4 / 5
        case .square:
            return 1
        case .nineBySixteen:
            return 9 / 16
        }
    }

    var outputSize: CGSize {
        switch self {
        case .fourByFive:
            return CGSize(width: 1080, height: 1350)
        case .square:
            return CGSize(width: 1080, height: 1080)
        case .nineBySixteen:
            return CGSize(width: 1080, height: 1920)
        }
    }
}

struct LocalizedDisplayName: Hashable {
    let ja: String
    let en: String
}

extension Template {
    static let previewPetLifelog = Template(
        id: "pet_lifelog_clean_preview",
        name: "Pet Lifelog Clean",
        category: "petLifelog",
        supportedAspectRatios: [.fourByFive, .square, .nineBySixteen],
        defaultLayout: .bottomLeft,
        overlayStyle: OverlayStyle(
            name: "Clean",
            defaultTextColor: .white,
            defaultFontRole: .clean,
            photoPlaceholderStartColor: "#BFD8EA",
            photoPlaceholderEndColor: "#8FB7D9",
            addsSoftShadow: true
        ),
        textFieldDefinitions: [
            CardTextFieldDefinition(id: "location", role: .location, defaultText: "Park", editable: true),
            CardTextFieldDefinition(id: "date", role: .date, defaultText: "2026.06.17", editable: true),
            CardTextFieldDefinition(id: "mainText", role: .mainText, defaultText: "My Pet", editable: true),
            CardTextFieldDefinition(id: "subText", role: .subText, defaultText: "Happy day", editable: true)
        ]
    )
}
