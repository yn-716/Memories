import SwiftUI
import UIKit
import WidgetKit

private let appGroupIdentifier = "group.com.myfs716.Memories"
private let snapshotFileName = "pet-calendar-widget-snapshot.json"

struct MemoriesWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPetCalendarSnapshot
}

struct MemoriesWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoriesWidgetEntry {
        MemoriesWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoriesWidgetEntry) -> Void) {
        completion(MemoriesWidgetEntry(date: Date(), snapshot: WidgetPetCalendarSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoriesWidgetEntry>) -> Void) {
        let entry = MemoriesWidgetEntry(date: Date(), snapshot: WidgetPetCalendarSnapshotStore.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
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
            .systemLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
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
        switch family {
        case .systemSmall:
            TodayWidgetView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "memories://calendar/today"))
        case .systemMedium, .systemLarge:
            MonthWidgetView(snapshot: entry.snapshot, isLarge: family == .systemLarge)
                .widgetURL(URL(string: "memories://calendar"))
        case .accessoryInline:
            AccessoryInlineWidgetView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "memories://calendar/today"))
        case .accessoryCircular:
            AccessoryCircularWidgetView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "memories://calendar/today"))
        case .accessoryRectangular:
            AccessoryRectangularWidgetView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "memories://calendar/today"))
        default:
            TodayWidgetView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "memories://calendar/today"))
        }
    }
}

private struct TodayWidgetView: View {
    let snapshot: WidgetPetCalendarSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if snapshot.showsBranding {
                Text("Memories Pet Life")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.16))
                if let todayEntry = snapshot.todayEntry,
                   let image = WidgetPetCalendarSnapshotStore.thumbnail(for: todayEntry) {
                    WidgetPlacedImage(image: image, placement: todayEntry.photoPlacement)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    WidgetCellOverlayLayer(
                        day: Calendar.current.component(.day, from: Date()),
                        overlayStyle: todayEntry.overlayStyle,
                        usesCustomStyle: true,
                        showsDate: false,
                        isLarge: true
                    )
                } else {
                    WidgetPawShape()
                        .fill(Color.secondary.opacity(0.22))
                        .frame(width: 44, height: 44)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 86)
            .clipped()

            Text(todayTitle)
                .font(.headline.weight(.bold))
                .lineLimit(1)

            Text(todayStatusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .containerBackground(.background, for: .widget)
    }

    private var todayTitle: String {
        let day = Calendar.current.component(.day, from: Date())
        return "\(day)"
    }

    private var todayStatusText: String {
        if snapshot.displayLanguage == .japanese {
            return snapshot.todayEntry == nil ? "今日の1枚を追加" : "登録済み"
        }
        return snapshot.todayEntry == nil ? "Add today" : "Saved"
    }
}

private struct MonthWidgetView: View {
    let snapshot: WidgetPetCalendarSnapshot
    let isLarge: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(monthTitle)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                Spacer()
                if snapshot.showsBranding {
                    Text("Memories")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(Array(WidgetCalendarDateRules.weekdays(language: snapshot.displayLanguage).enumerated()), id: \.offset) { _, weekday in
                    Text(weekday)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(WidgetCalendarDateRules.monthGrid(for: snapshot.selectedMonth), id: \.id) { cell in
                    WidgetMonthCell(cell: cell, entry: snapshot.entryByID[cell.id], isLarge: isLarge)
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: snapshot.displayLanguage == .japanese ? "ja_JP" : "en_US")
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: snapshot.selectedMonth)
    }
}

