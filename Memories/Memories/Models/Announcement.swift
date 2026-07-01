import Foundation

struct AnnouncementEnvelope: Codable {
    var announcements: [Announcement]
}

struct Announcement: Codable, Hashable, Identifiable {
    let id: String
    let titleJa: String
    let bodyJa: String
    let titleEn: String
    let bodyEn: String
    let publishedAt: Date
    let expiresAt: Date?
    let isActive: Bool
    let url: URL?
    let minimumAppVersion: String?
    let maximumAppVersion: String?
    let priority: Int?
    let showForNewUsers: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case titleJa
        case bodyJa
        case titleEn
        case bodyEn
        case publishedAt
        case expiresAt
        case isActive
        case url
        case minimumAppVersion
        case maximumAppVersion
        case priority
        case showForNewUsers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        titleJa = try container.decode(String.self, forKey: .titleJa)
        bodyJa = try container.decode(String.self, forKey: .bodyJa)
        titleEn = try container.decode(String.self, forKey: .titleEn)
        bodyEn = try container.decode(String.self, forKey: .bodyEn)
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        minimumAppVersion = try container.decodeIfPresent(String.self, forKey: .minimumAppVersion)
        maximumAppVersion = try container.decodeIfPresent(String.self, forKey: .maximumAppVersion)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority)
        showForNewUsers = try container.decodeIfPresent(Bool.self, forKey: .showForNewUsers) ?? false
    }

    func title(language: ResolvedAppLanguage) -> String {
        localized(primary: language == .japanese ? titleJa : titleEn, fallback: language == .japanese ? titleEn : titleJa)
    }

    func body(language: ResolvedAppLanguage) -> String {
        localized(primary: language == .japanese ? bodyJa : bodyEn, fallback: language == .japanese ? bodyEn : bodyJa)
    }

    func isVisible(
        appVersion: String,
        now: Date = Date(),
        displayBaselineAt: Date = .distantPast
    ) -> Bool {
        guard isActive else {
            return false
        }
        if let expiresAt, expiresAt < now {
            return false
        }

        let current = SemanticAppVersion(appVersion)
        if let minimumAppVersion, current < SemanticAppVersion(minimumAppVersion) {
            return false
        }
        if let maximumAppVersion, current > SemanticAppVersion(maximumAppVersion) {
            return false
        }
        if publishedAt < displayBaselineAt && !showForNewUsers {
            return false
        }
        return true
    }

    private func localized(primary: String, fallback: String) -> String {
        let trimmedPrimary = primary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrimary.isEmpty {
            return trimmedPrimary
        }
        return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SemanticAppVersion: Comparable, Hashable {
    private let components: [Int]

    init(_ value: String) {
        components = value
            .split(separator: ".")
            .map { part in
                let digits = part.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }

    static func == (lhs: SemanticAppVersion, rhs: SemanticAppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    func hash(into hasher: inout Hasher) {
        var normalized = components
        while normalized.last == 0 {
            normalized.removeLast()
        }
        hasher.combine(normalized)
    }

    static func < (lhs: SemanticAppVersion, rhs: SemanticAppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}
