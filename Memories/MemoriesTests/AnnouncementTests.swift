import XCTest
@testable import Memories

@MainActor
final class AnnouncementTests: XCTestCase {
    func testDecodesAnnouncementJSON() throws {
        let announcements = try AnnouncementService.decodeAnnouncements(from: sampleJSON)

        XCTAssertEqual(announcements.count, 2)
        XCTAssertEqual(announcements[0].id, "2026-07-01-v120")
        XCTAssertEqual(announcements[0].title(language: .japanese), "動画編集に対応しました")
        XCTAssertEqual(announcements[0].title(language: .english), "Video editing is now supported")
        XCTAssertNil(announcements[0].expiresAt)
        XCTAssertFalse(announcements[0].showForNewUsers)
    }

    func testFiltersActiveAndVersionRange() throws {
        let announcements = try AnnouncementService.decodeAnnouncements(from: sampleJSON)

        let visibleFor120 = announcements.filter { $0.isVisible(appVersion: "1.2.0") }
        let visibleFor110 = announcements.filter { $0.isVisible(appVersion: "1.1.0") }

        XCTAssertEqual(visibleFor120.map(\.id), ["2026-07-01-v120"])
        XCTAssertTrue(visibleFor110.isEmpty)
    }

    func testSemanticVersionComparisonHandlesDoubleDigitPatch() {
        XCTAssertGreaterThan(SemanticAppVersion("1.2.10"), SemanticAppVersion("1.2.2"))
        XCTAssertLessThan(SemanticAppVersion("1.2.0"), SemanticAppVersion("1.2.1"))
        XCTAssertEqual(SemanticAppVersion("1.2"), SemanticAppVersion("1.2.0"))
    }

    func testExpiresAtFiltering() throws {
        let announcements = try AnnouncementService.decodeAnnouncements(from: filteringJSON)
        let now = date("2026-08-01T00:00:00Z")
        let baseline = date("2026-07-01T00:00:00Z")

        XCTAssertFalse(announcement("expired", in: announcements).isVisible(
            appVersion: "1.2.0",
            now: now,
            displayBaselineAt: baseline
        ))
        XCTAssertTrue(announcement("future-expiry", in: announcements).isVisible(
            appVersion: "1.2.0",
            now: now,
            displayBaselineAt: baseline
        ))
        XCTAssertTrue(announcement("no-expiry-null", in: announcements).isVisible(
            appVersion: "1.2.0",
            now: now,
            displayBaselineAt: baseline
        ))
        XCTAssertTrue(announcement("no-expiry-missing", in: announcements).isVisible(
            appVersion: "1.2.0",
            now: now,
            displayBaselineAt: baseline
        ))
    }

    func testNewUserBaselineFiltering() throws {
        let announcements = try AnnouncementService.decodeAnnouncements(from: filteringJSON)
        let now = date("2026-08-01T00:00:00Z")
        let baseline = date("2026-07-01T00:00:00Z")

        XCTAssertFalse(announcement("old-hidden", in: announcements).isVisible(
            appVersion: "1.2.0",
            now: now,
            displayBaselineAt: baseline
        ))
        XCTAssertTrue(announcement("old-important", in: announcements).isVisible(
            appVersion: "1.2.0",
            now: now,
            displayBaselineAt: baseline
        ))
        XCTAssertFalse(announcement("old-missing-flag", in: announcements).showForNewUsers)
        XCTAssertFalse(announcement("old-missing-flag", in: announcements).isVisible(
            appVersion: "1.2.0",
            now: now,
            displayBaselineAt: baseline
        ))
    }

    func testUnreadCountChangesWhenMarkedRead() throws {
        let defaults = try makeDefaults()
        let envelope = AnnouncementEnvelope(announcements: try AnnouncementService.decodeAnnouncements(from: sampleJSON))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(envelope), forKey: "memories.announcements.cache")

        let store = AnnouncementStore(defaults: defaults, now: date("2026-06-30T00:00:00Z"))

