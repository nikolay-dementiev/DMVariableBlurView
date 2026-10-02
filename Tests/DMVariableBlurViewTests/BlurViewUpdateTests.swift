import DMVariableBlurView
import UIKit
import XCTest

/// A SwiftUI update hands the view new values: the same UIKit view shows them.
final class BlurViewUpdateTests: XCTestCase {
    @MainActor
    func test_blurView_updatedWithANewRadiusAndDirection_showsThemOnTheSameView() throws {
        let sut = try makeSUT(DMVariableBlurView(maxBlurRadius: 5, direction: .blurredTopClearBottom))
        defer { sut.hide() }

        let updated = try sut.update(DMVariableBlurView(maxBlurRadius: 9, direction: .blurredBottomClearTop))

        XCTAssertTrue(updated === sut.blurView, "SwiftUI keeps the UIKit view and updates it")
        XCTAssertEqual(sut.radius, 9, "the new radius is installed")
        assertMaskProfile(of: sut, matches: MaskProfileFixtures.bottomZeroOffset)
    }

    @MainActor
    func test_blurView_updatedToARejectedValue_showsThePlainSystemBlur() throws {
        let sut = try makeSUT(DMVariableBlurView(maxBlurRadius: 5, direction: .blurredTopClearBottom))
        defer { sut.hide() }

        _ = try sut.update(DMVariableBlurView(direction: .blurredCenterClearTopBottom(centerBandProportion: 1.5)))

        XCTAssertFalse(sut.filterTypes.contains("variableBlur"), "the variable blur is gone")
        XCTAssertFalse(sut.filterTypes.isEmpty, "the backdrop carries the filters of the system blur")
        XCTAssertEqual(sut.tintAlphas, [1], "the tint of the system blur is visible")
    }

    @MainActor
    func test_blurView_updatedFromARejectedValueToAValidOne_showsTheVariableBlur() throws {
        let sut = try makeSUT(DMVariableBlurView(direction: .blurredCenterClearTopBottom(centerBandProportion: 1.5)))
        defer { sut.hide() }

        _ = try sut.update(DMVariableBlurView(maxBlurRadius: 9, direction: .blurredBottomClearTop))

        XCTAssertEqual(sut.filterTypes, ["variableBlur"], "the variable blur replaces the system blur")
        XCTAssertEqual(sut.tintAlphas, [0], "the tint is hidden again")
        assertMaskProfile(of: sut, matches: MaskProfileFixtures.bottomZeroOffset)
    }

    @MainActor
    func test_blurView_updatedToARejectedValueTwice_writesOneLine() throws {
        let sut = try makeSUT(DMVariableBlurView(maxBlurRadius: 5, direction: .blurredTopClearBottom))
        defer { sut.hide() }
        let log = UnifiedLogReader()
        let rejected = DMVariableBlurView(direction: .blurredCenterClearTopBottom(centerBandProportion: 1.5))

        _ = try sut.update(rejected)
        _ = try sut.update(rejected)

        XCTAssertEqual(try log.libraryLines().count, 1)
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
