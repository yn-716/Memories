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
            Text("Memories Pet Life")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.16))
                if let todayEntry = snapshot.todayEntry,
                   let image = WidgetPetCalendarSnapshotStore.thumbnail(for: todayEntry) {
                    WidgetPlacedImage(image: image, placement: todayEntry.photoPlacement)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        if WidgetCalendarDateRules.isJapaneseLocale {
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
                Text("Memories")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(WidgetCalendarDateRules.weekdays, id: \.self) { weekday in
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
                Text("\(cell.day)")
                    .font(.system(size: isLarge ? 11 : 8, weight: .bold))
                    .foregroundStyle(entry == nil ? Color.primary : Color.white)
                    .padding(2)
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
        if WidgetCalendarDateRules.isJapaneseLocale {
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
        VStack(alignment: .leading, spacing: 3) {
            Text(WidgetCalendarDateRules.isJapaneseLocale ? "今週" : "This Week")
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            HStack(spacing: 3) {
                ForEach(0..<weekDays.count, id: \.self) { index in
                    weekDayColumn(weekDays[index])
                }
            }
        }
    }

    private var weekDays: [WidgetWeekDayModel] {
        WidgetCalendarDateRules.week(containing: Date(), registeredEntryIDs: snapshot.entryIDs)
    }

    private func weekDayColumn(_ day: WidgetWeekDayModel) -> some View {
        VStack(spacing: 1) {
            Text(day.weekdaySymbol)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(day.day)")
                .font(.system(size: 10, weight: day.isToday ? .bold : .semibold))
                .foregroundStyle(day.isFuture ? Color.secondary.opacity(0.55) : Color.primary)
            statusMark(day)
        }
        .frame(maxWidth: .infinity)
        .opacity(day.isFuture ? 0.48 : 1)
        .padding(.vertical, 1)
        .background(day.isToday ? Color.accentColor.opacity(0.20) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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
    var entries: [WidgetPetCalendarEntry]

    static let placeholder = WidgetPetCalendarSnapshot(
        updatedAt: Date(),
        selectedMonth: Date(),
        entries: []
    )

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

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case thumbnailFileName
        case caption
        case photoPlacement
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        thumbnailFileName = try container.decode(String.self, forKey: .thumbnailFileName)
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        photoPlacement = (try container.decodeIfPresent(WidgetPhotoPlacement.self, forKey: .photoPlacement) ?? .default).clamped
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
    static let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        return calendar
    }

    static var isJapaneseLocale: Bool {
        Locale.current.language.languageCode?.identifier == "ja"
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

    static func week(containing date: Date, now: Date = Date(), registeredEntryIDs: Set<String>) -> [WidgetWeekDayModel] {
        let start = startOfWeek(containing: date)
        let todayID = id(for: now)
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            let dayID = id(for: day)
            return WidgetWeekDayModel(
                id: dayID,
                date: day,
                day: calendar.component(.day, from: day),
                weekdaySymbol: weekdays[offset],
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
