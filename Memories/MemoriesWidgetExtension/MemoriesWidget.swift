import SwiftUI
import UIKit
import WidgetKit

private let appGroupIdentifier = "group.com.myfs716.Memories"
private let snapshotFileName = "pet-calendar-widget-snapshot.json"

struct MemoriesWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPetCalendarSnapshot
    let renderedImage: UIImage?
}

struct MemoriesWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoriesWidgetEntry {
        makeEntry(for: context)
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoriesWidgetEntry) -> Void) {
        completion(makeEntry(for: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoriesWidgetEntry>) -> Void) {
        let entry = makeEntry(for: context)
        let now = Date()
        let periodicUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        let nextDayUpdate = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? periodicUpdate
        let nextUpdate = min(periodicUpdate, nextDayUpdate)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry(for context: Context) -> MemoriesWidgetEntry {
        let snapshot = WidgetPetCalendarSnapshotStore.load()
        return MemoriesWidgetEntry(
            date: Date(),
            snapshot: snapshot,
            renderedImage: WidgetPetCalendarSnapshotStore.renderedImage(for: context.family, snapshot: snapshot)
        )
    }
}

struct MemoriesWidget: Widget {
    let kind = "MemoriesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoriesWidgetProvider()) { entry in
            MemoriesWidgetView(entry: entry)
        }
        .configurationDisplayName("Memories Pet Life")
        .description("Pet Calendar")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}

@main
struct MemoriesWidgetBundle: WidgetBundle {
    var body: some Widget {
        MemoriesWidget()
    }
}

private struct MemoriesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MemoriesWidgetEntry

    var body: some View {
        content
            .redacted(reason: [])
            .unredacted()
            .containerBackground(for: .widget) {
                WidgetAquaBackground()
            }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if let renderedImage = entry.renderedImage {
                RenderedWidgetImageView(image: renderedImage)
            } else {
                WidgetFallbackView(snapshot: entry.snapshot)
            }
        }
        .widgetURL(family == .systemSmall ? URL(string: "memories://calendar/today") : URL(string: "memories://calendar"))
    }
}

private struct RenderedWidgetImageView: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .widgetAccentable(false)
    }
}

private struct WidgetFallbackView: View {
    let snapshot: WidgetPetCalendarSnapshot

    var body: some View {
        ZStack {
            WidgetAquaSurface(cornerRadius: 16)
            VStack(spacing: 6) {
                Text(WidgetCalendarDateRules.monthTitle(for: snapshot.selectedMonth, language: snapshot.displayLanguage))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WidgetCalendarColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                Text("Memories Pet Life")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetCalendarColors.mutedText)
                    .lineLimit(1)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum WidgetCalendarColors {
    static let text = Color(red: 0.10, green: 0.17, blue: 0.24)
    static let mutedText = Color(red: 0.34, green: 0.45, blue: 0.54)
}

private struct WidgetAquaBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.12),
                Color(red: 0.94, green: 0.98, blue: 1.0).opacity(0.10),
                Color(red: 0.86, green: 0.93, blue: 0.96).opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct WidgetAquaSurface: View {
    var cornerRadius: CGFloat
    var isDimmed = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isDimmed ? 0.04 : 0.10),
                        Color(red: 0.95, green: 0.98, blue: 1.0).opacity(isDimmed ? 0.04 : 0.08),
                        Color(red: 0.78, green: 0.88, blue: 0.93).opacity(isDimmed ? 0.03 : 0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDimmed ? 0.18 : 0.60),
                                Color(red: 0.82, green: 0.90, blue: 0.94).opacity(isDimmed ? 0.12 : 0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .widgetAccentable(false)
    }
}

struct WidgetPetCalendarSnapshot: Codable, Hashable {
    var updatedAt: Date
    var selectedMonth: Date
    var displayLanguage: WidgetPetCalendarDisplayLanguage
    var showsBranding: Bool
    var smallImageFileName: String?
    var mediumImageFileName: String?
    var largeImageFileName: String?
    var renderedImageSets: [WidgetPetCalendarRenderedImageSet]
    var entries: [WidgetPetCalendarEntry]