        XCTAssertEqual(store.unreadCount(appVersion: "1.2.0", now: date("2026-07-02T00:00:00Z")), 1)
        let announcement = try XCTUnwrap(store.visibleAnnouncements(
            appVersion: "1.2.0",
            now: date("2026-07-02T00:00:00Z")
        ).first)
        store.markRead(announcement)
        XCTAssertEqual(store.unreadCount(appVersion: "1.2.0", now: date("2026-07-02T00:00:00Z")), 0)
    }

    func testUnreadCountOnlyIncludesVisibleAnnouncements() throws {
        let defaults = try makeDefaults()
        defaults.set(
            try encodedEnvelope(from: filteringJSON),
            forKey: "memories.announcements.cache"
        )
        defaults.set(["future-expiry"], forKey: "memories.announcements.readIDs")
        let store = AnnouncementStore(defaults: defaults, now: date("2026-07-01T00:00:00Z"))

        let visibleIDs = store.visibleAnnouncements(
            appVersion: "1.2.0",
            now: date("2026-08-01T00:00:00Z")
        )
        .map(\.id)

        XCTAssertTrue(visibleIDs.contains("future-expiry"))
        XCTAssertTrue(visibleIDs.contains("no-expiry-null"))
        XCTAssertTrue(visibleIDs.contains("no-expiry-missing"))
        XCTAssertTrue(visibleIDs.contains("old-important"))
        XCTAssertFalse(visibleIDs.contains("expired"))
        XCTAssertFalse(visibleIDs.contains("old-hidden"))
        XCTAssertFalse(visibleIDs.contains("old-missing-flag"))
        XCTAssertEqual(store.unreadCount(appVersion: "1.2.0", now: date("2026-08-01T00:00:00Z")), 3)
    }

    func testCacheAppliesExpiryAndNewUserFilters() throws {
        let defaults = try makeDefaults()
        defaults.set(
            try encodedEnvelope(from: filteringJSON),
            forKey: "memories.announcements.cache"
        )

        let store = AnnouncementStore(defaults: defaults, now: date("2026-07-01T00:00:00Z"))
        let visibleIDs = store.visibleAnnouncements(
            appVersion: "1.2.0",
            now: date("2026-08-01T00:00:00Z")
        )
        .map(\.id)

        XCTAssertFalse(visibleIDs.contains("expired"))
        XCTAssertFalse(visibleIDs.contains("old-hidden"))
        XCTAssertTrue(visibleIDs.contains("old-important"))
    }

    func testDisplayBaselineIsPersistedOnce() throws {
        let defaults = try makeDefaults()
        defaults.set(
            try encodedEnvelope(from: baselinePersistenceJSON),
            forKey: "memories.announcements.cache"
        )

        _ = AnnouncementStore(defaults: defaults, now: date("2026-07-10T00:00:00Z"))
        let storeAfterLaterLaunch = AnnouncementStore(defaults: defaults, now: date("2026-08-01T00:00:00Z"))

        XCTAssertEqual(
            storeAfterLaterLaunch.visibleAnnouncements(
                appVersion: "1.2.0",
                now: date("2026-08-02T00:00:00Z")
            )
            .map(\.id),
            ["published-after-first-baseline"]
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "AnnouncementTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func encodedEnvelope(from json: Data) throws -> Data {
        let envelope = AnnouncementEnvelope(announcements: try AnnouncementService.decodeAnnouncements(from: json))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(envelope)
    }

    private func announcement(_ id: String, in announcements: [Announcement]) -> Announcement {
        guard let announcement = announcements.first(where: { $0.id == id }) else {
            XCTFail("Missing announcement \(id)")
            return announcements[0]
        }
        return announcement
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? Date.distantPast
    }

    private var sampleJSON: Data {
        Data(
            """
            {
              "announcements": [
                {
                  "id": "2026-07-01-v120",
                  "titleJa": "動画編集に対応しました",
                  "bodyJa": "写真だけでなく、動画にもカード風フレームを重ねられるようになりました。",
                  "titleEn": "Video editing is now supported",
                  "bodyEn": "You can now create card-style videos as well as photos.",
                  "publishedAt": "2026-07-01T00:00:00Z",
                  "isActive": true,
                  "url": "https://memories.myfs716.com/support/",
                  "minimumAppVersion": "1.2.0",
                  "maximumAppVersion": null,
                  "priority": 0
                },
                {
                  "id": "inactive",
                  "titleJa": "非表示",
                  "bodyJa": "非表示",
                  "titleEn": "Hidden",
                  "bodyEn": "Hidden",
                  "publishedAt": "2026-06-01T00:00:00Z",
                  "isActive": false,
                  "url": null,
                  "minimumAppVersion": null,
                  "maximumAppVersion": null,
                  "priority": 1
                }
              ]
            }
            """.utf8
        )
    }

    private var filteringJSON: Data {
        Data(
            """
            {
              "announcements": [
                {
                  "id": "expired",
                  "titleJa": "期限切れ",
                  "bodyJa": "期限切れ",
                  "titleEn": "Expired",
                  "bodyEn": "Expired",
                  "publishedAt": "2026-07-10T00:00:00Z",
                  "expiresAt": "2026-07-20T00:00:00Z",
                  "isActive": true,
                  "url": null,
                  "minimumAppVersion": null,
                  "maximumAppVersion": null,
                  "priority": 0,
                  "showForNewUsers": false
                },
                {
                  "id": "future-expiry",
                  "titleJa": "期限内",
                  "bodyJa": "期限内",
                  "titleEn": "Future expiry",
                  "bodyEn": "Future expiry",
                  "publishedAt": "2026-07-10T00:00:00Z",
                  "expiresAt": "2026-09-01T00:00:00Z",
                  "isActive": true,
                  "url": null,
                  "minimumAppVersion": null,
                  "maximumAppVersion": null,
                  "priority": 1,
                  "showForNewUsers": false
                },
                {
                  "id": "no-expiry-null",
                  "titleJa": "期限なし null",
                  "bodyJa": "期限なし null",
                  "titleEn": "No expiry null",
                  "bodyEn": "No expiry null",
                  "publishedAt": "2026-07-11T00:00:00Z",
                  "expiresAt": null,
                  "isActive": true,
                  "url": null,
                  "minimumAppVersion": null,
                  "maximumAppVersion": null,
                  "priority": 2,
                  "showForNewUsers": false
                },
                {
                  "id": "no-expiry-missing",
                  "titleJa": "期限なし missing",
                  "bodyJa": "期限なし missing",
                  "titleEn": "No expiry missing",
                  "bodyEn": "No expiry missing",
                  "publishedAt": "2026-07-12T00:00:00Z",
                  "isActive": true,
                  "url": null,
                  "minimumAppVersion": null,
                  "maximumAppVersion": null,
                  "priority": 3,
                  "showForNewUsers": false
                },
                {
                  "id": "old-hidden",
                  "titleJa": "古い更新",
                  "bodyJa": "古い更新",
                  "titleEn": "Old update",
                  "bodyEn": "Old update",
                  "publishedAt": "2026-06-01T00:00:00Z",
                  "expiresAt": null,
                  "isActive": true,
                  "url": null,
                  "minimumAppVersion": null,
                  "maximumAppVersion": null,
                  "priority": 4,
                  "showForNewUsers": false
                },
                {
                  "id": "old-important",
                  "titleJa": "重要なお知らせ",
                  "bodyJa": "重要なお知らせ",
                  "titleEn": "Important",
                  "bodyEn": "Important",
                  "publishedAt": "2026-06-01T00:00:00Z",
                  "expiresAt": null,
                  "isActive": true,
                  "url": null,
                  "minimumAppVersion": null,
                  "maximumAppVersion": null,
                  "priority": 5,
                  "showForNewUsers": true
                },
                {
                  "id": "old-missing-flag",
                  "titleJa": "未指定",
                  "bodyJa": "未指定",
                  "titleEn": "Missing flag",
                  "bodyEn": "Missing flag",
                  "publishedAt": "2026-06-01T00:00:00Z",
                  "expiresAt": null,
                  "isActive": true,
                  "url": null,
                  "minimumAppVersion": null,
                  "maximumAppVersion": null,
                  "priority": 6
                }
              ]
            }
            """.utf8
        )
    }

    private var baselinePersistenceJSON: Data {
        Data(
            """
            {
              "announcements": [
                {
                  "id": "published-after-first-baseline",
                  "titleJa": "あとから公開",
                  "bodyJa": "あとから公開",
                  "titleEn": "Published later",
                  "bodyEn": "Published later",
                  "publishedAt": "2026-07-15T00:00:00Z",
                  "expiresAt": null,
                  "isActive": true,
                  "url": null,
                  "minimumAppVersion": null,
                  "maximumAppVersion": null,
                  "priority": 0,
                  "showForNewUsers": false
                }
              ]
            }
            """.utf8
        )
    }
}
