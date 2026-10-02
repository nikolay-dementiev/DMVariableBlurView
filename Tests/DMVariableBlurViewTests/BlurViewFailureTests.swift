import DMVariableBlurView
import OSLog
import XCTest

/// A configuration the library rejects is never silent: the view writes one line at
/// error level to the unified log, which names the value it rejected.
final class BlurViewFailureTests: XCTestCase {
    @MainActor
    func test_blurView_centerBandProportionOutOfRange_writesOneErrorLineThatNamesTheValue() throws {
        let log = UnifiedLogReader()

        let sut = try makeSUT(DMVariableBlurView(direction: .blurredCenterClearTopBottom(centerBandProportion: 1.5)))
        defer { sut.hide() }

        let lines = try log.libraryLines()
        XCTAssertEqual(lines.count, 1, "one line for one rejected configuration")
        XCTAssertEqual(lines.first?.level, .error, "the line is written at error level")
        XCTAssertTrue(
            lines.first?.composedMessage.contains("centerBandProportion must be in the range 0...1, but it is 1.5") == true,
            "the line names the parameter, its range and the value: \(lines.first?.composedMessage ?? "no line")"
        )
    }

    @MainActor
    func test_blurView_validConfiguration_writesNothingToTheLog() throws {
        let log = UnifiedLogReader()

        let sut = try makeSUT(DMVariableBlurView(direction: .blurredCenterClearTopBottom(centerBandProportion: 0.4)))
        defer { sut.hide() }

        XCTAssertEqual(try log.libraryLines().count, 0)
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT(
        _ view: DMVariableBlurView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> HostedBlurView {
        try HostedBlurView(view, file: file, line: line)
    }
}
