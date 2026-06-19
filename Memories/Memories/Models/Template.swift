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
    let renderStyle: TemplateRenderStyle

    init(
        id: String,
        name: String,
        category: String,
        supportedAspectRatios: [CardAspectRatio],
        defaultLayout: OverlayPosition,
        overlayStyle: OverlayStyle,
        textFieldDefinitions: [CardTextFieldDefinition],
        renderStyle: TemplateRenderStyle = .simpleCard
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.supportedAspectRatios = supportedAspectRatios
        self.defaultLayout = defaultLayout
        self.overlayStyle = overlayStyle
        self.textFieldDefinitions = textFieldDefinitions
        self.renderStyle = renderStyle
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case supportedAspectRatios
        case defaultLayout
        case overlayStyle
        case textFieldDefinitions
        case renderStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        supportedAspectRatios = try container.decode([CardAspectRatio].self, forKey: .supportedAspectRatios)
        defaultLayout = try container.decode(OverlayPosition.self, forKey: .defaultLayout)
        overlayStyle = try container.decode(OverlayStyle.self, forKey: .overlayStyle)
        textFieldDefinitions = try container.decode([CardTextFieldDefinition].self, forKey: .textFieldDefinitions)
        renderStyle = try container.decodeIfPresent(TemplateRenderStyle.self, forKey: .renderStyle) ?? .simpleCard
    }

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

    var isTicketStyle: Bool {
        renderStyle.isTicket
    }

    var previewEditState: CardEditState {
        if renderStyle.isRetroFilm {
            return CardEditState(
                selectedThemeIcon: .walk,
                selectedWeather: .none,
                locationText: "",
                dateMode: .single,
                selectedDate: CardEditState.date(year: 2026, month: 6, day: 19),
                startDate: CardEditState.date(year: 2026, month: 6, day: 19),
                endDate: CardEditState.date(year: 2026, month: 6, day: 19),
                customDateText: "",
                mainText: "",
                subText: "",
                ticketTitle: "",
                selectedPosition: .bottomRight,
                selectedFontRole: overlayStyle.defaultFontRole,
                selectedTextColor: overlayStyle.defaultTextColor,
                visibilitySettings: VisibilitySettings(
                    showThemeIcon: false,
                    showLocation: false,
                    showDate: true,
                    showWeather: false,
                    showMainText: false,
                    showSubText: false
                ),
                photoPlacement: .default,
                retroFilterType: .sepia
            )
        }

        return CardEditState(
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
            ticketTitle: "MEMORY TICKET",
            selectedPosition: defaultLayout,
            selectedFontRole: overlayStyle.defaultFontRole,
            selectedTextColor: overlayStyle.defaultTextColor,
            visibilitySettings: .allVisible,
            photoPlacement: .default
        )
    }
}

enum TemplateRenderStyle: String, Codable, Hashable {
    case simpleCard
    case ticketPortrait
    case ticketLandscape
    case retroFilm

    var isTicket: Bool {
        self == .ticketPortrait || self == .ticketLandscape
    }

    var isRetroFilm: Bool {
        self == .retroFilm
    }

    var ticketFrameAssetName: String? {
        switch self {
        case .simpleCard, .retroFilm:
            return nil
        case .ticketPortrait:
            return "ticket_frame_portrait"
        case .ticketLandscape:
            return "ticket_frame_landscape"
        }
    }

    var outputSize: CGSize? {
        switch self {
        case .simpleCard, .retroFilm:
            return nil
        case .ticketPortrait:
            return CGSize(width: 1600, height: 2000)
        case .ticketLandscape:
            return CGSize(width: 2400, height: 1600)
        }
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
    case ticketTitle

    var id: String { rawValue }
}

enum CardDateMode: String, Codable, CaseIterable, Hashable, Identifiable {
    case single
    case range
    case custom

    var id: String { rawValue }

    var displayName: String {
        displayName(language: .japanese)
    }

    func displayName(language: ResolvedAppLanguage) -> String {
        switch self {
        case .single:
            return MemoriesLocalization.text("date.single", language: language)
        case .range:
            return MemoriesLocalization.text("date.range", language: language)
        case .custom:
            return MemoriesLocalization.text("date.custom", language: language)
        }
    }
}

struct CardEditState: Codable, Hashable {
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
    var ticketTitle: String
    var selectedPosition: OverlayPosition
    var selectedFontRole: FontRole
    var selectedTextColor: TextColorOption
    var visibilitySettings: VisibilitySettings
    var photoPlacement: PhotoPlacement
    var retroFilterType: RetroFilterType