    static let placeholder = WidgetPetCalendarSnapshot(
        updatedAt: Date(),
        selectedMonth: Date(),
        displayLanguage: .japanese,
        showsBranding: true,
        smallImageFileName: nil,
        mediumImageFileName: nil,
        largeImageFileName: nil,
        renderedImageSets: [],
        entries: []
    )

    private enum CodingKeys: String, CodingKey {
        case updatedAt
        case selectedMonth
        case displayLanguage
        case showsBranding
        case smallImageFileName
        case mediumImageFileName
        case largeImageFileName
        case renderedImageSets
        case entries
    }

    init(
        updatedAt: Date,
        selectedMonth: Date,
        displayLanguage: WidgetPetCalendarDisplayLanguage = .japanese,
        showsBranding: Bool = true,
        smallImageFileName: String? = nil,
        mediumImageFileName: String? = nil,
        largeImageFileName: String? = nil,
        renderedImageSets: [WidgetPetCalendarRenderedImageSet] = [],
        entries: [WidgetPetCalendarEntry]
    ) {
        self.updatedAt = updatedAt
        self.selectedMonth = selectedMonth
        self.displayLanguage = displayLanguage
        self.showsBranding = showsBranding
        self.smallImageFileName = smallImageFileName
        self.mediumImageFileName = mediumImageFileName
        self.largeImageFileName = largeImageFileName
        self.renderedImageSets = renderedImageSets
        self.entries = entries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        selectedMonth = try container.decode(Date.self, forKey: .selectedMonth)
        displayLanguage = try container.decodeIfPresent(WidgetPetCalendarDisplayLanguage.self, forKey: .displayLanguage) ?? .japanese
        showsBranding = try container.decodeIfPresent(Bool.self, forKey: .showsBranding) ?? true
        smallImageFileName = try container.decodeIfPresent(String.self, forKey: .smallImageFileName)
        mediumImageFileName = try container.decodeIfPresent(String.self, forKey: .mediumImageFileName)
        largeImageFileName = try container.decodeIfPresent(String.self, forKey: .largeImageFileName)
        renderedImageSets = try container.decodeIfPresent([WidgetPetCalendarRenderedImageSet].self, forKey: .renderedImageSets) ?? []
        entries = container.decodeLossyArray(WidgetPetCalendarEntry.self, forKey: .entries)
    }

}

struct WidgetPetCalendarRenderedImageNames: Codable, Hashable {
    var small: String
    var medium: String
    var large: String
}

struct WidgetPetCalendarRenderedImageSet: Codable, Hashable {
    var dayID: String
    var imageNames: WidgetPetCalendarRenderedImageNames

    func fileName(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall:
            return imageNames.small
        case .systemMedium:
            return imageNames.medium
        case .systemLarge:
            return imageNames.large
        default:
            return imageNames.small
        }
    }
}

struct WidgetPetCalendarEntry: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var imageFileName: String?
    var thumbnailFileName: String?
    var caption: String
    var photoPlacement: WidgetPhotoPlacement
    var overlayStyle: WidgetPetCalendarOverlayStyle

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case imageFileName
        case thumbnailFileName
        case caption
        case photoPlacement
        case overlayStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        thumbnailFileName = try container.decodeIfPresent(String.self, forKey: .thumbnailFileName)
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        photoPlacement = (try container.decodeIfPresent(WidgetPhotoPlacement.self, forKey: .photoPlacement) ?? .default).clamped
        overlayStyle = try container.decodeIfPresent(WidgetPetCalendarOverlayStyle.self, forKey: .overlayStyle) ?? .default
    }
}

enum WidgetPetCalendarDisplayLanguage: String, Codable, Hashable {
    case japanese
    case english
}

enum WidgetPetCalendarOverlayCorner: String, Codable, CaseIterable, Hashable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

