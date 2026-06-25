import XCTest
@testable import Memories

@MainActor
final class CardEditStateTests: XCTestCase {
    func testDisplayDateTextSupportsSingleRangeAndCustomModes() {
        var state = makeState()

        state.dateMode = .single
        state.selectedDate = CardEditState.date(year: 2026, month: 6, day: 17)
        XCTAssertEqual(state.displayDateText, "2026.06.17")

        state.dateMode = .range
        state.startDate = CardEditState.date(year: 2026, month: 6, day: 17)
        state.endDate = CardEditState.date(year: 2026, month: 6, day: 19)
        XCTAssertEqual(state.displayDateText, "2026.06.17 - 2026.06.19")

        state.endDate = CardEditState.date(year: 2026, month: 6, day: 15)
        XCTAssertEqual(state.displayDateText, "2026.06.17 - 2026.06.17")

        state.dateMode = .custom
        state.customDateText = "Spring 2026"
        XCTAssertEqual(state.displayDateText, "Spring 2026")
    }

    func testRetroDateStampUsesV1Format() {
        var state = makeState()
        state.selectedDate = CardEditState.date(year: 2026, month: 6, day: 19)

        XCTAssertEqual(state.retroDateStampText, "06 19 '26")
    }

    func testRetroFilterDefaultsToSepiaForNewlyDecodedDraftState() throws {
        let state = try JSONDecoder().decode(CardEditState.self, from: Data("{}".utf8))

        XCTAssertEqual(state.retroFilterType, .sepia)
    }

    func testLegacyRetroFilterStrengthFallsBackToNostalgic() throws {
        let json = #"{"retroFilterStrength":"strong"}"#
        let state = try JSONDecoder().decode(CardEditState.self, from: Data(json.utf8))

        XCTAssertEqual(state.retroFilterType, .nostalgic)
    }

    func testLegacyRoundedFontRoleDecodesAsSoft() throws {
        let fontRole = try JSONDecoder().decode(FontRole.self, from: Data(#""rounded""#.utf8))

        XCTAssertEqual(fontRole, .soft)
    }

    private func makeState() -> CardEditState {
        CardEditState.newCard(
            defaultLayout: .bottomLeft,
            fontRole: .clean,
            textColor: .white,
            date: CardEditState.date(year: 2026, month: 6, day: 17)
        )
    }
}