    init(
        selectedThemeIcon: ThemeIconType,
        selectedWeather: WeatherType,
        locationText: String,
        dateMode: CardDateMode,
        selectedDate: Date,
        startDate: Date,
        endDate: Date,
        customDateText: String,
        mainText: String,
        subText: String,
        ticketTitle: String = "MEMORY TICKET",
        selectedPosition: OverlayPosition,
        selectedFontRole: FontRole,
        selectedTextColor: TextColorOption,
        visibilitySettings: VisibilitySettings,
        photoPlacement: PhotoPlacement = .default,
        retroFilterType: RetroFilterType = .sepia
    ) {
        self.selectedThemeIcon = selectedThemeIcon
        self.selectedWeather = selectedWeather
        self.locationText = locationText
        self.dateMode = dateMode
        self.selectedDate = selectedDate
        self.startDate = startDate
        self.endDate = endDate
        self.customDateText = customDateText
        self.mainText = mainText
        self.subText = subText
        self.ticketTitle = ticketTitle
        self.selectedPosition = selectedPosition
        self.selectedFontRole = selectedFontRole
        self.selectedTextColor = selectedTextColor
        self.visibilitySettings = visibilitySettings
        self.photoPlacement = photoPlacement
        self.retroFilterType = retroFilterType
    }

    enum CodingKeys: String, CodingKey {
        case selectedThemeIcon
        case selectedWeather
        case locationText
        case dateMode
        case selectedDate
        case startDate
        case endDate
        case customDateText
        case mainText
        case subText
        case ticketTitle
        case selectedPosition
        case selectedFontRole
        case selectedTextColor
        case visibilitySettings
        case photoPlacement
        case retroFilterType
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case retroFilterStrength
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        selectedThemeIcon = try container.decodeIfPresent(ThemeIconType.self, forKey: .selectedThemeIcon) ?? .walk
        selectedWeather = try container.decodeIfPresent(WeatherType.self, forKey: .selectedWeather) ?? .none
        locationText = try container.decodeIfPresent(String.self, forKey: .locationText) ?? ""
        dateMode = try container.decodeIfPresent(CardDateMode.self, forKey: .dateMode) ?? .single
        selectedDate = try container.decodeIfPresent(Date.self, forKey: .selectedDate) ?? Self.normalizedDate(Date())
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? selectedDate
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate) ?? startDate
        customDateText = try container.decodeIfPresent(String.self, forKey: .customDateText) ?? ""
        mainText = try container.decodeIfPresent(String.self, forKey: .mainText) ?? ""
        subText = try container.decodeIfPresent(String.self, forKey: .subText) ?? ""
        ticketTitle = try container.decodeIfPresent(String.self, forKey: .ticketTitle) ?? "MEMORY TICKET"
        selectedPosition = try container.decodeIfPresent(OverlayPosition.self, forKey: .selectedPosition) ?? .bottomLeft
        selectedFontRole = try container.decodeIfPresent(FontRole.self, forKey: .selectedFontRole) ?? .clean
        selectedTextColor = try container.decodeIfPresent(TextColorOption.self, forKey: .selectedTextColor) ?? .white
        visibilitySettings = try container.decodeIfPresent(VisibilitySettings.self, forKey: .visibilitySettings) ?? .newCardDefault
        photoPlacement = try container.decodeIfPresent(PhotoPlacement.self, forKey: .photoPlacement) ?? .default
        retroFilterType = try container.decodeIfPresent(RetroFilterType.self, forKey: .retroFilterType)
            ?? (try legacyContainer.decodeIfPresent(LegacyRetroFilterStrength.self, forKey: .retroFilterStrength))?.fallbackFilterType
            ?? .sepia
    }

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

    var retroDateStampText: String {
        Self.retroDateFormatter.string(from: selectedDate)
    }

    static func newCard(
        defaultLayout: OverlayPosition,
        fontRole: FontRole,
        textColor: TextColorOption,
        date: Date = Date()
    ) -> CardEditState {
        CardEditState(
            selectedThemeIcon: .walk,
            selectedWeather: .sunny,
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

    private static let retroDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM dd ''yy"
        return formatter
    }()
}

enum RetroFilterType: String, Codable, CaseIterable, Hashable, Identifiable {
    case sepia
    case nostalgic
    case monochrome

