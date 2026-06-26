import Foundation
import UIKit

enum PetCalendarRepositoryError: LocalizedError, Equatable {
    case appGroupContainerUnavailable
    case imageMissing
    case imageWriteFailed
    case futureDateNotAllowed
    case replacementRequiresConfirmation
    case appSupportDirectoryUnavailable

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
        case .appSupportDirectoryUnavailable:
            return "カレンダー保存先を準備できませんでした。"
        }
    }
}

struct PetCalendarRepository {
    static let appDataFileProtection: FileProtectionType = .complete
    static let widgetDataFileProtection: FileProtectionType = .completeUntilFirstUserAuthentication

    private let appRootURL: URL
    private let widgetRootURL: URL
    private let legacyAppGroupRootURL: URL?
    private let fileManager: FileManager
    private let calendar: Calendar

    init(
        rootURL: URL? = nil,
        appRootURL: URL? = nil,
        widgetRootURL: URL? = nil,
        legacyAppGroupRootURL: URL? = nil,
        fileManager: FileManager = .default,
        calendar: Calendar = PetCalendarDateRules.gregorianCalendar()
    ) throws {
        self.fileManager = fileManager
        self.calendar = calendar

        if let rootURL {
            self.appRootURL = rootURL
            self.widgetRootURL = rootURL
        } else {
            if let appRootURL {
                self.appRootURL = appRootURL
            } else if let defaultAppRootURL = Self.defaultAppRootURL(fileManager: fileManager) {
                self.appRootURL = defaultAppRootURL
            } else {
                throw PetCalendarRepositoryError.appSupportDirectoryUnavailable
            }

            if let widgetRootURL {
                self.widgetRootURL = widgetRootURL
            } else if let appGroupURL = fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: PetCalendarConstants.appGroupIdentifier
            ) {
                self.widgetRootURL = appGroupURL
            } else {
                throw PetCalendarRepositoryError.appGroupContainerUnavailable
            }
        }

