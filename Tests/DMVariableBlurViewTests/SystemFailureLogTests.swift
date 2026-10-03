import DMVariableBlurView
import OSLog
import XCTest

/// The log adapter against the unified log of the system.
final class SystemFailureLogTests: XCTestCase {
    func test_record_errorWithADetail_writesOneErrorLineWithTheDescriptionAndTheDetail() throws {
        let log = UnifiedLogReader()

        makeSUT().record(.effectUnavailable, detail: "filterTypeMissing")

        let lines = try log.libraryLines()
        XCTAssertEqual(lines.count, 1, "one line per recorded failure")
        XCTAssertEqual(lines.first?.level, .error, "the line is written at error level")
        XCTAssertEqual(
            lines.first?.composedMessage,
            "The system does not offer the variable blur effect, or did not accept it. "
                + "The view shows the plain blur of the system, or nothing while the host has removed its effect. "
                + "Detail: filterTypeMissing",
            "the line holds the description, the consequence and the detail"
        )
    }

    func test_record_errorWithoutADetail_writesTheDescriptionAndTheConsequence() throws {
        let log = UnifiedLogReader()

        makeSUT().record(.invalidCenterBandProportion(1.5), detail: nil)

        XCTAssertEqual(
            try log.libraryLines().map(\.composedMessage),
            [
                "centerBandProportion must be in the range 0...1, but it is 1.5. "
                    + "The view shows the plain blur of the system, or nothing while the host has removed its effect."
            ]
        )
    }

    // MARK: - Helpers

    private func makeSUT() -> SystemFailureLog {
        SystemFailureLog()
    }
}
