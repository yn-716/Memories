import Foundation

extension Bundle {
    nonisolated var memoriesDisplayVersion: String {
        Self.memoriesDisplayVersion(from: infoDictionary)
    }

    nonisolated static func memoriesDisplayVersion(from infoDictionary: [String: Any]?) -> String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