enum WidgetPetCalendarThemeIcon: String, Codable, Hashable {
    case walk
    case outing
    case meal
    case nap
    case hospital
    case shampoo
    case cafe
    case home
    case birthday

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
}

enum WidgetPetCalendarWeatherIcon: String, Codable, Hashable {
    case sunny
    case cloudy
    case rainy
    case snowy

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
}

enum WidgetPetCalendarOverlayColorStyle: String, Codable, Hashable {
    case white
    case black
    case navy
    case blue
    case softGray

    var color: Color {
        switch self {
        case .white:
            return .white
        case .black:
            return Color(red: 0.12, green: 0.12, blue: 0.12)
        case .navy:
            return Color(red: 0.13, green: 0.21, blue: 0.31)
        case .blue:
            return Color(red: 0.31, green: 0.50, blue: 0.64)
        case .softGray:
            return Color(red: 0.86, green: 0.89, blue: 0.92)
        }
    }
}

enum WidgetPetCalendarOverlayFontStyle: String, Codable, Hashable {
    case rounded
    case regular
    case bold
}

struct WidgetPetCalendarOverlayStyle: Codable, Hashable {
    var isThemeIconVisible: Bool
    var themeIcon: WidgetPetCalendarThemeIcon?
    var themeIconCorner: WidgetPetCalendarOverlayCorner
    var isWeatherIconVisible: Bool
    var weatherIcon: WidgetPetCalendarWeatherIcon?
    var weatherIconCorner: WidgetPetCalendarOverlayCorner
    var textColor: WidgetPetCalendarOverlayColorStyle
    var accentColor: WidgetPetCalendarOverlayColorStyle
    var fontStyle: WidgetPetCalendarOverlayFontStyle

    static let `default` = WidgetPetCalendarOverlayStyle(
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
        themeIcon: WidgetPetCalendarThemeIcon?,
        themeIconCorner: WidgetPetCalendarOverlayCorner,
        isWeatherIconVisible: Bool,
        weatherIcon: WidgetPetCalendarWeatherIcon?,
        weatherIconCorner: WidgetPetCalendarOverlayCorner,
        textColor: WidgetPetCalendarOverlayColorStyle,
        accentColor: WidgetPetCalendarOverlayColorStyle,
        fontStyle: WidgetPetCalendarOverlayFontStyle
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
        themeIcon = (try? container.decodeIfPresent(WidgetPetCalendarThemeIcon.self, forKey: .themeIcon)) ?? fallback.themeIcon
        themeIconCorner = (try? container.decodeIfPresent(WidgetPetCalendarOverlayCorner.self, forKey: .themeIconCorner)) ?? fallback.themeIconCorner
        isWeatherIconVisible = (try? container.decodeIfPresent(Bool.self, forKey: .isWeatherIconVisible)) ?? fallback.isWeatherIconVisible
        weatherIcon = (try? container.decodeIfPresent(WidgetPetCalendarWeatherIcon.self, forKey: .weatherIcon)) ?? fallback.weatherIcon
        weatherIconCorner = (try? container.decodeIfPresent(WidgetPetCalendarOverlayCorner.self, forKey: .weatherIconCorner)) ?? fallback.weatherIconCorner
        textColor = (try? container.decodeIfPresent(WidgetPetCalendarOverlayColorStyle.self, forKey: .textColor)) ?? fallback.textColor
        accentColor = (try? container.decodeIfPresent(WidgetPetCalendarOverlayColorStyle.self, forKey: .accentColor)) ?? fallback.accentColor
        fontStyle = (try? container.decodeIfPresent(WidgetPetCalendarOverlayFontStyle.self, forKey: .fontStyle)) ?? fallback.fontStyle
    }

    var effectiveThemeIcon: WidgetPetCalendarThemeIcon? {
        isThemeIconVisible ? (themeIcon ?? .walk) : nil
    }

