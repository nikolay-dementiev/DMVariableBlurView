import DMVariableBlurView
import XCTest

/// Values the library rejects, through the public view: the plain blur of the system and
/// one report that names the parameter and the value.
///
/// The reports go to a handler: every line in the unified log would count against the
/// logging volume of the test process, which the system then throttles.
final class BlurViewRejectedValueTests: XCTestCase {
    @MainActor
    func test_blurView_radiusThatIsNegativeOrNotFinite_showsThePlainBlurAndNamesTheRadius() async throws {
        for radius in [-1, -.leastNonzeroMagnitude, .nan, .infinity, -.infinity] as [CGFloat] {
            try await expectRejection(
                of: DMVariableBlurView(maxBlurRadius: radius, direction: .blurredTopClearBottom),
                reportedAs: .invalidMaxBlurRadius(radius),
                described: "maxBlurRadius must be a finite number, 0 or greater, but it is \(radius)"
            )
        }
    }

    @MainActor
    func test_blurView_startOffsetThatIsNotFinite_showsThePlainBlurAndNamesTheOffset() async throws {
        let directions: [DMVariableBlurDirection] = [
            .blurredTopClearBottom, .blurredBottomClearTop, .blurredCenterClearTopBottom(), .blurredFully
        ]
        for direction in directions {
            for offset in [.nan, .infinity, -.infinity] as [CGFloat] {
                try await expectRejection(
                    of: DMVariableBlurView(direction: direction, startOffset: offset),
                    reportedAs: .invalidStartOffset(offset),
                    described: "startOffset must be a finite number, but it is \(offset)"
                )
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT(_ view: DMVariableBlurView, file: StaticString, line: UInt) throws -> HostedBlurView {
        try HostedBlurView(view, file: file, line: line)
    }

    @MainActor
    private func expectRejection(
        of view: DMVariableBlurView,
        reportedAs reason: DMVariableBlurError,
        described text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        var reports: [DMVariableBlurError] = []
        let sut = try makeSUT(view.onFailure { reports.append($0) }, file: file, line: line)
        defer { sut.hide() }

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(sut.filterTypes.contains("variableBlur"), "\(text): no variable blur", file: file, line: line)
        XCTAssertEqual(sut.tintAlphas, [1], "\(text): the tint of the system blur is visible", file: file, line: line)
        XCTAssertEqual(reports, [reason], "\(text): one report with the value", file: file, line: line)
        XCTAssertEqual(reports.first?.localizedDescription, text, "\(text): the description", file: file, line: line)
    }
}
