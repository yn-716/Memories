import XCTest
@testable import Memories

@MainActor
final class BundleVersionTests: XCTestCase {
    func testDisplayVersionReadsShortVersionOnly() {
        let version = Bundle.memoriesDisplayVersion(
            from: [
                "CFBundleShortVersionString": "1.2.0",
                "CFBundleVersion": "42"
            ]
        )

        XCTAssertEqual(version, "1.2.0")
    }

    func testDisplayVersionFallback() {
        XCTAssertEqual(Bundle.memoriesDisplayVersion(from: nil), "—")
    }
}
