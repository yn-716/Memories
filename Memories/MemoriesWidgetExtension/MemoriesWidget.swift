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
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
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

            Text(snapshot.todayEntry?.caption.isEmpty == false ? snapshot.todayEntry?.caption ?? "" : "Today")
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
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
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
        if let caption = snapshot.todayEntry?.caption, !caption.isEmpty {
            return "Pet Calendar: \(caption)"
        }
        return snapshot.todayEntry == nil ? "Pet Calendar: add today" : "Pet Calendar: today"
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
            Text("Pet Calendar")
                .font(.caption.weight(.semibold))
            Text(snapshot.todayEntry == nil ? "Add today's photo" : "Today's memory is saved")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let caption = snapshot.todayEntry?.caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
        }
    }
}

private struct WidgetPawShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let toe = side * 0.22
        let toeCenters = [
            CGPoint(x: center.x - side * 0.25, y: rect.minY + side * 0.26),
            CGPoint(x: center.x, y: rect.minY + side * 0.16),
            CGPoint(x: center.x + side * 0.25, y: rect.minY + side * 0.26),
            CGPoint(x: center.x, y: rect.minY + side * 0.38)
        ]
        for point in toeCenters {
            path.addEllipse(in: CGRect(x: point.x - toe / 2, y: point.y - toe / 2, width: toe, height: toe))
        }
        path.addEllipse(in: CGRect(
            x: center.x - side * 0.25,
            y: center.y - side * 0.05,
            width: side * 0.5,
            height: side * 0.42
        ))
        return path
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
}

struct WidgetPetCalendarEntry: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var thumbnailFileName: String
    var caption: String
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

private enum WidgetCalendarDateRules {
    static let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        return calendar
    }

    static func id(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
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
