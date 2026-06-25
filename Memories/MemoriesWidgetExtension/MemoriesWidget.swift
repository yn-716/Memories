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
            .containerBackground(for: .widget) {
                WidgetAquaBackground()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            TodayWidgetView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "memories://calendar/today"))
        case .systemMedium:
            WeekWidgetView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "memories://calendar"))
        case .systemLarge:
            MonthWidgetView(snapshot: entry.snapshot, isLarge: true)
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

private struct WidgetWatermark: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    var compact = false

    var body: some View {
        let iconSide: CGFloat = compact ? 11 : 14
        let label = "Memories Pet Life"
        let materialTint = widgetRenderingMode == .vibrant ? 0.06 : 0.14

        HStack(spacing: compact ? 3 : 5) {
            Image("watermark_app_icon")
                .resizable()
                .scaledToFill()
                .frame(width: iconSide, height: iconSide)
                .clipShape(RoundedRectangle(cornerRadius: iconSide * 0.18, style: .continuous))
                .opacity(widgetRenderingMode == .vibrant ? 0.92 : 0.82)

            Text(label)
                .font(.system(size: compact ? 7 : 9, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .allowsTightening(true)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(Color.primary.opacity(widgetRenderingMode == .vibrant ? 0.92 : 0.70))
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 3 : 4)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(materialTint))
                }
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(widgetRenderingMode == .vibrant ? 0.28 : 0.32), lineWidth: 0.6)
        }
        .widgetAccentable(false)
    }
}

private struct TodayWidgetView: View {
    let snapshot: WidgetPetCalendarSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(WidgetCalendarDateRules.dateTitle(for: Date(), language: snapshot.displayLanguage))
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Text(WidgetCalendarDateRules.weekdayTitle(for: Date(), language: snapshot.displayLanguage))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if snapshot.showsBranding {
                    WidgetWatermark(compact: true)
                }
            }

            Spacer(minLength: 0)

            ZStack {
                WidgetAquaSurface(cornerRadius: 12)
                if let todayEntry = snapshot.todayEntry,
                   let image = WidgetPetCalendarSnapshotStore.thumbnail(for: todayEntry) {
                    WidgetPlacedImage(image: image, placement: todayEntry.photoPlacement)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if snapshot.todayEntry?.overlayStyle.effectiveWeatherIcon == nil {
                    WidgetPawShape()
                        .fill(Color.secondary.opacity(0.22))
                        .frame(width: 44, height: 44)
                }

                if let todayEntry = snapshot.todayEntry {
                    WidgetWeatherIconLayer(
                        style: todayEntry.overlayStyle,
                        usesPhotoBackground: WidgetPetCalendarSnapshotStore.thumbnail(for: todayEntry) != nil
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 98)
            .clipped()
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(snapshot.todayEntry == nil ? Color.clear : WidgetCalendarColors.registeredFrame, lineWidth: 1.6)
            }
        }
    }
}

private struct MonthWidgetView: View {
    let snapshot: WidgetPetCalendarSnapshot
    let isLarge: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    var body: some View {
        let cells = WidgetCalendarDateRules.monthGrid(for: snapshot.selectedMonth)
        let rowCount = max(1, cells.count / 7)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(monthTitle)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                Spacer()
                if snapshot.showsBranding {
                    WidgetWatermark()
                }
            }

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(Array(WidgetCalendarDateRules.weekdays(language: snapshot.displayLanguage).enumerated()), id: \.offset) { _, weekday in
                    Text(weekday)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(cells, id: \.id) { cell in
                    WidgetMonthCell(cell: cell, entry: snapshot.entryByID[cell.id], isLarge: isLarge, rowCount: rowCount)
                }
            }
        }
    }

    private var monthTitle: String {
        WidgetCalendarDateRules.monthTitle(for: snapshot.selectedMonth, language: snapshot.displayLanguage)
    }
}

private struct WeekWidgetView: View {
    let snapshot: WidgetPetCalendarSnapshot

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(WidgetCalendarDateRules.weekTitle(for: Date(), language: snapshot.displayLanguage))
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if snapshot.showsBranding {
                    WidgetWatermark(compact: true)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                    WidgetWeekDayCard(day: day, entry: snapshot.entryByID[day.id], index: index)
                }
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
}

private struct WidgetWeekDayCard: View {
    let day: WidgetWeekDayModel
    let entry: WidgetPetCalendarEntry?
    let index: Int