    var id: String { rawValue }

    func displayName(language: ResolvedAppLanguage) -> String {
        switch self {
        case .sepia:
            return MemoriesLocalization.text("retro.sepia", language: language)
        case .nostalgic:
            return MemoriesLocalization.text("retro.nostalgic", language: language)
        case .monochrome:
            return MemoriesLocalization.text("retro.monochrome", language: language)
        }
    }
}

private enum LegacyRetroFilterStrength: String, Codable {
    case light
    case medium
    case strong

    var fallbackFilterType: RetroFilterType {
        .nostalgic
    }
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
        showWeather: true,
        showMainText: true,
        showSubText: true
    )
}

struct PhotoPlacement: Codable, Hashable {
    var scale: Double
    var offsetX: Double
    var offsetY: Double

    static let `default` = PhotoPlacement(scale: 1, offsetX: 0, offsetY: 0)

    var clamped: PhotoPlacement {
        PhotoPlacement(
            scale: min(max(scale, 1), 3),
            offsetX: min(max(offsetX, -1), 1),
            offsetY: min(max(offsetY, -1), 1)
        )
    }
}

enum OverlayPosition: String, Codable, CaseIterable, Hashable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var displayName: String {
        displayName(language: .japanese)
    }

    func displayName(language: ResolvedAppLanguage) -> String {
        switch self {
        case .topLeft:
            return language == .japanese ? "左上" : "Top Left"
        case .topRight:
            return language == .japanese ? "右上" : "Top Right"
        case .bottomLeft:
            return language == .japanese ? "左下" : "Bottom Left"
        case .bottomRight:
            return language == .japanese ? "右下" : "Bottom Right"
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
            return LocalizedDisplayName(ja: "お昼寝 犬", en: "Nap Dog")
        case .napCat:
            return LocalizedDisplayName(ja: "お昼寝 猫", en: "Nap Cat")
        case .travel:
            return LocalizedDisplayName(ja: "旅行", en: "Travel")
        case .hospital:
            return LocalizedDisplayName(ja: "病院", en: "Vet")
        case .shampoo:
            return LocalizedDisplayName(ja: "シャンプー", en: "Bath")
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

    var assetName: String {
        switch self {
        case .meal:
            return "theme_food"
        case .walk:
            return "theme_walk"
        case .napDog:
            return "theme_nap_dog"
        case .napCat:
            return "theme_nap_cat"
        case .travel:
            return "theme_travel"
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
            return LocalizedDisplayName(ja: "曇り", en: "Cloudy")
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

    var assetName: String? {
        switch self {
        case .none:
            return nil
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

enum UtilityIconType {
    case location
    case calendar

    var assetName: String {
        switch self {
        case .location:
            return "utility_location"
        case .calendar:
            return "utility_calendar"
        }
    }

    var fallbackSymbolName: String {
        switch self {
        case .location:
            return "mappin"
        case .calendar:
            return "calendar"
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
        displayName(language: .english)
    }

    func displayName(language: ResolvedAppLanguage) -> String {
        if language == .japanese {
            switch self {
            case .black:
                return "黒"
            case .white:
                return "白"
            case .gray:
                return "グレー"
            case .beige:
                return "ベージュ"
            case .navy:
                return "ネイビー"
            case .brown:
                return "ブラウン"
            case .deepGreen:
                return "深緑"
            case .dustyBlue:
                return "ダスティブルー"
            case .paleBlue:
                return "ペールブルー"
            }
        }

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

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if rawValue == "rounded" {
            self = .soft
            return
        }

        self = FontRole(rawValue: rawValue) ?? .clean
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

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

    func displayName(language: ResolvedAppLanguage) -> String {
        displayName
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
            return roundedUIFont(size: size, weight: weight)
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

    private func roundedUIFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let baseFont = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = baseFont.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return baseFont
    }
}

enum CardAspectRatio: String, Codable, CaseIterable, Hashable, Identifiable {
    case fourByFive = "4:5"
    case square = "1:1"
    case nineBySixteen = "9:16"
    case threeByTwo = "3:2"

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
        case .threeByTwo:
            return 3 / 2
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
        case .threeByTwo:
            return CGSize(width: 2400, height: 1600)
        }
    }
}

struct LocalizedDisplayName: Hashable {
    let ja: String
    let en: String

    func localized(for language: ResolvedAppLanguage) -> String {
        language == .japanese ? ja : en
    }
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
