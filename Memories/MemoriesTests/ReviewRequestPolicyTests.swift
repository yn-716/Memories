import XCTest
@testable import Memories

@MainActor
final class ReviewRequestPolicyTests: XCTestCase {
    func testAllowsAfterThirdSuccessfulSave() {
        let policy = ReviewRequestPolicy()
        let now = Date()
        let state = ReviewRequestState(
            firstLaunchDate: now.addingTimeInterval(-7 * 24 * 60 * 60),
            successfulSaveCount: 3,
            lastAttemptedAt: nil,
            lastAttemptedVersion: nil,
            attemptedVersions: []
        )

        XCTAssertTrue(policy.shouldAttemptReview(state: state, now: now, appVersion: "1.2.0"))
    }

    func testDoesNotAllowWithinFiftyDays() {
        let policy = ReviewRequestPolicy()
        let now = Date()
        let state = ReviewRequestState(
            firstLaunchDate: now.addingTimeInterval(-100 * 24 * 60 * 60),
            successfulSaveCount: 10,
            lastAttemptedAt: now.addingTimeInterval(-49 * 24 * 60 * 60),
            lastAttemptedVersion: "1.1.0",
            attemptedVersions: ["1.1.0"]
        )

        XCTAssertFalse(policy.shouldAttemptReview(state: state, now: now, appVersion: "1.2.0"))
    }

    func testDoesNotAllowTwiceForSameVersion() {
        let policy = ReviewRequestPolicy()
        let now = Date()
        let state = ReviewRequestState(
            firstLaunchDate: now.addingTimeInterval(-100 * 24 * 60 * 60),
            successfulSaveCount: 10,
            lastAttemptedAt: now.addingTimeInterval(-80 * 24 * 60 * 60),
            lastAttemptedVersion: "1.2.0",
            attemptedVersions: ["1.2.0"]
        )

        XCTAssertFalse(policy.shouldAttemptReview(state: state, now: now, appVersion: "1.2.0"))
    }
}
