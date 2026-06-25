import Foundation
import UIKit

enum PetCalendarRepositoryError: LocalizedError, Equatable {
    case appGroupContainerUnavailable
    case imageMissing
    case imageWriteFailed
    case futureDateNotAllowed
    case replacementRequiresConfirmation

    var errorDescription: String? {
        switch self {
        case .appGroupContainerUnavailable:
            return "カレンダー保存先を準備できませんでした。"
        case .imageMissing:
            return "写真を読み込めませんでした。"
        case .imageWriteFailed:
            return "カレンダー画像を保存できませんでした。"
        case .futureDateNotAllowed:
            return "未来の日付には登録できません。"
        case .replacementRequiresConfirmation:
            return "既存の写真を置き換えるには確認が必要です。"
        }
    }
}

struct PetCalendarRepository {
    private let rootURL: URL
    private let fileManager: FileManager
    private let calendar: Calendar

    init(
        rootURL: URL? = nil,
        fileManager: FileManager = .default,
        calendar: Calendar = PetCalendarDateRules.gregorianCalendar()
    ) throws {
        self.fileManager = fileManager
        self.calendar = calendar

        if let rootURL {
            self.rootURL = rootURL
        } else if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: PetCalendarConstants.appGroupIdentifier
        ) {
            self.rootURL = appGroupURL
        } else {
            throw PetCalendarRepositoryError.appGroupContainerUnavailable
        }
    }

    func loadEntries() -> [PetCalendarDayEntry] {
        guard let data = try? Data(contentsOf: indexURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = (try? decoder.decode([PetCalendarDayEntry].self, from: data)) ?? []
        return entries.sorted { $0.date < $1.date }
    }

    func entry(for date: Date) -> PetCalendarDayEntry? {
        let targetID = PetCalendarDateRules.id(for: date, calendar: calendar)
        return loadEntries().first { $0.id == targetID }
    }

    func save(
        image: UIImage?,
        caption: String = "",
        photoPlacement: PhotoPlacement = .default,
        overlayStyle: PetCalendarOverlayStyle = .default,
        for date: Date,
        allowReplace: Bool = false,
        now: Date = Date()
    ) throws -> PetCalendarDayEntry {
        guard PetCalendarDateRules.canRegisterPhoto(for: date, now: now, calendar: calendar) else {
            throw PetCalendarRepositoryError.futureDateNotAllowed
        }
        guard image != nil || overlayStyle.effectiveWeatherIcon != nil else {
            throw PetCalendarRepositoryError.imageMissing
        }
        _ = caption

        try ensureDirectories()

        var entries = loadEntries()
        let dateID = PetCalendarDateRules.id(for: date, calendar: calendar)
        let existing = entries.first { $0.id == dateID }
        if existing != nil && !allowReplace {
            throw PetCalendarRepositoryError.replacementRequiresConfirmation
        }

        let nowDate = now
        let imageFileName: String?
        let thumbnailFileName: String?
        if let image {
            let generatedImageFileName = "\(dateID)-\(UUID().uuidString)-image.jpg"
            let generatedThumbnailFileName = "\(dateID)-\(UUID().uuidString)-thumb.jpg"
            try writeImage(
                image,
                maxLongSide: PetCalendarConstants.displayImageMaxLongSide,
                quality: PetCalendarConstants.displayImageJPEGQuality,
                to: imagesDirectory.appendingPathComponent(generatedImageFileName)
            )
            try writeImage(
                image,
                maxLongSide: PetCalendarConstants.thumbnailMaxLongSide,
                quality: PetCalendarConstants.thumbnailJPEGQuality,
                to: thumbnailsDirectory.appendingPathComponent(generatedThumbnailFileName)
            )
            imageFileName = generatedImageFileName
            thumbnailFileName = generatedThumbnailFileName
        } else {
            imageFileName = nil
            thumbnailFileName = nil
        }

        if let existing {
            removeStoredImages(for: existing)
        }

        let entry = PetCalendarDayEntry(
            id: dateID,
            date: PetCalendarDateRules.startOfDay(for: date, calendar: calendar),
            imageFileName: imageFileName,
            thumbnailFileName: thumbnailFileName,
            caption: "",
            photoPlacement: photoPlacement.clamped,
            overlayStyle: overlayStyle,
            createdAt: existing?.createdAt ?? nowDate,
            updatedAt: nowDate
        )

        entries.removeAll { $0.id == dateID }
        entries.append(entry)
        entries.sort { $0.date < $1.date }
        try writeIndex(entries)
        try writeWidgetSnapshot(entries: entries)

        return entry
    }

    func deleteEntry(for date: Date) throws {
        let dateID = PetCalendarDateRules.id(for: date, calendar: calendar)
        var entries = loadEntries()
        guard let entry = entries.first(where: { $0.id == dateID }) else {
            return
        }

        entries.removeAll { $0.id == dateID }
        try writeIndex(entries)
        removeStoredImages(for: entry)
        try writeWidgetSnapshot(entries: entries)
    }

    func image(for entry: PetCalendarDayEntry) -> UIImage? {
        guard let imageFileName = entry.imageFileName else {
            return nil
        }
        return UIImage(contentsOfFile: imagesDirectory.appendingPathComponent(imageFileName).path)
    }

    func thumbnail(for entry: PetCalendarDayEntry) -> UIImage? {
        guard let thumbnailFileName = entry.thumbnailFileName else {
            return nil
        }
        return UIImage(contentsOfFile: thumbnailsDirectory.appendingPathComponent(thumbnailFileName).path)
    }

    func thumbnailURL(for entry: PetCalendarDayEntry) -> URL? {
        guard let thumbnailFileName = entry.thumbnailFileName else {
            return nil
        }
        return thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
    }

    func storageSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: calendarDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL else {
                return nil
            }
            return (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        }.reduce(0, +)
    }

    func writeWidgetSnapshot(
        entries: [PetCalendarDayEntry]? = nil,
        selectedMonth: Date = Date(),
        displayLanguage: PetCalendarDisplayLanguage = .japanese,
        showsBranding: Bool = true
    ) throws {
        try ensureDirectories()
        let snapshot = PetCalendarWidgetSnapshot(
            updatedAt: Date(),
            selectedMonth: PetCalendarDateRules.monthStart(for: selectedMonth, calendar: calendar),
            displayLanguage: displayLanguage,
            showsBranding: showsBranding,
            entries: (entries ?? loadEntries()).map { entry in
                PetCalendarWidgetEntry(
                    id: entry.id,
                    date: entry.date,
                    thumbnailFileName: entry.thumbnailFileName,
                    caption: entry.caption,
                    photoPlacement: entry.photoPlacement,
                    overlayStyle: entry.overlayStyle
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: widgetSnapshotURL, options: widgetReadableWriteOptions)
        protectItemIfPossible(at: widgetSnapshotURL)
    }

    var widgetDirectoryURL: URL {
        widgetDirectory
    }

    private func writeIndex(_ entries: [PetCalendarDayEntry]) throws {
        try ensureDirectories()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try data.write(to: indexURL, options: widgetReadableWriteOptions)
        protectItemIfPossible(at: indexURL)
    }

    private func removeStoredImages(for entry: PetCalendarDayEntry) {
        if let imageFileName = entry.imageFileName {
            try? fileManager.removeItem(at: imagesDirectory.appendingPathComponent(imageFileName))
        }
        if let thumbnailFileName = entry.thumbnailFileName {
            try? fileManager.removeItem(at: thumbnailsDirectory.appendingPathComponent(thumbnailFileName))
        }
    }

    private func writeImage(_ image: UIImage, maxLongSide: CGFloat, quality: CGFloat, to url: URL) throws {
        let resized = image.resizedForPetCalendar(maxLongSide: maxLongSide)
        guard let data = resized.jpegData(compressionQuality: quality) else {
            throw PetCalendarRepositoryError.imageWriteFailed
        }

        try data.write(to: url, options: widgetReadableWriteOptions)
        protectItemIfPossible(at: url)
    }

    private func ensureDirectories() throws {
        try createProtectedDirectory(at: calendarDirectory)
        try createProtectedDirectory(at: imagesDirectory)
        try createProtectedDirectory(at: thumbnailsDirectory)
        try createProtectedDirectory(at: widgetDirectory)
        protectExistingItemsIfPossible(in: imagesDirectory)
        protectExistingItemsIfPossible(in: thumbnailsDirectory)
        protectExistingItemsIfPossible(in: widgetDirectory)
    }

    private func createProtectedDirectory(at url: URL) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: protectedFileAttributes
        )
        protectItemIfPossible(at: url)
    }

    private func protectExistingItemsIfPossible(in directory: URL) {
        guard let urls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        urls.forEach { protectItemIfPossible(at: $0) }
    }

    private func protectItemIfPossible(at url: URL) {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try? fileManager.setAttributes(protectedFileAttributes, ofItemAtPath: url.path)
    }

    private var calendarDirectory: URL {
        rootURL.appendingPathComponent("PetCalendar", isDirectory: true)
    }

    private var imagesDirectory: URL {
        calendarDirectory.appendingPathComponent("Images", isDirectory: true)
    }

    private var thumbnailsDirectory: URL {
        calendarDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    private var widgetDirectory: URL {
        calendarDirectory.appendingPathComponent("Widget", isDirectory: true)
    }

    private var indexURL: URL {
        calendarDirectory.appendingPathComponent("index.json")
    }

    private var widgetSnapshotURL: URL {
        widgetDirectory.appendingPathComponent(PetCalendarWidgetSnapshot.fileName)
    }

    private var widgetReadableWriteOptions: Data.WritingOptions {
        [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
    }

    private var protectedFileAttributes: [FileAttributeKey: Any] {
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
    }
}

struct PetCalendarWidgetSnapshot: Codable, Hashable {
    static let fileName = "pet-calendar-widget-snapshot.json"

    var updatedAt: Date
    var selectedMonth: Date
    var displayLanguage: PetCalendarDisplayLanguage
    var showsBranding: Bool
    var entries: [PetCalendarWidgetEntry]

    init(
        updatedAt: Date,
        selectedMonth: Date,
        displayLanguage: PetCalendarDisplayLanguage = .japanese,
        showsBranding: Bool = true,
        entries: [PetCalendarWidgetEntry]
    ) {
        self.updatedAt = updatedAt
        self.selectedMonth = selectedMonth
        self.displayLanguage = displayLanguage
        self.showsBranding = showsBranding
        self.entries = entries
    }

    private enum CodingKeys: String, CodingKey {
        case updatedAt
        case selectedMonth
        case displayLanguage
        case showsBranding
        case entries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        selectedMonth = try container.decode(Date.self, forKey: .selectedMonth)
        displayLanguage = try container.decodeIfPresent(PetCalendarDisplayLanguage.self, forKey: .displayLanguage) ?? .japanese
        showsBranding = try container.decodeIfPresent(Bool.self, forKey: .showsBranding) ?? true
        entries = try container.decode([PetCalendarWidgetEntry].self, forKey: .entries)
    }
}

struct PetCalendarWidgetEntry: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var thumbnailFileName: String?
    var caption: String
    var photoPlacement: PhotoPlacement
    var overlayStyle: PetCalendarOverlayStyle

    init(
        id: String,
        date: Date,
        thumbnailFileName: String?,
        caption: String = "",
        photoPlacement: PhotoPlacement = .default,
        overlayStyle: PetCalendarOverlayStyle = .default
    ) {
        self.id = id
        self.date = date
        self.thumbnailFileName = thumbnailFileName
        self.caption = caption
        self.photoPlacement = photoPlacement.clamped
        self.overlayStyle = overlayStyle
    }

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
        photoPlacement = (try container.decodeIfPresent(PhotoPlacement.self, forKey: .photoPlacement) ?? .default).clamped
        overlayStyle = try container.decodeIfPresent(PetCalendarOverlayStyle.self, forKey: .overlayStyle) ?? .default
    }
}

private extension UIImage {
    func resizedForPetCalendar(maxLongSide: CGFloat) -> UIImage {
        guard size.width > 0, size.height > 0 else {
            return self
        }

        let longSide = max(size.width, size.height)
        guard longSide > maxLongSide else {
            return self
        }

        let scale = maxLongSide / longSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
