import Foundation
import Combine

enum AnnouncementServiceError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "お知らせを取得できませんでした"
        }
    }
}

struct AnnouncementService {
    nonisolated static let endpoint = URL(string: "https://memories.myfs716.com/announcements.json")!

    var session: URLSession = .shared
    var endpoint: URL = Self.endpoint

    nonisolated init(session: URLSession = .shared, endpoint: URL = Self.endpoint) {
        self.session = session
        self.endpoint = endpoint
    }

    func fetchAnnouncements() async throws -> [Announcement] {
        let (data, response) = try await session.data(from: endpoint)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AnnouncementServiceError.invalidResponse
        }

        return try Self.decodeAnnouncements(from: data)
    }

    static func decodeAnnouncements(from data: Data) throws -> [Announcement] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.announcementsWithFractionalSeconds.date(from: value)
                ?? ISO8601DateFormatter.announcements.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date")
        }
        return try decoder.decode(AnnouncementEnvelope.self, from: data).announcements
    }
}

@MainActor
final class AnnouncementStore: ObservableObject {
    @Published private(set) var announcements: [Announcement] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false

    private var readIDs: Set<String>
    private let defaults: UserDefaults
    private let service: AnnouncementService
    private let displayBaselineAt: Date

    init(defaults: UserDefaults = .standard, service: AnnouncementService = AnnouncementService(), now: Date = Date()) {
        self.defaults = defaults
        self.service = service
        self.readIDs = Set(defaults.stringArray(forKey: Keys.readIDs) ?? [])
        self.displayBaselineAt = Self.ensureDisplayBaseline(in: defaults, now: now)
        self.announcements = Self.cachedAnnouncements(from: defaults)
    }

    func visibleAnnouncements(
        appVersion: String? = nil,
        now: Date = Date(),
        displayBaselineAt overrideDisplayBaselineAt: Date? = nil
    ) -> [Announcement] {
        let appVersion = appVersion ?? Bundle.main.memoriesDisplayVersion
        let displayBaselineAt = overrideDisplayBaselineAt ?? self.displayBaselineAt
        return announcements
            .filter {
                $0.isVisible(
                    appVersion: appVersion,
                    now: now,
                    displayBaselineAt: displayBaselineAt
                )
            }
            .sorted { lhs, rhs in
                let leftPriority = lhs.priority ?? Int.max
                let rightPriority = rhs.priority ?? Int.max
                if leftPriority != rightPriority {
                    return leftPriority < rightPriority
                }
                return lhs.publishedAt > rhs.publishedAt
            }
    }

    func unreadCount(
        appVersion: String? = nil,
        now: Date = Date(),
        displayBaselineAt: Date? = nil
    ) -> Int {
        visibleAnnouncements(
            appVersion: appVersion,
            now: now,
            displayBaselineAt: displayBaselineAt
        )
            .filter { !readIDs.contains($0.id) }
            .count
    }

    func isUnread(_ announcement: Announcement) -> Bool {
        !readIDs.contains(announcement.id)
    }

    func markRead(_ announcement: Announcement) {
        readIDs.insert(announcement.id)
        persistReadIDs()
    }

    func markAllRead(appVersion: String? = nil, now: Date = Date(), displayBaselineAt: Date? = nil) {
        visibleAnnouncements(
            appVersion: appVersion,
            now: now,
            displayBaselineAt: displayBaselineAt
        )
        .forEach { readIDs.insert($0.id) }
        persistReadIDs()
    }

    func refreshIfNeeded(now: Date = Date()) async {
        guard shouldAutoRefresh(now: now) else {
            return
        }
        await refresh(force: false, now: now)
    }

    func refresh(force: Bool, now: Date = Date()) async {
        if !force, !shouldAutoRefresh(now: now) {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await service.fetchAnnouncements()
            announcements = fetched
            loadFailed = false
            defaults.set(now, forKey: Keys.lastFetchAt)
            persistCache(fetched)
        } catch {
            loadFailed = true
            if announcements.isEmpty {
                announcements = Self.cachedAnnouncements(from: defaults)
            }
        }
    }

    private func shouldAutoRefresh(now: Date) -> Bool {
        guard let lastFetchAt = defaults.object(forKey: Keys.lastFetchAt) as? Date else {
            return true
        }

        return now.timeIntervalSince(lastFetchAt) >= 6 * 60 * 60
    }

    private func persistReadIDs() {
        defaults.set(Array(readIDs), forKey: Keys.readIDs)
        objectWillChange.send()
    }

    private func persistCache(_ announcements: [Announcement]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(AnnouncementEnvelope(announcements: announcements)) {
            defaults.set(data, forKey: Keys.cache)
        }
    }

    private static func cachedAnnouncements(from defaults: UserDefaults) -> [Announcement] {
        guard
            let data = defaults.data(forKey: Keys.cache),
            let announcements = try? AnnouncementService.decodeAnnouncements(from: data)
        else {
            return []
        }
        return announcements
    }

    private static func ensureDisplayBaseline(in defaults: UserDefaults, now: Date) -> Date {
        if let existing = defaults.object(forKey: Keys.displayBaselineAt) as? Date {
            return existing
        }

        defaults.set(now, forKey: Keys.displayBaselineAt)
        return now
    }

    private enum Keys {
        static let cache = "memories.announcements.cache"
        static let readIDs = "memories.announcements.readIDs"
        static let lastFetchAt = "memories.announcements.lastFetchAt"
        static let displayBaselineAt = "memories.announcements.displayBaselineAt"
    }
}

private extension ISO8601DateFormatter {
    static let announcements: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let announcementsWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
