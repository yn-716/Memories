import SwiftUI
import UIKit
import WidgetKit

private let appGroupIdentifier = "group.com.myfs716.Memories"
private let snapshotFileName = "widget-snapshot.json"

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
    var renderedImageSets: [WidgetPetCalendarRenderedImageSet]

    static let placeholder = WidgetPetCalendarSnapshot(
        updatedAt: Date(),
        selectedMonth: Date(),
        displayLanguage: .japanese,
        showsBranding: true,
        renderedImageSets: []
    )

    private enum CodingKeys: String, CodingKey {
        case updatedAt
        case selectedMonth
        case displayLanguage
        case showsBranding
        case renderedImageSets
    }

    init(
        updatedAt: Date,
        selectedMonth: Date,
        displayLanguage: WidgetPetCalendarDisplayLanguage = .japanese,
        showsBranding: Bool = true,
        renderedImageSets: [WidgetPetCalendarRenderedImageSet] = []
    ) {
        self.updatedAt = updatedAt
        self.selectedMonth = selectedMonth
        self.displayLanguage = displayLanguage
        self.showsBranding = showsBranding
        self.renderedImageSets = renderedImageSets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        selectedMonth = try container.decode(Date.self, forKey: .selectedMonth)
        displayLanguage = try container.decodeIfPresent(WidgetPetCalendarDisplayLanguage.self, forKey: .displayLanguage) ?? .japanese
        showsBranding = try container.decodeIfPresent(Bool.self, forKey: .showsBranding) ?? true
        renderedImageSets = try container.decodeIfPresent([WidgetPetCalendarRenderedImageSet].self, forKey: .renderedImageSets) ?? []
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

enum WidgetPetCalendarDisplayLanguage: String, Codable, Hashable {
    case japanese
    case english
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

        guard let fileName else {
            return nil
        }
        return UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path)
    }

    private static var sharedDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("PetCalendarWidget", isDirectory: true)
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