    var body: some View {
        let hasPhoto = entry.flatMap { WidgetPetCalendarSnapshotStore.thumbnail(for: $0) } != nil
        let hasWeatherIcon = entry?.overlayStyle.effectiveWeatherIcon != nil

        VStack(spacing: 3) {
            Text(day.weekdaySymbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(height: 10)

            ZStack(alignment: .topLeading) {
                WidgetAquaSurface(cornerRadius: 6, isDimmed: day.isFuture)
                    .overlay {
                        if let entry, let image = WidgetPetCalendarSnapshotStore.thumbnail(for: entry) {
                            WidgetPlacedImage(image: image, placement: entry.photoPlacement)
                        } else if !hasWeatherIcon {
                            WidgetPawShape()
                                .fill(Color.secondary.opacity(day.isFuture ? 0.10 : 0.18))
                                .padding(8)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(entry == nil ? Color.clear : WidgetCalendarColors.registeredFrame, lineWidth: 1.4)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(day.isToday ? Color.accentColor : Color.clear, lineWidth: 1.6)
                    }

                if let entry {
                    WidgetWeatherIconLayer(style: entry.overlayStyle, usesPhotoBackground: hasPhoto)
                }

                Text("\(day.day)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(hasPhoto ? Color.white : Color.primary)
                    .shadow(color: hasPhoto ? Color.black.opacity(0.35) : .clear, radius: 1, y: 1)
                    .padding(3)
            }
            .aspectRatio(0.78, contentMode: .fit)
            .opacity(day.isFuture ? 0.48 : 1)
        }
    }
}

private struct WidgetMonthCell: View {
    let cell: WidgetMonthCellModel
    let entry: WidgetPetCalendarEntry?
    let isLarge: Bool
    let rowCount: Int

    var body: some View {
        let hasPhoto = entry.flatMap { WidgetPetCalendarSnapshotStore.thumbnail(for: $0) } != nil
        let hasWeatherIcon = entry?.overlayStyle.effectiveWeatherIcon != nil

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.clear)
                .background {
                    if cell.isInDisplayedMonth {
                        WidgetAquaSurface(cornerRadius: 5, isDimmed: cell.isFuture)
                    }
                }
                .overlay {
                    if let entry, let image = WidgetPetCalendarSnapshotStore.thumbnail(for: entry) {
                        WidgetPlacedImage(image: image, placement: entry.photoPlacement)
                    } else if cell.isInDisplayedMonth, !hasWeatherIcon {
                        WidgetPawShape()
                            .fill(Color.secondary.opacity(0.16))
                            .padding(isLarge ? 7 : 4)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(entry == nil ? Color.clear : WidgetCalendarColors.registeredFrame, lineWidth: 1.2)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(cell.isToday ? Color.accentColor : Color.clear, lineWidth: 1.5)
                }

            if let entry {
                WidgetWeatherIconLayer(style: entry.overlayStyle, usesPhotoBackground: hasPhoto)
            }

            if cell.isInDisplayedMonth {
                Text("\(cell.day)")
                    .font(.system(size: isLarge ? 11 : 8, weight: .bold))
                    .foregroundStyle(hasPhoto ? Color.white : Color.primary)
                    .shadow(color: hasPhoto ? Color.black.opacity(0.32) : .clear, radius: 1, y: 1)
                    .padding(2)
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .opacity(cell.isFuture ? 0.42 : 1)
    }

    private var aspectRatio: CGFloat {
        if !isLarge {
            return rowCount <= 5 ? 0.86 : 1.0
        }
        return rowCount <= 4 ? 0.68 : (rowCount == 5 ? 0.78 : 1.0)
    }
}

private struct WidgetWeatherIconLayer: View {
    let style: WidgetPetCalendarOverlayStyle
    let usesPhotoBackground: Bool

    var body: some View {
        GeometryReader { proxy in
            if let icon = style.effectiveWeatherIcon {
                let minSide = min(proxy.size.width, proxy.size.height)
                let iconSide = max(minSide * 0.32, 12)
                let inset = max(minSide * 0.10, 3)
                let center = centerPoint(
                    for: style.weatherIconCorner,
                    size: proxy.size,
                    iconSide: iconSide,
                    inset: inset
                )

                Image(systemName: icon.symbolName)
                    .font(.system(size: iconSide * 0.74, weight: .bold, design: .rounded))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(style.accentColor.color)
                    .shadow(color: usesPhotoBackground ? Color.black.opacity(0.34) : Color.white.opacity(0.78), radius: 1.6, y: 0.8)
                    .frame(width: iconSide, height: iconSide)
                    .position(center)
            }
        }
        .allowsHitTesting(false)
        .widgetAccentable(false)
    }

    private func centerPoint(for corner: WidgetPetCalendarOverlayCorner, size: CGSize, iconSide: CGFloat, inset: CGFloat) -> CGPoint {
        let x: CGFloat
        let y: CGFloat

        switch corner {
        case .topLeft, .bottomLeft:
            x = inset + iconSide / 2
        case .topRight, .bottomRight:
            x = size.width - inset - iconSide / 2
        }

        switch corner {
        case .topLeft, .topRight:
            y = inset + iconSide / 2
        case .bottomLeft, .bottomRight:
            y = size.height - inset - iconSide / 2
        }

        return CGPoint(x: x, y: y)
    }
}

private struct AccessoryInlineWidgetView: View {
    let snapshot: WidgetPetCalendarSnapshot

    var body: some View {
        Text(accessoryText)
    }

    private var accessoryText: String {
        if snapshot.displayLanguage == .japanese {
            return "\(WidgetCalendarDateRules.compactDateTitle(for: Date(), language: snapshot.displayLanguage)) 今日"
        }
        return "\(WidgetCalendarDateRules.compactDateTitle(for: Date(), language: snapshot.displayLanguage)) Today"
    }
}

private struct AccessoryCircularWidgetView: View {
    let snapshot: WidgetPetCalendarSnapshot

    var body: some View {
        ZStack {
            if let featuredEntry, let image = WidgetPetCalendarSnapshotStore.thumbnail(for: featuredEntry) {
                WidgetPlacedImage(image: image, placement: featuredEntry.photoPlacement)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(WidgetCalendarColors.registeredFrame.opacity(0.92), lineWidth: 1.3)
                    }
            } else {
                AccessoryWidgetBackground()
                WidgetPawShape()
                    .fill(Color.secondary.opacity(0.48))
                    .padding(12)
            }

            VStack(spacing: 0) {
                Text(WidgetCalendarDateRules.shortMonthTitle(for: Date(), language: snapshot.displayLanguage))
                    .font(.system(size: 8, weight: .semibold))
                    .lineLimit(1)
                Text("\(WidgetCalendarDateRules.calendar.component(.day, from: Date()))")
                    .font(.headline.weight(.bold))
                Text(WidgetCalendarDateRules.weekdayTitle(for: Date(), language: snapshot.displayLanguage))
                    .font(.system(size: 7, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(featuredEntry == nil ? Color.primary : Color.white)
            .shadow(color: featuredEntry == nil ? .clear : Color.black.opacity(0.34), radius: 1, y: 1)
        }
    }

    private var featuredEntry: WidgetPetCalendarEntry? {
        snapshot.featuredEntry
    }
}

private struct AccessoryRectangularWidgetView: View {
    let snapshot: WidgetPetCalendarSnapshot

    var body: some View {
        HStack(spacing: 5) {
            featuredPhoto
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(WidgetCalendarDateRules.compactWeekTitle(for: Date(), language: snapshot.displayLanguage))
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    if snapshot.showsBranding {
                        WidgetWatermark(compact: true)
                    }
                }

                weekRow { day in
                    Text(day.weekdaySymbol)
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                weekRow { day in
                    Text("\(day.day)")
                        .font(.system(size: 9, weight: day.isToday ? .bold : .semibold))
                        .foregroundStyle(day.isFuture ? Color.secondary.opacity(0.55) : Color.primary)
                }
                weekRow { day in
                    statusMark(day)
                }
            }
        }
    }

    @ViewBuilder
    private var featuredPhoto: some View {
        if let featuredEntry, let image = WidgetPetCalendarSnapshotStore.thumbnail(for: featuredEntry) {
            WidgetPlacedImage(image: image, placement: featuredEntry.photoPlacement)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(WidgetCalendarColors.registeredFrame.opacity(0.92), lineWidth: 1.2)
                }
        } else {
            ZStack {
                WidgetAquaSurface(cornerRadius: 6)
                WidgetPawShape()
                    .fill(Color.secondary.opacity(0.36))
                    .padding(9)
            }
        }
    }

    private func weekRow<Content: View>(@ViewBuilder content: @escaping (WidgetWeekDayModel) -> Content) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                content(day)
                    .frame(maxWidth: .infinity)
                    .frame(height: 9)
                    .opacity(day.isFuture ? 0.48 : 1)
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

    private var featuredEntry: WidgetPetCalendarEntry? {
        snapshot.featuredEntry
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

private enum WidgetCalendarColors {
    static let registeredFrame = Color(red: 0.56, green: 0.78, blue: 0.93)
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
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

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
            fullColorImage(drawRect: drawRect)
        }
        .clipped()
        .widgetAccentable(false)
    }

    @ViewBuilder
    private func fullColorImage(drawRect: CGRect) -> some View {
        if widgetRenderingMode == .vibrant {
            Image(uiImage: image)
                .resizable()
                .frame(width: drawRect.width, height: drawRect.height)
                .position(x: drawRect.midX, y: drawRect.midY)
                .brightness(-0.32)
                .contrast(2.10)
                .saturation(1.25)
                .drawingGroup(opaque: false, colorMode: .linear)
        } else if #available(iOS 18.0, *) {
            Image(uiImage: image)
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
                .frame(width: drawRect.width, height: drawRect.height)
                .position(x: drawRect.midX, y: drawRect.midY)
        } else {
            Image(uiImage: image)
                .resizable()
                .frame(width: drawRect.width, height: drawRect.height)
                .position(x: drawRect.midX, y: drawRect.midY)
        }
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

    var featuredEntry: WidgetPetCalendarEntry? {
        let today = WidgetCalendarDateRules.calendar.startOfDay(for: Date())
        return entries
            .filter { WidgetCalendarDateRules.calendar.startOfDay(for: $0.date) <= today }
            .max { $0.date < $1.date }
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
    var thumbnailFileName: String?
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
        var snapshot = loadSnapshot()
        if let entries = loadIndexEntries() {
            snapshot.entries = entries
        }
        return snapshot
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

    private static func loadIndexEntries() -> [WidgetPetCalendarEntry]? {
        guard
            let directory = calendarDirectory,
            let data = try? Data(contentsOf: directory.appendingPathComponent("index.json"))
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WidgetPetCalendarEntry].self, from: data))?.sorted { $0.date < $1.date }
    }

    static func thumbnail(for entry: WidgetPetCalendarEntry) -> UIImage? {
        guard
            let directory = calendarDirectory,
            let thumbnailFileName = entry.thumbnailFileName
        else {
            return nil
        }
        let thumbnailURL = directory
            .appendingPathComponent("Thumbnails", isDirectory: true)
            .appendingPathComponent(thumbnailFileName)
        return UIImage(contentsOfFile: thumbnailURL.path)
    }

    private static var sharedDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("PetCalendar/Widget", isDirectory: true)
    }

    private static var calendarDirectory: URL? {
        sharedDirectory?.deletingLastPathComponent()
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

    static func dateTitle(for date: Date, language: WidgetPetCalendarDisplayLanguage) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        let month = components.month ?? 0
        let day = components.day ?? 0
        switch language {
        case .japanese:
            return "\(month)月\(day)日"
        case .english:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    static func compactDateTitle(for date: Date, language: WidgetPetCalendarDisplayLanguage) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        let month = components.month ?? 0
        let day = components.day ?? 0
        switch language {
        case .japanese:
            return "\(month)/\(day)"
        case .english:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }

    static func weekdayTitle(for date: Date, language: WidgetPetCalendarDisplayLanguage) -> String {
        let weekday = max(1, min(7, calendar.component(.weekday, from: date)))
        switch language {
        case .japanese:
            return ["日", "月", "火", "水", "木", "金", "土"][weekday - 1]
        case .english:
            return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][weekday - 1]
        }
    }

    static func shortMonthTitle(for date: Date, language: WidgetPetCalendarDisplayLanguage) -> String {
        let month = calendar.component(.month, from: date)
        switch language {
        case .japanese:
            return "\(month)月"
        case .english:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }
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

    static func weekTitle(for date: Date, language: WidgetPetCalendarDisplayLanguage) -> String {
        switch language {
        case .japanese:
            return "\(monthTitle(for: date, language: language)) 今週"
        case .english:
            return "\(monthTitle(for: date, language: language)) Week"
        }
    }

    static func compactWeekTitle(for date: Date, language: WidgetPetCalendarDisplayLanguage) -> String {
        switch language {
        case .japanese:
            return "\(shortMonthTitle(for: date, language: language)) 今週"
        case .english:
            return "\(shortMonthTitle(for: date, language: language)) Week"
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
        let monthInterval = calendar.dateInterval(of: .month, for: monthStart)
        let lastMonthDate = monthInterval
            .flatMap { calendar.date(byAdding: .day, value: -1, to: $0.end) }
            ?? monthStart
        let trailingDays = (calendar.firstWeekday + 6 - calendar.component(.weekday, from: lastMonthDate) + 7) % 7
        let gridEnd = calendar.date(byAdding: .day, value: trailingDays + 1, to: lastMonthDate) ?? lastMonthDate
        let dayCount = max(28, calendar.dateComponents([.day], from: gridStart, to: gridEnd).day ?? 42)
        let displayedMonth = calendar.component(.month, from: monthStart)
        let displayedYear = calendar.component(.year, from: monthStart)
        let todayID = id(for: Date())

        return (0..<dayCount).compactMap { offset in
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