private struct WidgetMonthCell: View {
    let cell: WidgetMonthCellModel
    let entry: WidgetPetCalendarEntry?
    let isLarge: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(cell.isInDisplayedMonth ? Color.gray.opacity(0.16) : Color.clear)
                .overlay {
                    if let entry, let image = WidgetPetCalendarSnapshotStore.thumbnail(for: entry) {
                        WidgetPlacedImage(image: image, placement: entry.photoPlacement)
                            .overlay(Color.black.opacity(0.08))
                    } else if cell.isInDisplayedMonth {
                        WidgetPawShape()
                            .fill(Color.secondary.opacity(0.16))
                            .padding(isLarge ? 7 : 4)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(cell.isToday ? Color.accentColor : Color.clear, lineWidth: 1.5)
                }

            if cell.isInDisplayedMonth {
                WidgetCellOverlayLayer(
                    day: cell.day,
                    overlayStyle: entry?.overlayStyle ?? .default,
                    usesCustomStyle: entry != nil,
                    showsDate: true,
                    isLarge: isLarge
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(cell.isFuture ? 0.42 : 1)
    }
}

private struct AccessoryInlineWidgetView: View {
    let snapshot: WidgetPetCalendarSnapshot

    var body: some View {
        Text(accessoryText)
    }

    private var accessoryText: String {
        if snapshot.displayLanguage == .japanese {
            return snapshot.todayEntry == nil ? "うちの子: 今日追加" : "うちの子: 登録済み"
        }
        return snapshot.todayEntry == nil ? "Pet Calendar: Add today" : "Pet Calendar: Saved"
    }
}

private struct AccessoryCircularWidgetView: View {
    let snapshot: WidgetPetCalendarSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if snapshot.todayEntry == nil {
                WidgetPawShape()
                    .fill(Color.secondary.opacity(0.6))
                    .padding(11)
            } else {
                VStack(spacing: 0) {
                    Text("\(Calendar.current.component(.day, from: Date()))")
                        .font(.headline.weight(.bold))
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
            }
        }
    }
}

private struct AccessoryRectangularWidgetView: View {
    let snapshot: WidgetPetCalendarSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(snapshot.displayLanguage == .japanese ? "今週" : "This Week")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 2)
                if snapshot.showsBranding {
                    Text("Memories")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            weekRow { day in
                Text(day.weekdaySymbol)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            weekRow { day in
                Text("\(day.day)")
                    .font(.system(size: 10, weight: day.isToday ? .bold : .semibold))
                    .foregroundStyle(day.isFuture ? Color.secondary.opacity(0.55) : Color.primary)
            }
            weekRow { day in
                statusMark(day)
            }
        }
    }

    private func weekRow<Content: View>(@ViewBuilder content: @escaping (WidgetWeekDayModel) -> Content) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<weekDays.count, id: \.self) { index in
                content(weekDays[index])
                    .frame(maxWidth: .infinity)
                    .frame(height: 10)
                    .opacity(weekDays[index].isFuture ? 0.48 : 1)
            }
        }
    }

    private var weekDays: [WidgetWeekDayModel] {
        WidgetCalendarDateRules.week(
            containing: Date(),
            registeredEntryIDs: snapshot.entryIDs,
            language: snapshot.displayLanguage
        )
    }

    @ViewBuilder
    private func statusMark(_ day: WidgetWeekDayModel) -> some View {
        if day.isFuture {
            Text("-")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.55))
        } else if day.isRegistered {
            Image(systemName: day.isToday ? "checkmark.circle.fill" : "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.accentColor)
        } else if day.isToday {
            Circle()
                .stroke(Color.accentColor, lineWidth: 1.2)
                .frame(width: 7, height: 7)
        } else {
            Circle()
                .fill(Color.secondary.opacity(0.38))
                .frame(width: 5, height: 5)
        }
    }
}

private struct WidgetCellOverlayLayer: View {
    let day: Int
    let overlayStyle: WidgetPetCalendarOverlayStyle
    let usesCustomStyle: Bool
    let showsDate: Bool
    let isLarge: Bool

    var body: some View {
        GeometryReader { proxy in
            let minSide = min(proxy.size.width, proxy.size.height)
            let iconSize = min(max(minSide * 0.23, isLarge ? 14 : 10), isLarge ? 22 : 16)
            let inset = max(minSide * 0.07, isLarge ? 3 : 2)
            ZStack(alignment: .topLeading) {
                if showsDate {
                    Text("\(day)")
                        .font(overlayStyle.font(size: isLarge ? 11 : 8, weight: .bold))
                        .foregroundStyle(usesCustomStyle ? overlayStyle.textColor.color : (Color.primary))
                        .shadow(color: usesCustomStyle ? Color.black.opacity(0.28) : .clear, radius: 1, y: 1)
                        .padding(2)
                }

                ForEach(overlayItems.indices, id: \.self) { index in
                    let item = overlayItems[index]
                    WidgetOverlayIconView(
                        symbolName: item.symbolName,
                        color: overlayStyle.accentColor.color,
                        size: iconSize
                    )
                    .position(position(for: item.corner, itemIndex: indexInCorner(index), iconSize: iconSize, inset: inset, size: proxy.size, reservesDateSpace: showsDate))
                }
            }
        }
    }

    private var overlayItems: [WidgetOverlayViewItem] {
        guard usesCustomStyle else {
            return []
        }
        var items: [WidgetOverlayViewItem] = []
        if let icon = overlayStyle.effectiveThemeIcon {
            items.append(WidgetOverlayViewItem(corner: overlayStyle.themeIconCorner, symbolName: icon.symbolName))
        }
        if let icon = overlayStyle.effectiveWeatherIcon {
            items.append(WidgetOverlayViewItem(corner: overlayStyle.weatherIconCorner, symbolName: icon.symbolName))
        }
        return items
    }

    private func indexInCorner(_ index: Int) -> Int {
        let corner = overlayItems[index].corner
        return overlayItems[..<index].filter { $0.corner == corner }.count
    }