        if let legacyAppGroupRootURL {
            self.legacyAppGroupRootURL = legacyAppGroupRootURL
        } else {
            self.legacyAppGroupRootURL = fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: PetCalendarConstants.appGroupIdentifier
            )
        }

        migrateLegacyAppGroupDataIfNeeded()
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
        now: Date = Date(),
        updatesWidgetSnapshot: Bool = true,
        widgetSelectedMonth: Date? = nil,
        widgetDisplayLanguage: PetCalendarDisplayLanguage = .japanese,
        widgetShowsBranding: Bool = true
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
        if updatesWidgetSnapshot {
            try writeWidgetSnapshot(
                entries: entries,
                selectedMonth: widgetSelectedMonth ?? date,
                displayLanguage: widgetDisplayLanguage,
                showsBranding: widgetShowsBranding
            )
        }

        return entry
    }

    func deleteEntry(
        for date: Date,
        widgetSelectedMonth: Date? = nil,
        widgetDisplayLanguage: PetCalendarDisplayLanguage = .japanese,
        widgetShowsBranding: Bool = true
    ) throws {
        let dateID = PetCalendarDateRules.id(for: date, calendar: calendar)
        var entries = loadEntries()
        guard let entry = entries.first(where: { $0.id == dateID }) else {
            return
        }

        entries.removeAll { $0.id == dateID }
        try writeIndex(entries)
        removeStoredImages(for: entry)
        try writeWidgetSnapshot(
            entries: entries,
            selectedMonth: widgetSelectedMonth ?? date,
            displayLanguage: widgetDisplayLanguage,
            showsBranding: widgetShowsBranding
        )
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
        [calendarDirectory, widgetDirectory].reduce(Int64(0)) { total, directory in
            guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
                return total
            }

            return total + enumerator.compactMap { item in
                guard let url = item as? URL else {
                    return nil
                }
                return (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
            }.reduce(0, +)
        }
    }

    func writeWidgetSnapshot(
        entries: [PetCalendarDayEntry]? = nil,
        selectedMonth: Date = Date(),
        displayLanguage: PetCalendarDisplayLanguage = .japanese,
        showsBranding: Bool = true
    ) throws {
        try ensureDirectories()
        let currentEntries = entries ?? loadEntries()
        var snapshot = PetCalendarWidgetSnapshot(
            updatedAt: Date(),
            selectedMonth: PetCalendarDateRules.monthStart(for: selectedMonth, calendar: calendar),
            displayLanguage: displayLanguage,
            showsBranding: showsBranding
        )
        let renderedImageSets = try writeWidgetRenderedImageSets(snapshot: snapshot, entries: currentEntries)
        guard !renderedImageSets.isEmpty else {
            throw PetCalendarRepositoryError.imageWriteFailed
        }
        snapshot.renderedImageSets = renderedImageSets

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: widgetSnapshotURL, options: widgetReadableWriteOptions)
        protectItemIfPossible(at: widgetSnapshotURL, attributes: widgetReadableFileAttributes)
        removeObsoleteWidgetRenderedImages(keeping: Set(renderedImageSets.flatMap(\.fileNames)))
    }

    var widgetDirectoryURL: URL {
        widgetDirectory
    }

    var appCalendarDirectoryURL: URL {
        calendarDirectory
    }

    private func writeIndex(_ entries: [PetCalendarDayEntry]) throws {
        try ensureDirectories()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try data.write(to: indexURL, options: appProtectedWriteOptions)
        protectItemIfPossible(at: indexURL, attributes: appProtectedFileAttributes)
    }

    private func writeWidgetRenderedImageSets(
        snapshot: PetCalendarWidgetSnapshot,
        entries: [PetCalendarDayEntry]
    ) throws -> [PetCalendarWidgetRenderedImageSet] {
        let thumbnailsByID = Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
            thumbnail(for: entry).map { (entry.id, $0) }
        })
        let now = Date()
        let today = PetCalendarDateRules.startOfDay(for: now, calendar: calendar)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(86_400)
        let renderDates = [now, tomorrow]
        let renderer = PetCalendarWidgetRenderer()

        return try renderDates.map { renderDate in
            let dayID = PetCalendarDateRules.id(for: renderDate, calendar: calendar)
            let renderedImages = renderer.renderAll(
                snapshot: snapshot,
                entries: entries,
                thumbnailsByID: thumbnailsByID,
                now: renderDate
            )
            let versionID = "\(dayID)-\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString)"
            var renderedFileNames: [PetCalendarWidgetRenderedImageFamily: String] = [:]

            for renderedImage in renderedImages {
                guard let data = renderedImage.image.jpegData(compressionQuality: 0.84) else {
                    throw PetCalendarRepositoryError.imageWriteFailed
                }
                let fileName = renderedImage.family.fileName(versionID: versionID)
                let url = widgetDirectory.appendingPathComponent(fileName)
                try data.write(to: url, options: widgetReadableWriteOptions)
                protectItemIfPossible(at: url, attributes: widgetReadableFileAttributes)
                renderedFileNames[renderedImage.family] = fileName
            }

            return PetCalendarWidgetRenderedImageSet(
                dayID: dayID,
                imageNames: PetCalendarWidgetRenderedImageNames(
                    small: renderedFileNames[.small] ?? PetCalendarWidgetRenderedImageFamily.small.fileName(versionID: versionID),
                    medium: renderedFileNames[.medium] ?? PetCalendarWidgetRenderedImageFamily.medium.fileName(versionID: versionID),
                    large: renderedFileNames[.large] ?? PetCalendarWidgetRenderedImageFamily.large.fileName(versionID: versionID)
                )
            )
        }
    }

    private func removeObsoleteWidgetRenderedImages(keeping keptFileNames: Set<String>) {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: widgetDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for url in urls {
            let fileName = url.lastPathComponent
            guard
                fileName.hasPrefix("pet-calendar-widget-"),
                fileName.hasSuffix(".jpg"),
                !keptFileNames.contains(fileName)
            else {
                continue
            }
            try? fileManager.removeItem(at: url)
        }
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

        try data.write(to: url, options: appProtectedWriteOptions)
        protectItemIfPossible(at: url, attributes: appProtectedFileAttributes)
    }

    private func ensureDirectories() throws {
        try createProtectedDirectory(at: calendarDirectory, attributes: appProtectedFileAttributes)
        try createProtectedDirectory(at: imagesDirectory, attributes: appProtectedFileAttributes)
        try createProtectedDirectory(at: thumbnailsDirectory, attributes: appProtectedFileAttributes)
        try createProtectedDirectory(at: widgetDirectory, attributes: widgetReadableFileAttributes)
        protectExistingItemsIfPossible(in: calendarDirectory, attributes: appProtectedFileAttributes)
        protectExistingItemsIfPossible(in: imagesDirectory, attributes: appProtectedFileAttributes)
        protectExistingItemsIfPossible(in: thumbnailsDirectory, attributes: appProtectedFileAttributes)
        protectExistingItemsIfPossible(in: widgetDirectory, attributes: widgetReadableFileAttributes)
    }

    private func createProtectedDirectory(at url: URL, attributes: [FileAttributeKey: Any]) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: attributes
        )
        protectItemIfPossible(at: url, attributes: attributes)
    }

    private func protectExistingItemsIfPossible(in directory: URL, attributes: [FileAttributeKey: Any]) {
        guard let urls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        urls.forEach { protectItemIfPossible(at: $0, attributes: attributes) }
    }

    private func protectItemIfPossible(at url: URL, attributes: [FileAttributeKey: Any]) {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try? fileManager.setAttributes(attributes, ofItemAtPath: url.path)
    }

    private func migrateLegacyAppGroupDataIfNeeded() {
        guard
            !fileManager.fileExists(atPath: indexURL.path),
            let legacyAppGroupRootURL,
            legacyAppGroupRootURL.standardizedFileURL != appRootURL.standardizedFileURL
        else {
            return
        }

        let legacyCalendarDirectory = legacyAppGroupRootURL.appendingPathComponent("PetCalendar", isDirectory: true)
        let legacyIndexURL = legacyCalendarDirectory.appendingPathComponent("index.json")
        guard fileManager.fileExists(atPath: legacyIndexURL.path) else {
            return
        }

        do {
            try createProtectedDirectory(at: calendarDirectory, attributes: appProtectedFileAttributes)
            try copyLegacyItemIfNeeded(
                from: legacyIndexURL,
                to: indexURL,
                attributes: appProtectedFileAttributes
            )
            try copyLegacyItemIfNeeded(
                from: legacyCalendarDirectory.appendingPathComponent("Images", isDirectory: true),
                to: imagesDirectory,
                attributes: appProtectedFileAttributes
            )
            try copyLegacyItemIfNeeded(
                from: legacyCalendarDirectory.appendingPathComponent("Thumbnails", isDirectory: true),
                to: thumbnailsDirectory,
                attributes: appProtectedFileAttributes
            )
            protectExistingItemsIfPossible(in: calendarDirectory, attributes: appProtectedFileAttributes)
            protectExistingItemsIfPossible(in: imagesDirectory, attributes: appProtectedFileAttributes)
            protectExistingItemsIfPossible(in: thumbnailsDirectory, attributes: appProtectedFileAttributes)
            try writeWidgetSnapshot(entries: loadEntries())
            try? fileManager.removeItem(at: legacyIndexURL)
            try? fileManager.removeItem(at: legacyCalendarDirectory.appendingPathComponent("Images", isDirectory: true))
            try? fileManager.removeItem(at: legacyCalendarDirectory.appendingPathComponent("Thumbnails", isDirectory: true))
        } catch {
            return
        }
    }

    private func copyLegacyItemIfNeeded(
        from sourceURL: URL,
        to destinationURL: URL,
        attributes: [FileAttributeKey: Any]
    ) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            return
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: attributes
        )
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        protectItemIfPossible(at: destinationURL, attributes: attributes)
    }

    private static func defaultAppRootURL(fileManager: FileManager) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Memories", isDirectory: true)
    }

    private var calendarDirectory: URL {
        appRootURL.appendingPathComponent("PetCalendar", isDirectory: true)
    }

    private var imagesDirectory: URL {
        calendarDirectory.appendingPathComponent("Images", isDirectory: true)
    }

    private var thumbnailsDirectory: URL {
        calendarDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    private var widgetDirectory: URL {
        widgetRootURL.appendingPathComponent("PetCalendarWidget", isDirectory: true)
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

    private var appProtectedWriteOptions: Data.WritingOptions {
        [.atomic, .completeFileProtection]
    }

    private var appProtectedFileAttributes: [FileAttributeKey: Any] {
        [.protectionKey: Self.appDataFileProtection]
    }

    private var widgetReadableFileAttributes: [FileAttributeKey: Any] {
        [.protectionKey: Self.widgetDataFileProtection]
    }
}

struct PetCalendarWidgetSnapshot: Codable, Hashable {
    static let fileName = "widget-snapshot.json"

    var updatedAt: Date
    var selectedMonth: Date
    var displayLanguage: PetCalendarDisplayLanguage
    var showsBranding: Bool
    var renderedImageSets: [PetCalendarWidgetRenderedImageSet]

    init(
        updatedAt: Date,
        selectedMonth: Date,
        displayLanguage: PetCalendarDisplayLanguage = .japanese,
        showsBranding: Bool = true,
        renderedImageSets: [PetCalendarWidgetRenderedImageSet] = []
    ) {
        self.updatedAt = updatedAt
        self.selectedMonth = selectedMonth
        self.displayLanguage = displayLanguage
        self.showsBranding = showsBranding
        self.renderedImageSets = renderedImageSets
    }

    private enum CodingKeys: String, CodingKey {
        case updatedAt
        case selectedMonth
        case displayLanguage
        case showsBranding
        case renderedImageSets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        selectedMonth = try container.decode(Date.self, forKey: .selectedMonth)
        displayLanguage = try container.decodeIfPresent(PetCalendarDisplayLanguage.self, forKey: .displayLanguage) ?? .japanese
        showsBranding = try container.decodeIfPresent(Bool.self, forKey: .showsBranding) ?? true
        renderedImageSets = try container.decodeIfPresent([PetCalendarWidgetRenderedImageSet].self, forKey: .renderedImageSets) ?? []
    }
}

struct PetCalendarWidgetRenderedImageNames: Codable, Hashable {
    var small: String
    var medium: String
    var large: String
}

struct PetCalendarWidgetRenderedImageSet: Codable, Hashable {
    var dayID: String
    var imageNames: PetCalendarWidgetRenderedImageNames

    var fileNames: [String] {
        [imageNames.small, imageNames.medium, imageNames.large]
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
