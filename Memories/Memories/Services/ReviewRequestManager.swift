import Foundation
import StoreKit
import UIKit

struct ReviewRequestState: Codable, Equatable {
    var firstLaunchDate: Date
    var successfulSaveCount: Int
    var lastAttemptedAt: Date?
    var lastAttemptedVersion: String?
    var attemptedVersions: Set<String>

    static func initial(now: Date) -> ReviewRequestState {
        ReviewRequestState(
            firstLaunchDate: now,
            successfulSaveCount: 0,
            lastAttemptedAt: nil,
            lastAttemptedVersion: nil,
            attemptedVersions: []
        )
    }
}

struct ReviewRequestPolicy {
    var minimumSuccessfulSaveCount = 3
    var minimumDaysBetweenAttempts = 50

    nonisolated init(minimumSuccessfulSaveCount: Int = 3, minimumDaysBetweenAttempts: Int = 50) {
        self.minimumSuccessfulSaveCount = minimumSuccessfulSaveCount
        self.minimumDaysBetweenAttempts = minimumDaysBetweenAttempts
    }

    func shouldAttemptReview(
        state: ReviewRequestState,
        now: Date,
        appVersion: String
    ) -> Bool {
        guard state.successfulSaveCount >= minimumSuccessfulSaveCount else {
            return false
        }

        guard !state.attemptedVersions.contains(appVersion), state.lastAttemptedVersion != appVersion else {
            return false
        }

        if let lastAttemptedAt = state.lastAttemptedAt {
            let elapsed = now.timeIntervalSince(lastAttemptedAt)
            guard elapsed >= TimeInterval(minimumDaysBetweenAttempts * 24 * 60 * 60) else {
                return false
            }
        }

        return true
    }
}

@MainActor
final class ReviewRequestManager {
    static let shared = ReviewRequestManager()

    private let defaults: UserDefaults
    private let policy: ReviewRequestPolicy

    init(defaults: UserDefaults = .standard, policy: ReviewRequestPolicy = ReviewRequestPolicy()) {
        self.defaults = defaults
        self.policy = policy
        if defaults.data(forKey: Keys.state) == nil {
            saveState(.initial(now: Date()))
        }
    }

    func recordSuccessfulSaveAndRequestReviewIfEligible(now: Date = Date()) {
        var state = loadState(now: now)
        state.successfulSaveCount += 1

        let appVersion = Bundle.main.memoriesDisplayVersion
        guard policy.shouldAttemptReview(state: state, now: now, appVersion: appVersion) else {
            saveState(state)
            return
        }

        state.lastAttemptedAt = now
        state.lastAttemptedVersion = appVersion
        state.attemptedVersions.insert(appVersion)
        saveState(state)
        requestReview()
    }

    private func requestReview() {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
        else {
            return
        }

        SKStoreReviewController.requestReview(in: scene)
    }

    private func loadState(now: Date) -> ReviewRequestState {
        guard
            let data = defaults.data(forKey: Keys.state),
            let state = try? JSONDecoder().decode(ReviewRequestState.self, from: data)
        else {
            return .initial(now: now)
        }

        return state
    }

    private func saveState(_ state: ReviewRequestState) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Keys.state)
        }
    }

    private enum Keys {
        static let state = "memories.reviewRequest.state"
    }
}