    private func position(
        for corner: WidgetPetCalendarOverlayCorner,
        itemIndex: Int,
        iconSize: CGFloat,
        inset: CGFloat,
        size: CGSize,
        reservesDateSpace: Bool
    ) -> CGPoint {
        let spacing: CGFloat = 2
        let stackOffset = CGFloat(itemIndex) * (iconSize + spacing)
        let x: CGFloat
        switch corner {
        case .topLeft, .bottomLeft:
            x = inset + iconSize / 2
        case .topRight, .bottomRight:
            x = size.width - inset - iconSize / 2
        }

        let y: CGFloat
        switch corner {
        case .topLeft:
            y = inset + iconSize / 2 + (reservesDateSpace ? 12 : 0) + stackOffset
        case .topRight:
            y = inset + iconSize / 2 + stackOffset
        case .bottomLeft, .bottomRight:
            y = size.height - inset - iconSize / 2 - stackOffset
        }

        return CGPoint(x: x, y: y)
    }
}

private struct WidgetOverlayViewItem {
    var corner: WidgetPetCalendarOverlayCorner
    var symbolName: String
}

private struct WidgetOverlayIconView: View {
    let symbolName: String
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(color.prefersDarkOverlayBackground ? Color.black.opacity(0.30) : Color.white.opacity(0.64))
            Image(systemName: symbolName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
                .padding(size * 0.25)
        }
        .frame(width: size, height: size)
    }
}

private extension Color {
    var prefersDarkOverlayBackground: Bool {
        guard let components = UIColor(self).cgColor.components else {
            return true
        }
        let red = components.indices.contains(0) ? components[0] : 1
        let green = components.indices.contains(1) ? components[1] : red
        let blue = components.indices.contains(2) ? components[2] : red
        return (red * 0.299 + green * 0.587 + blue * 0.114) > 0.58
    }
}

private struct WidgetPawShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        let toe = side * 0.18
        let toeCenters = [
            CGPoint(x: origin.x + side * 0.24, y: origin.y + side * 0.28),
            CGPoint(x: origin.x + side * 0.42, y: origin.y + side * 0.20),
            CGPoint(x: origin.x + side * 0.58, y: origin.y + side * 0.20),
            CGPoint(x: origin.x + side * 0.76, y: origin.y + side * 0.28)
        ]
        for point in toeCenters {
            path.addEllipse(in: CGRect(x: point.x - toe / 2, y: point.y - toe / 2, width: toe, height: toe * 1.12))
        }
        path.addRoundedRect(in: CGRect(
            x: origin.x + side * 0.30,
            y: origin.y + side * 0.46,
            width: side * 0.40,
            height: side * 0.36
        ), cornerSize: CGSize(
            width: side * 0.18,
            height: side * 0.18
        ))
        return path
    }
}

private struct WidgetPlacedImage: View {
    let image: UIImage
    let placement: WidgetPhotoPlacement

    var body: some View {
        GeometryReader { proxy in
            let frameRect = CGRect(origin: .zero, size: proxy.size)
            let drawRect = WidgetPhotoPlacementLayout.drawRect(
                imageSize: image.size,
                frameRect: frameRect,
                placement: placement
            )
            Image(uiImage: image)
                .resizable()
                .frame(width: drawRect.width, height: drawRect.height)
                .position(x: drawRect.midX, y: drawRect.midY)
        }
        .clipped()
    }
}

struct WidgetPetCalendarSnapshot: Codable, Hashable {
    var updatedAt: Date
    var selectedMonth: Date
    var displayLanguage: WidgetPetCalendarDisplayLanguage
    var showsBranding: Bool
    var entries: [WidgetPetCalendarEntry]

    static let placeholder = WidgetPetCalendarSnapshot(
        updatedAt: Date(),
        selectedMonth: Date(),
        displayLanguage: .japanese,
        showsBranding: true,
        entries: []
    )

    private enum CodingKeys: String, CodingKey {
        case updatedAt
        case selectedMonth
        case displayLanguage
        case showsBranding
        case entries
    }

    init(
        updatedAt: Date,
        selectedMonth: Date,
        displayLanguage: WidgetPetCalendarDisplayLanguage = .japanese,
        showsBranding: Bool = true,
        entries: [WidgetPetCalendarEntry]
    ) {
        self.updatedAt = updatedAt
        self.selectedMonth = selectedMonth
        self.displayLanguage = displayLanguage
        self.showsBranding = showsBranding
        self.entries = entries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        selectedMonth = try container.decode(Date.self, forKey: .selectedMonth)
        displayLanguage = try container.decodeIfPresent(WidgetPetCalendarDisplayLanguage.self, forKey: .displayLanguage) ?? .japanese
        showsBranding = try container.decodeIfPresent(Bool.self, forKey: .showsBranding) ?? true
        entries = try container.decode([WidgetPetCalendarEntry].self, forKey: .entries)
    }

