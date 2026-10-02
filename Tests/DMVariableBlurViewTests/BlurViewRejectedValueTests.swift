import DMVariableBlurView
import OSLog
import XCTest

/// Values the library rejects, through the public view: the plain blur of the system and
/// one line in the log that names the parameter and the value.
final class BlurViewRejectedValueTests: XCTestCase {
    @MainActor
    func test_blurView_radiusThatIsNegativeOrNotFinite_showsThePlainBlurAndNamesTheRadius() throws {
        for radius in [-1, -.leastNonzeroMagnitude, .nan, .infinity, -.infinity] as [CGFloat] {
            try expectRejection(
                of: DMVariableBlurView(maxBlurRadius: radius, direction: .blurredTopClearBottom),
                namingInTheLog: "maxBlurRadius must be a finite number, 0 or greater, but it is \(radius)"
            )
        }
    }

    @MainActor
    func test_blurView_startOffsetThatIsNotFinite_showsThePlainBlurAndNamesTheOffset() throws {
        let directions: [DMVariableBlurDirection] = [
            .blurredTopClearBottom, .blurredBottomClearTop, .blurredCenterClearTopBottom(), .blurredFully
        ]
        for direction in directions {
            for offset in [.nan, .infinity, -.infinity] as [CGFloat] {
                try expectRejection(
                    of: DMVariableBlurView(direction: direction, startOffset: offset),
                    namingInTheLog: "startOffset must be a finite number, but it is \(offset)"
                )
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func expectRejection(
        of view: DMVariableBlurView,
        namingInTheLog text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let log = UnifiedLogReader()
        let sut = try HostedBlurView(view, file: file, line: line)
        defer { sut.hide() }

        let lines = try log.libraryLines()
        XCTAssertFalse(sut.filterTypes.contains("variableBlur"), "\(text): no variable blur", file: file, line: line)
        XCTAssertEqual(sut.tintAlphas, [1], "\(text): the tint of the system blur is visible", file: file, line: line)
        XCTAssertEqual(lines.count, 1, "\(text): one line in the log", file: file, line: line)
        XCTAssertTrue(
            lines.first?.composedMessage.hasPrefix(text) == true,
            "\(text): the line names the parameter and the value, found \(lines.first?.composedMessage ?? "no line")",
            file: file,
            line: line
        )
    }
}