    var effectiveWeatherIcon: WidgetPetCalendarWeatherIcon? {
        isWeatherIconVisible ? (weatherIcon ?? .sunny) : nil
    }

    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch fontStyle {
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .regular:
            return .system(size: size, weight: weight, design: .default)
        case .bold:
            return .system(size: size, weight: .bold, design: .default)
        }
    }
}

struct WidgetPhotoPlacement: Codable, Hashable {
    var scale: Double
    var offsetX: Double
    var offsetY: Double

    static let `default` = WidgetPhotoPlacement(scale: 1, offsetX: 0, offsetY: 0)

    var clamped: WidgetPhotoPlacement {
        WidgetPhotoPlacement(
            scale: min(max(scale, 1), 3),
            offsetX: min(max(offsetX, -1), 1),
            offsetY: min(max(offsetY, -1), 1)
        )
    }
}

private enum WidgetPetCalendarSnapshotStore {
    static func load() -> WidgetPetCalendarSnapshot {
        loadSnapshot()
    }

    private static func loadSnapshot() -> WidgetPetCalendarSnapshot {
        guard
            let directory = sharedDirectory,
            let data = try? Data(contentsOf: directory.appendingPathComponent(snapshotFileName))
        else {
            return .placeholder
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(WidgetPetCalendarSnapshot.self, from: data)) ?? .placeholder
    }

    static func renderedImage(for family: WidgetFamily, snapshot: WidgetPetCalendarSnapshot) -> UIImage? {
        guard let directory = sharedDirectory else {
            return nil
        }

        let todayID = WidgetCalendarDateRules.id(for: Date())
        let fileName = snapshot.renderedImageSets
            .first(where: { $0.dayID == todayID })?
            .fileName(for: family)
            ?? legacyFileName(for: family, snapshot: snapshot)

        guard let fileName else {
            return nil
        }
        return UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path)
    }

    private static func legacyFileName(for family: WidgetFamily, snapshot: WidgetPetCalendarSnapshot) -> String? {
        switch family {
        case .systemSmall:
            return snapshot.smallImageFileName
        case .systemMedium:
            return snapshot.mediumImageFileName
        case .systemLarge:
            return snapshot.largeImageFileName
        default:
            return snapshot.smallImageFileName
        }
    }

    private static var sharedDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("PetCalendar/Widget", isDirectory: true)
    }
}

private struct WidgetPetCalendarDiscardedValue: Decodable {
    init(from decoder: Decoder) throws {
        if var container = try? decoder.unkeyedContainer() {
            while !container.isAtEnd {
                _ = try? container.decode(WidgetPetCalendarDiscardedValue.self)
            }
            return
        }

        if let container = try? decoder.container(keyedBy: WidgetPetCalendarDynamicCodingKey.self) {
            for key in container.allKeys {
                _ = try? container.decode(WidgetPetCalendarDiscardedValue.self, forKey: key)
            }
            return
        }

        let container = try? decoder.singleValueContainer()
        _ = try? container?.decode(Bool.self)
        _ = try? container?.decode(Double.self)
        _ = try? container?.decode(String.self)
    }
}

private struct WidgetPetCalendarDynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyArray<Element: Decodable>(_ type: Element.Type, forKey key: Key) -> [Element] {
        (try? decode(WidgetPetCalendarLossyArray<Element>.self, forKey: key).elements) ?? []
    }
}

private struct WidgetPetCalendarLossyArray<Element: Decodable>: Decodable {
    var elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                let previousIndex = container.currentIndex
                _ = try? container.decode(WidgetPetCalendarDiscardedValue.self)
                if container.currentIndex == previousIndex {
                    break
                }
            }
        }
        self.elements = elements
    }
}

private enum WidgetCalendarDateRules {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        return calendar
    }

    static func monthTitle(for date: Date, language: WidgetPetCalendarDisplayLanguage) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        switch language {
        case .japanese:
            return "\(year)年\(month)月"
        case .english:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }
    }

    static func id(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