    var todayEntry: WidgetPetCalendarEntry? {
        entryByID[WidgetCalendarDateRules.id(for: Date())]
    }

    var entryByID: [String: WidgetPetCalendarEntry] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }

    var entryIDs: Set<String> {
        Set(entries.map(\.id))
    }
}

struct WidgetPetCalendarEntry: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var thumbnailFileName: String
    var caption: String
    var photoPlacement: WidgetPhotoPlacement
    var overlayStyle: WidgetPetCalendarOverlayStyle

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case thumbnailFileName
        case caption
        case photoPlacement
        case overlayStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        thumbnailFileName = try container.decode(String.self, forKey: .thumbnailFileName)
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

private enum WidgetPhotoPlacementLayout {
    static func drawRect(imageSize: CGSize, frameRect: CGRect, placement: WidgetPhotoPlacement) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, frameRect.width > 0, frameRect.height > 0 else {
            return frameRect
        }
        let clamped = placement.clamped
        let baseScale = max(frameRect.width / imageSize.width, frameRect.height / imageSize.height)
        let drawScale = baseScale * CGFloat(clamped.scale)
        let drawSize = CGSize(width: imageSize.width * drawScale, height: imageSize.height * drawScale)
        let overflowX = max(0, (drawSize.width - frameRect.width) / 2)
        let overflowY = max(0, (drawSize.height - frameRect.height) / 2)
        let center = CGPoint(
            x: frameRect.midX + CGFloat(clamped.offsetX) * overflowX,
            y: frameRect.midY + CGFloat(clamped.offsetY) * overflowY
        )
        return CGRect(
            x: center.x - drawSize.width / 2,
            y: center.y - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
    }
}

private enum WidgetPetCalendarSnapshotStore {
    static func load() -> WidgetPetCalendarSnapshot {
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

    static func thumbnail(for entry: WidgetPetCalendarEntry) -> UIImage? {
        guard let directory = sharedDirectory?.deletingLastPathComponent() else {
            return nil
        }
        let thumbnailURL = directory
            .appendingPathComponent("Thumbnails", isDirectory: true)
            .appendingPathComponent(entry.thumbnailFileName)
        return UIImage(contentsOfFile: thumbnailURL.path)
    }

    private static var sharedDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("PetCalendar/Widget", isDirectory: true)
    }
}

private struct WidgetMonthCellModel: Hashable {
    var id: String
    var date: Date
    var day: Int
    var isInDisplayedMonth: Bool
    var isToday: Bool
    var isFuture: Bool
}

private struct WidgetWeekDayModel: Identifiable, Hashable {
    var id: String
    var date: Date
    var day: Int
    var weekdaySymbol: String
    var isToday: Bool
    var isFuture: Bool
    var isRegistered: Bool
}

private enum WidgetCalendarDateRules {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        return calendar
    }

    static func weekdays(language: WidgetPetCalendarDisplayLanguage) -> [String] {
        switch language {
        case .japanese:
            return ["日", "月", "火", "水", "木", "金", "土"]
        case .english:
            return ["S", "M", "T", "W", "T", "F", "S"]
        }
    }

    static func id(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }

    static func startOfWeek(containing date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        let leadingDays = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -leadingDays, to: start) ?? start
    }

    static func week(
        containing date: Date,
        now: Date = Date(),
        registeredEntryIDs: Set<String>,
        language: WidgetPetCalendarDisplayLanguage
    ) -> [WidgetWeekDayModel] {
        let start = startOfWeek(containing: date)
        let todayID = id(for: now)
        let weekdaySymbols = weekdays(language: language)
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            let dayID = id(for: day)
            return WidgetWeekDayModel(
                id: dayID,
                date: day,
                day: calendar.component(.day, from: day),
                weekdaySymbol: weekdaySymbols[offset],
                isToday: dayID == todayID,
                isFuture: calendar.startOfDay(for: day) > calendar.startOfDay(for: now),
                isRegistered: registeredEntryIDs.contains(dayID)
            )
        }
    }

    static func monthGrid(for month: Date) -> [WidgetMonthCellModel] {
        let monthStart = monthStart(for: month)
        let leadingDays = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart
        let displayedMonth = calendar.component(.month, from: monthStart)
        let displayedYear = calendar.component(.year, from: monthStart)
        let todayID = id(for: Date())

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return WidgetMonthCellModel(
                id: id(for: date),
                date: date,
                day: components.day ?? 0,
                isInDisplayedMonth: components.year == displayedYear && components.month == displayedMonth,
                isToday: id(for: date) == todayID,
                isFuture: calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
            )
        }
    }
}
